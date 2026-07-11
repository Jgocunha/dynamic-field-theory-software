// cedar_runner_2d — 2D cross-framework algebraic equivalence test suite runner
//
// Reads every 2D JSON architecture from simulations/cedar, runs the two-phase
// protocol (500 steps stimulus ON, 500 steps stimulus OFF), and saves the
// flattened (row-major, 2500-value) field activation profiles to data/cedar/.
//
// This runner drives the REAL Cedar library: each JSON is loaded into a
// cedar::proc::Group via readJson, the NeuralField and GaussInput sources are
// retrieved by element lookup, and the field is stepped directly with an
// advancing global clock. The 50x50 activation Mat (CV_32F) is flattened
// row-major. Identical to the 1D runner except the architecture is 2D; Cedar's
// own convolution engine handles the 2D lateral interaction. No equations are
// reimplemented here.
//
// Build: registered via cedar_add_executable in the sibling CMakeLists.txt and
// built as part of the Cedar project (links Cedar + Qt + OpenCV).
//
// Usage: cross_platform_validation <simulations_dir> <output_dir>
//   simulations_dir: path to simulations/cedar  (contains sim_NNN_*.json)
//   output_dir:      path to data/cedar          (CSVs written here)

#include "cedar/processing/Group.h"
#include "cedar/processing/StepTime.h"
#include "cedar/processing/DataConnection.h"
#include "cedar/processing/DataSlot.h"
#include "cedar/processing/Triggerable.h"
#include "cedar/auxiliaries/GlobalClock.h"
#include "cedar/processing/sources/GaussInput.h"
#include "cedar/dynamics/fields/NeuralField.h"
#include "cedar/auxiliaries/MatData.h"
#include "cedar/units/Time.h"
#include "cedar/units/prefixes.h"

#include <opencv2/opencv.hpp>

#include <QCoreApplication>

#include <boost/property_tree/json_parser.hpp>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

// Field / protocol constants (match the 1D cross-platform-validation spec).
static constexpr int    N_STEPS   = 500;     // steps per phase
static const cedar::unit::Time STEP_TIME(25.0 * cedar::unit::milli * cedar::unit::second);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Flatten a cv::Mat (1xN, Nx1, or HxW) to a row-major std::vector<float>.
static std::vector<float> flatten_mat(const cv::Mat& mat)
{
    cv::Mat m;
    if (mat.type() != CV_32F) mat.convertTo(m, CV_32F); else m = mat;
    std::vector<float> out;
    out.reserve(static_cast<size_t>(m.rows) * m.cols);
    for (int r = 0; r < m.rows; ++r)
        for (int c = 0; c < m.cols; ++c)
            out.push_back(m.at<float>(r, c));
    return out;
}

static void save_csv(const std::vector<float>& data, const fs::path& path)
{
    std::ofstream f(path);
    if (!f) throw std::runtime_error("Cannot open: " + path.string());
    for (size_t i = 0; i < data.size(); ++i) {
        if (i > 0) f << ',';
        f << data[i];
    }
    f << '\n';
}

// Collect all GaussInput source steps in the group.
static std::vector<cedar::proc::sources::GaussInputPtr>
collect_stimuli(const cedar::proc::GroupPtr& group)
{
    std::vector<cedar::proc::sources::GaussInputPtr> stimuli;
    for (const auto& name_element : group->getElements()) {
        auto gi = boost::dynamic_pointer_cast<cedar::proc::sources::GaussInput>(name_element.second);
        if (gi) stimuli.push_back(gi);
    }
    return stimuli;
}

// Step the field N_STEPS times. The field is triggered directly (a freshly
// loaded LoopedTrigger has no listeners until started, and we want a
// deterministic, fixed step count rather than the wall-clock loop). Each
// onTrigger runs one Euler step, recomputing the input sum from the connected
// stimulus first.
static void run_phase(const cedar::dyn::NeuralFieldPtr& field)
{
    // Each step must carry a strictly-increasing global timestamp; Step::onTrigger
    // skips compute() when the StepTime's timestamp is not newer than the last one.
    // So advance the global clock by STEP_TIME and build a fresh StepTime each step.
    auto clock = cedar::aux::GlobalClockSingleton::getInstance();
    for (int t = 0; t < N_STEPS; ++t)
    {
        clock->addTime(STEP_TIME);
        cedar::proc::ArgumentsPtr args(new cedar::proc::StepTime(STEP_TIME, clock->getTime()));
        field->onTrigger(args, cedar::proc::TriggerPtr());
    }
}

// True if the field's convolution engine threw during a step (e.g. FFTW's "kernel
// size is too big for FFTW convolution" when the kernel is wider than the field).
// A field stuck in this state does no real work — every further step is a no-op —
// so the resulting CSV would be a meaningless frozen snapshot, not real dynamics.
static bool in_exception_state(const cedar::dyn::NeuralFieldPtr& field)
{
    const auto st = field->getState();
    return st == cedar::proc::Triggerable::STATE_EXCEPTION ||
           st == cedar::proc::Triggerable::STATE_EXCEPTION_ON_START;
}

// Dump the loaded architecture (elements, parameters, connections) as JSON so
// we can confirm readJson produced what we intended. Used in --dump mode.
static void dump_architecture(const fs::path& json_path)
{
    cedar::proc::GroupPtr group(new cedar::proc::Group());
    group->readJson(json_path.string());

    cedar::aux::ConfigurationNode root;
    group->writeConfiguration(root);

    std::stringstream ss;
    boost::property_tree::write_json(ss, root);
    std::cout << "==== Round-tripped architecture for " << json_path.filename().string()
              << " ====\n" << ss.str();

    std::cout << "---- Data connections ----\n";
    for (const auto& c : group->getDataConnections()) {
        std::cout << "  " << c->getSource()->getParent() << "." << c->getSource()->getName()
                  << "  ->  " << c->getTarget()->getParent() << "." << c->getTarget()->getName()
                  << '\n';
    }
}

// ---------------------------------------------------------------------------
// Per-simulation run
// ---------------------------------------------------------------------------

static bool run_one(const fs::path& json_path, const fs::path& out_dir)
{
    const std::string stem = json_path.stem().string(); // sim_NNN_act_fn

    cedar::proc::GroupPtr group(new cedar::proc::Group());
    group->readJson(json_path.string());

    auto field = group->getElement<cedar::dyn::NeuralField>("Neural Field");
    if (!field) throw std::runtime_error("No 'Neural Field' in " + stem);

    auto stimuli = collect_stimuli(group);

    // ── Phase 1: stimulus ON ──────────────────────────────────────────────
    run_phase(field);
    if (in_exception_state(field)) {
        std::cerr << "SKIP " << stem
                   << " — field in exception state (kernel does not fit field?); no rows written\n";
        return false;
    }
    auto u_with = flatten_mat(field->getFieldActivation()->getData());
    save_csv(u_with, out_dir / (stem + "_with_stimulus.csv"));

    // ── Phase 2: stimulus OFF ─────────────────────────────────────────────
    for (auto& s : stimuli) s->setAmplitude(0.0);
    run_phase(field);
    if (in_exception_state(field)) {
        std::cerr << "SKIP " << stem
                   << " (phase 2) — field in exception state; removing phase-1 output too\n";
        std::error_code ec; fs::remove(out_dir / (stem + "_with_stimulus.csv"), ec);
        return false;
    }
    auto u_without = flatten_mat(field->getFieldActivation()->getData());
    save_csv(u_without, out_dir / (stem + "_without_stimulus.csv"));

    const float peak_with    = *std::max_element(u_with.begin(),    u_with.end());
    const float peak_without = *std::max_element(u_without.begin(), u_without.end());
    std::cout << "[OK]  " << stem
              << "  peak_with=" << peak_with
              << "  peak_without=" << peak_without << '\n';
    return true;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

int main(int argc, char* argv[])
{
    // Cedar elements rely on Qt; a QCoreApplication must exist.
    QCoreApplication app(argc, argv);

    cedar::aux::GlobalClockSingleton::getInstance()->start();

    // --dump <one_json>: load and print the round-tripped architecture, then exit.
    if (argc >= 3 && std::string(argv[1]) == "--dump") {
        dump_architecture(fs::path(argv[2]));
        return 0;
    }

    const fs::path sim_dir = (argc >= 2)
        ? fs::path(argv[1])
        : fs::path(R"(C:\dev-files\dynamic-field-theory-software\cross-platform-validation-2d\simulations\cedar)");
    const fs::path out_dir = (argc >= 3)
        ? fs::path(argv[2])
        : fs::path(R"(C:\dev-files\dynamic-field-theory-software\cross-platform-validation-2d\data\cedar)");

    if (!fs::exists(sim_dir)) {
        std::cerr << "Simulations dir not found: " << sim_dir << '\n';
        return 1;
    }
    fs::create_directories(out_dir);

    std::vector<fs::path> json_files;
    for (const auto& e : fs::directory_iterator(sim_dir))
        if (e.path().extension() == ".json")
            json_files.push_back(e.path());
    std::sort(json_files.begin(), json_files.end());

    std::cout << "Found " << json_files.size() << " Cedar JSON files.\n";

    int ok = 0, failed = 0, skipped = 0;
    for (const auto& json_path : json_files) {
        try {
            if (run_one(json_path, out_dir)) ++ok;
            else ++skipped;
        }
        catch (const std::exception& e) {
            std::cerr << "[ERR] " << json_path.stem().string() << ": " << e.what() << '\n';
            ++failed;
        }
    }

    std::cout << "\nDone: " << ok << " OK, " << skipped << " skipped, " << failed << " failed.\n";
    return failed > 0 ? 1 : 0;
}
