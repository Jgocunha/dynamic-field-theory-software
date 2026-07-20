// cedar_benchmark_2d — headless 2D timing benchmark for Cedar DFT computation.
//
// Drives the REAL Cedar library: builds an architecture of N independent 2D
// neural fields (each: 1 GaussInput + 1 NeuralField with a lateral Gauss kernel)
// on a fixed 50x50 grid by generating a Cedar JSON and loading it with
// cedar::proc::Group::readJson, then times stepping the fields. No field
// equations are reimplemented.
//
// 2D counterpart of benchmark.cpp (Plan 01 real-API benchmark). Same protocol
// and per-field architecture, promoted to 2D.
//
// Build: registered via cedar_add_executable in the sibling CMakeLists.txt.
//
// Usage: benchmark_2d [output_csv]
//   output_csv defaults to "timings-cedar-2d.csv"
//
// Output rows (no header): cedar,headless,<N>,<run>,<steps_per_second>

#include "cedar/processing/Group.h"
#include "cedar/processing/StepTime.h"
#include "cedar/processing/Triggerable.h"
#include "cedar/processing/sources/GaussInput.h"
#include "cedar/dynamics/fields/NeuralField.h"
#include "cedar/auxiliaries/GlobalClock.h"
#include "cedar/auxiliaries/MatData.h"
#include "cedar/units/Time.h"
#include "cedar/units/prefixes.h"

#include <QCoreApplication>
#include <opencv2/core.hpp>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

// Protocol / field constants (match the 2D benchmark spec).
static constexpr int    BASE_GRID    = 50;     // reference grid side the arch positions are defined on
static constexpr double TAU          = 25.0;
static constexpr double BETA         = 100.0;
static constexpr double NOISE_GAIN   = 0.1;    // benchmark uses A>0 so the RNG cost is measured
static constexpr int    WARMUP_STEPS = 200;
static constexpr int    TIMED_STEPS  = 2000;
static constexpr int    N_RUNS       = 5;

static const cedar::unit::Time STEP_TIME(25.0 * cedar::unit::milli * cedar::unit::second);

// ---------------------------------------------------------------------------
// Architecture definitions (2D) — representative validation sim of each band
// (detection, selection, memory, multi-peak) with the 2D amplitude adjustments
// from generate_simulations_2d.py (positions on a 50-grid; selection kernel
// amp x4; memory exc/inh x2.5 + global -0.05).
// ---------------------------------------------------------------------------

enum class KernelType { Gauss, MexicanHat };

struct Stim { double amp, sigma, pos; };

struct Arch {
    std::string name;
    double      h;
    KernelType  kernel;
    double      kSigma, kAmp, kGlobal;
    double      kSigmaExc, kAmpExc, kSigmaInh, kAmpInh, kGlobalMex;
    std::vector<Stim> stimuli;
};

static const Arch& get_arch(const std::string& name)
{
    static const std::vector<Arch> archs = {
        {"detection",    -8.0,  KernelType::Gauss,      3.0, 8.0, 0.0,   0,0,0,0,0,
            {{12.0, 5.0, 25.0}}},
        {"selection",   -10.0,  KernelType::Gauss,      3.0, 20.0, -0.15, 0,0,0,0,0,
            {{10.0, 5.0, 12.5}, {10.5, 5.0, 37.5}}},
        {"memory",       -5.0,  KernelType::MexicanHat, 0,0,0,
            3.4, 44.25, 8.9, 33.75, -0.05,
            {{15.0, 5.0, 25.0}}},
        {"multi-peak",   -8.0,  KernelType::Gauss,      2.0, 5.0, 0.0,   0,0,0,0,0,
            {{12.0, 5.0, 12.5}, {12.0, 5.0, 37.5}}},
    };
    for (const auto& a : archs)
        if (a.name == name) return a;
    std::fprintf(stderr, "Unknown arch '%s'; defaulting to detection\n", name.c_str());
    return archs[0];
}

// ---------------------------------------------------------------------------
// Architecture JSON generation (N independent 2D fields)
// ---------------------------------------------------------------------------

// Cedar's Gauss kernel taps = ceil(limit*sigma), bumped to the next odd number
// (cedar::aux::kernel::Gauss::estimateWidth) — a kernel-WIDTH convention. dnfc's/
// cosivina's cutoffFactor=5 is a kernel-RADIUS convention: taps = 2*min(ceil(5*sigma),
// field-size cap)+1 (dnfc computeKernelRange). The two are NOT the same units — Cedar's
// `limit` must be roughly 2x dnfc's cutoff to reach the same tap count. This computes
// the Cedar limit that reproduces dnfc's exact tap count for a given sigma/grid, so the
// benchmarked/validated architectures do the same amount of convolution work.
// Grid-boundary capping can make dnfc's target tap count EVEN (asymmetric cap at small
// grids); Cedar's kernel is always odd, so in that case we target the nearest odd value
// below dnfc's cap (off by at most 1 tap) — this only occurs for the dev-only grid=50
// memory-inhibitory kernel, not for the grids 100/200 used in the final protocol.
static double fairCedarLimit(double sigma, int grid)
{
    const int ceilSigma5 = static_cast<int>(std::ceil(5.0 * sigma));
    const double half = (grid - 1) / 2.0;
    const int capFloor = static_cast<int>(std::floor(half));
    const int capCeil  = static_cast<int>(std::ceil(half));
    const int rangeLo = std::min(ceilSigma5, capFloor);
    const int rangeHi = std::min(ceilSigma5, capCeil);
    int targetTaps = rangeLo + rangeHi + 1;
    if (targetTaps % 2 == 0) targetTaps -= 1;
    return (targetTaps - 0.5) / sigma;
}

// 2D lateral-kernels block: single Gauss, or dual Gauss for Mexican-hat.
static std::string lateral_kernels_block_2d(const Arch& arch, int grid)
{
    std::ostringstream k;
    if (arch.kernel == KernelType::Gauss) {
        const double limit = fairCedarLimit(arch.kSigma, grid);
        k << "{\"cedar.aux.kernel.Gauss\": {\n"
             "                \"dimensionality\": \"2\", \"anchor\": [\"0\", \"0\"], \"amplitude\": \"" << arch.kAmp << "\",\n"
             "                \"sigmas\": [\"" << arch.kSigma << "\", \"" << arch.kSigma << "\"], \"normalize\": \"true\", \"shifts\": [\"0\", \"0\"], \"limit\": \"" << limit << "\"\n"
             "            }}";
    } else {
        const double limitExc = fairCedarLimit(arch.kSigmaExc, grid);
        const double limitInh = fairCedarLimit(arch.kSigmaInh, grid);
        k << "{\n"
             "                \"cedar.aux.kernel.Gauss\": {\n"
             "                    \"dimensionality\": \"2\", \"anchor\": [\"0\", \"0\"], \"amplitude\": \"" << arch.kAmpExc << "\",\n"
             "                    \"sigmas\": [\"" << arch.kSigmaExc << "\", \"" << arch.kSigmaExc << "\"], \"normalize\": \"true\", \"shifts\": [\"0\", \"0\"], \"limit\": \"" << limitExc << "\"\n"
             "                },\n"
             "                \"cedar.aux.kernel.Gauss\": {\n"
             "                    \"dimensionality\": \"2\", \"anchor\": [\"0\", \"0\"], \"amplitude\": \"-" << arch.kAmpInh << "\",\n"
             "                    \"sigmas\": [\"" << arch.kSigmaInh << "\", \"" << arch.kSigmaInh << "\"], \"normalize\": \"true\", \"shifts\": [\"0\", \"0\"], \"limit\": \"" << limitInh << "\"\n"
             "                }\n"
             "            }";
    }
    return k.str();
}

static std::string build_architecture_json(int n, const Arch& arch, const std::string& variant,
                                           int grid)
{
    const double pos_scale = static_cast<double>(grid) / BASE_GRID;
    const std::string lateral = lateral_kernels_block_2d(arch, grid);
    const std::string global_inh =
        (arch.kernel == KernelType::Gauss && arch.kGlobal != 0.0)
            ? std::to_string(arch.kGlobal)
            : (arch.kernel == KernelType::MexicanHat && arch.kGlobalMex != 0.0)
                ? std::to_string(arch.kGlobalMex) : "0";
    const std::string engine = (variant == "fftw") ? "cedar.aux.conv.FFTW"
                                                    : "cedar.aux.conv.OpenCV";

    std::ostringstream steps, conns;
    bool first_step = true, first_conn = true;
    for (int i = 0; i < n; ++i) {
        const std::string nf = "Neural Field " + std::to_string(i);

        for (size_t s = 0; s < arch.stimuli.size(); ++s) {
            const Stim& st = arch.stimuli[s];
            const std::string gi =
                "Gauss Input " + std::to_string(i) + "_" + std::to_string(s);
            if (!first_step) steps << ",\n"; first_step = false;
            steps <<
              "        \"cedar.processing.sources.GaussInput\": {\n"
              "            \"name\": \"" << gi << "\",\n"
              "            \"dimensionality\": \"2\", \"sizes\": [\"" << grid << "\", \"" << grid << "\"],\n"
              "            \"amplitude\": \"" << st.amp << "\", \"centers\": [\"" << (st.pos * pos_scale) << "\", \"" << (st.pos * pos_scale) << "\"],\n"
              "            \"sigma\": [\"" << st.sigma << "\", \"" << st.sigma << "\"], \"cyclic\": \"true\", \"comments\": \"\"\n"
              "        }";
            if (!first_conn) conns << ",\n"; first_conn = false;
            conns <<
              "        {\"source\": \"" << gi << ".Gauss input\", \"target\": \"" << nf << ".input\"}";
        }

        if (!first_step) steps << ",\n"; first_step = false;
        steps <<
          "        \"cedar.dynamics.NeuralField\": {\n"
          "            \"name\": \"" << nf << "\",\n"
          "            \"dimensionality\": \"2\", \"sizes\": [\"" << grid << "\", \"" << grid << "\"],\n"
          "            \"time scale\": \"" << TAU << "\", \"resting level\": \"" << arch.h << "\",\n"
          "            \"input noise gain\": \"" << NOISE_GAIN << "\",\n"
          "            \"sigmoid\": {\"type\": \"cedar.aux.math.ExpSigmoid\", \"threshold\": \"0\", \"beta\": \"" << BETA << "\"},\n"
          "            \"global inhibition\": \"" << global_inh << "\",\n"
          "            \"lateral kernels\": " << lateral << ",\n"
          "            \"lateral kernel convolution\": {\n"
          "                \"engine\": {\"type\": \"" << engine << "\"},\n"
          "                \"borderType\": \"Cyclic\", \"mode\": \"Same\", \"alternate even kernel center\": \"false\"\n"
          "            },\n"
          "            \"comments\": \"\"\n"
          "        }";
    }

    std::ostringstream triggers;
    triggers << "    \"triggers\": {\"cedar.processing.LoopedTrigger\": {\n"
                "        \"name\": \"LoopedTrigger\", \"fake euler step\": \"false\",\n"
                "        \"loop mode\": \"0\", \"step size\": \"1\", \"Steps\": {";
    for (int i = 0; i < n; ++i) {
        if (i > 0) triggers << ", ";
        triggers << "\"Neural Field " << i << "\": {}";
    }
    triggers << "}\n    }}";

    std::ostringstream json;
    json << "{\n    \"meta\": {\"format\": \"1\"},\n"
         << "    \"steps\": {\n" << steps.str() << "\n    },\n"
         << triggers.str() << ",\n"
         << "    \"connections\": [\n" << conns.str() << "\n    ],\n"
         << "    \"records\": {}, \"ui\": {}, \"ui view\": {}, \"ui generic\": {}\n}";
    return json.str();
}

// ---------------------------------------------------------------------------
// Behavioral-validation mode: dump field 0's final activation
// ---------------------------------------------------------------------------

static void dump_final_field(const Arch& arch, const std::string& variant, int grid,
                              int timedSteps, const std::string& dumpPath)
{
    const fs::path tmp = fs::temp_directory_path() /
        ("cedar_bench2d_dump_" + arch.name + "_" + variant + "_fs" + std::to_string(grid) + ".json");
    { std::ofstream f(tmp); f << build_architecture_json(1, arch, variant, grid); }

    cedar::proc::GroupPtr group(new cedar::proc::Group());
    group->readJson(tmp.string());

    cedar::dyn::NeuralFieldPtr field;
    std::vector<cedar::proc::sources::GaussInputPtr> stimuli;
    for (const auto& name_element : group->getElements()) {
        auto f = boost::dynamic_pointer_cast<cedar::dyn::NeuralField>(name_element.second);
        if (f && !field) field = f;
        auto gi = boost::dynamic_pointer_cast<cedar::proc::sources::GaussInput>(name_element.second);
        if (gi) stimuli.push_back(gi);
    }

    auto clock = cedar::aux::GlobalClockSingleton::getInstance();
    auto step_one = [&]() {
        clock->addTime(STEP_TIME);
        cedar::proc::ArgumentsPtr args(new cedar::proc::StepTime(STEP_TIME, clock->getTime()));
        field->onTrigger(args, cedar::proc::TriggerPtr());
    };

    if (arch.name == "memory") {
        // Establish the bump with the stimulus on, then remove it — behavioral
        // dumps for "memory" must show genuine self-sustained persistence.
        for (int t = 0; t < 100; ++t) step_one();
        for (auto& gi : stimuli) gi->setAmplitude(0.0);
    }

    for (int t = 0; t < timedSteps; ++t) step_one();

    const cv::Mat& act = field->getFieldActivation()->getData();
    std::FILE* fp = std::fopen(dumpPath.c_str(), "w");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", dumpPath.c_str()); return; }
    for (int yi = 0; yi < act.rows; ++yi)
        for (int xi = 0; xi < act.cols; ++xi)
            std::fprintf(fp, "%.10g\n", static_cast<double>(act.at<float>(yi, xi)));
    std::fclose(fp);
    std::error_code ec; fs::remove(tmp, ec);
}

// ---------------------------------------------------------------------------
// Benchmark one N value
// ---------------------------------------------------------------------------

static void run_benchmark(int n, const Arch& arch, const std::string& variant,
                          int grid, const std::string& outfile)
{
    const fs::path tmp = fs::temp_directory_path() /
        ("cedar_bench2d_" + arch.name + "_" + variant + "_fs" + std::to_string(grid) +
         "_N" + std::to_string(n) + ".json");
    { std::ofstream f(tmp); f << build_architecture_json(n, arch, variant, grid); }

    cedar::proc::GroupPtr group(new cedar::proc::Group());
    group->readJson(tmp.string());

    std::vector<cedar::dyn::NeuralFieldPtr> fields;
    std::vector<cedar::proc::sources::GaussInputPtr> stimuli;
    for (const auto& name_element : group->getElements()) {
        auto f = boost::dynamic_pointer_cast<cedar::dyn::NeuralField>(name_element.second);
        if (f) fields.push_back(f);
        auto gi = boost::dynamic_pointer_cast<cedar::proc::sources::GaussInput>(name_element.second);
        if (gi) stimuli.push_back(gi);
    }

    auto clock = cedar::aux::GlobalClockSingleton::getInstance();
    auto step_all = [&]() {
        clock->addTime(STEP_TIME);
        cedar::proc::ArgumentsPtr args(new cedar::proc::StepTime(STEP_TIME, clock->getTime()));
        for (auto& f : fields) f->onTrigger(args, cedar::proc::TriggerPtr());
    };

    // Original stimulus amplitudes, captured so the memory arch can re-establish the
    // bump before every timed run (the establish phase zeroes them).
    std::vector<double> stimAmps;
    for (auto& gi : stimuli) stimAmps.push_back(gi->getAmplitude());

    auto reset_all = [&]() {
        for (auto& f : fields) f->callReset();
    };
    // Establish the bump with the stimulus on for 100 steps, then remove it — so the
    // timed measurement covers genuine self-sustained memory maintenance, not
    // stimulus-driven activity.
    auto establish_memory_bump = [&]() {
        for (std::size_t k = 0; k < stimuli.size(); ++k) stimuli[k]->setAmplitude(stimAmps[k]);
        for (int t = 0; t < 100; ++t) step_all();
        for (auto& gi : stimuli) gi->setAmplitude(0.0);
    };

    if (arch.name == "memory") establish_memory_bump();

    for (int t = 0; t < WARMUP_STEPS; ++t) step_all();

    // Guard: if any field entered an exception state during warm-up (e.g. the FFTW
    // engine throwing "kernel size is too big for FFTW convolution" when the kernel
    // is wider than the field), the steps did no real work and the resulting "sps"
    // would be meaningless exception-handling throughput. Skip the cell entirely.
    for (auto& f : fields) {
        const auto st = f->getState();
        if (st == cedar::proc::Triggerable::STATE_EXCEPTION ||
            st == cedar::proc::Triggerable::STATE_EXCEPTION_ON_START) {
            std::fprintf(stderr,
                "SKIP cedar/%s %s grid=%d N=%d — field in exception state (kernel does not fit field?); no rows written\n",
                variant.c_str(), arch.name.c_str(), grid, n);
            std::error_code ec; fs::remove(tmp, ec);
            return;
        }
    }

    std::FILE* fp = std::fopen(outfile.c_str(), "a");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", outfile.c_str()); return; }

    for (int run = 1; run <= N_RUNS; ++run) {
        // Re-initialize to resting state before each timed run so runs 2..N do not
        // continue from the evolved state of run 1 (mirrors dnfc / Cosivina, which
        // call init() per run).
        reset_all();
        if (arch.name == "memory") establish_memory_bump();
        auto t0 = std::chrono::high_resolution_clock::now();
        for (int t = 0; t < TIMED_STEPS; ++t) step_all();
        auto t1 = std::chrono::high_resolution_clock::now();

        const double elapsed = std::chrono::duration<double>(t1 - t0).count();
        const double sps     = TIMED_STEPS / elapsed;
        std::fprintf(fp,  "cedar,%s,%s,%d,headless,%d,%d,%.2f\n",
                     variant.c_str(), arch.name.c_str(), grid, n, run, sps);
        std::printf("cedar 2D /%-6s %-12s fs=%dx%d N=%4d run=%d  %.1f steps/s\n",
                    variant.c_str(), arch.name.c_str(), grid, grid, n, run, sps);
    }
    std::fclose(fp);
    std::error_code ec; fs::remove(tmp, ec);
}

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    cv::setNumThreads(0);   // force single-threaded OpenCV convolution (fair single-thread timing)
    cedar::aux::GlobalClockSingleton::getInstance()->start();

    // Usage: benchmark_2d [output_csv] [arch] [variant] [N_csv] [grid_side]
    //   variant:   opencv (default) | fftw  — selects the convolution engine
    //   grid_side: field side length, NxN grid (default 50)
    const std::string outfile  = (argc > 1) ? argv[1] : "timings-cedar-2d.csv";
    const std::string archName = (argc > 2) ? argv[2] : "detection";
    const std::string variant  = (argc > 3) ? argv[3] : "opencv";
    const Arch& arch = get_arch(archName);

    std::vector<int> Ns;
    if (argc > 4) {
        std::string s = argv[4];
        size_t pos = 0;
        while (pos < s.size()) {
            size_t comma = s.find(',', pos);
            std::string tok = s.substr(pos, comma == std::string::npos ? std::string::npos : comma - pos);
            if (!tok.empty()) Ns.push_back(std::stoi(tok));
            if (comma == std::string::npos) break;
            pos = comma + 1;
        }
    } else {
        Ns = {5, 10, 50, 100};
    }

    const int grid = (argc > 5) ? std::stoi(argv[5]) : BASE_GRID;

    if (argc > 6) {
        // Behavioral-validation mode: dump field 0's final activation instead of timing.
        const int timedSteps = (argc > 7) ? std::stoi(argv[7]) : TIMED_STEPS;
        dump_final_field(arch, variant, grid, timedSteps, argv[6]);
        return 0;
    }

    std::printf("Cedar 2D headless benchmark [arch=%s variant=%s grid=%dx%d] (real API, cv threads=0) -> %s\n",
                arch.name.c_str(), variant.c_str(), grid, grid, outfile.c_str());
    for (int n : Ns)
        run_benchmark(n, arch, variant, grid, outfile);
    return 0;
}
