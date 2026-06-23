// cedar_benchmark — headless timing benchmark for Cedar DFT computation.
//
// Drives the REAL Cedar library: builds an architecture of N independent neural
// fields (each: 1 GaussInput + 1 NeuralField with a lateral Gauss kernel) by
// generating a Cedar JSON and loading it with cedar::proc::Group::readJson,
// then times stepping the LoopedTrigger. No field equations are reimplemented.
//
// Architecture per field matches the cross-platform-validation single-field
// detection setup; fields are independent (no cross-coupling).
//
// Build: registered via cedar_add_executable in the sibling CMakeLists.txt.
//
// Usage: benchmark [output_csv]
//   output_csv defaults to "timings-cedar.csv"
//
// Output rows (no header): cedar,headless,<N>,<run>,<steps_per_second>

#include "cedar/processing/Group.h"
#include "cedar/processing/StepTime.h"
#include "cedar/dynamics/fields/NeuralField.h"
#include "cedar/auxiliaries/GlobalClock.h"
#include "cedar/units/Time.h"
#include "cedar/units/prefixes.h"

#include <QCoreApplication>

#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

// Protocol / field constants (match the 1D benchmark spec).
static constexpr int    FIELD_SIZE   = 100;
static constexpr double TAU          = 25.0;
static constexpr double H            = -5.0;
static constexpr double BETA         = 100.0;
static constexpr double K_SIGMA      = 3.0;
static constexpr double K_AMP        = 5.0;
static constexpr double S_SIGMA      = 5.0;
static constexpr double S_AMP        = 10.0;
static constexpr int    WARMUP_STEPS = 200;
static constexpr int    TIMED_STEPS  = 5000;
static constexpr int    N_RUNS       = 3;

static const cedar::unit::Time STEP_TIME(25.0 * cedar::unit::milli * cedar::unit::second);

// ---------------------------------------------------------------------------
// Architecture JSON generation (N independent fields)
// ---------------------------------------------------------------------------

static std::string build_architecture_json(int n)
{
    std::ostringstream steps, conns;
    for (int i = 0; i < n; ++i) {
        const int center = static_cast<int>((2 * i + 1) * FIELD_SIZE / (2 * n));
        const std::string gi = "Gauss Input " + std::to_string(i);
        const std::string nf = "Neural Field " + std::to_string(i);
        if (i > 0) { steps << ",\n"; conns << ",\n"; }
        steps <<
          "        \"cedar.processing.sources.GaussInput\": {\n"
          "            \"name\": \"" << gi << "\",\n"
          "            \"dimensionality\": \"1\", \"sizes\": [\"" << FIELD_SIZE << "\"],\n"
          "            \"amplitude\": \"" << S_AMP << "\", \"centers\": [\"" << center << "\"],\n"
          "            \"sigma\": [\"" << S_SIGMA << "\"], \"cyclic\": \"true\", \"comments\": \"\"\n"
          "        },\n"
          "        \"cedar.dynamics.NeuralField\": {\n"
          "            \"name\": \"" << nf << "\",\n"
          "            \"dimensionality\": \"1\", \"sizes\": [\"" << FIELD_SIZE << "\"],\n"
          "            \"time scale\": \"" << TAU << "\", \"resting level\": \"" << H << "\",\n"
          "            \"input noise gain\": \"0\",\n"
          "            \"sigmoid\": {\"type\": \"cedar.aux.math.AbsSigmoid\", \"threshold\": \"0\", \"beta\": \"" << BETA << "\"},\n"
          "            \"global inhibition\": \"0\",\n"
          "            \"lateral kernels\": {\"cedar.aux.kernel.Gauss\": {\n"
          "                \"dimensionality\": \"1\", \"anchor\": [\"0\"], \"amplitude\": \"" << K_AMP << "\",\n"
          "                \"sigmas\": [\"" << K_SIGMA << "\"], \"normalize\": \"true\", \"shifts\": [\"0\"], \"limit\": \"10\"\n"
          "            }},\n"
          "            \"lateral kernel convolution\": {\n"
          "                \"engine\": {\"type\": \"cedar.aux.conv.OpenCV\"},\n"
          "                \"borderType\": \"Cyclic\", \"mode\": \"Same\", \"alternate even kernel center\": \"false\"\n"
          "            },\n"
          "            \"comments\": \"\"\n"
          "        }";
        conns <<
          "        {\"source\": \"" << gi << ".Gauss input\", \"target\": \"" << nf << ".input\"}";
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
// Benchmark one N value
// ---------------------------------------------------------------------------

static void run_benchmark(int n, const std::string& outfile)
{
    // Write the architecture to a temp JSON and load it.
    const fs::path tmp = fs::temp_directory_path() / ("cedar_bench_N" + std::to_string(n) + ".json");
    { std::ofstream f(tmp); f << build_architecture_json(n); }

    cedar::proc::GroupPtr group(new cedar::proc::Group());
    group->readJson(tmp.string());

    // Collect the N fields and step them directly (a freshly loaded LoopedTrigger
    // has no listeners; stepping it would be a no-op). Each step needs a strictly
    // increasing global timestamp or Step::onTrigger skips compute().
    std::vector<cedar::dyn::NeuralFieldPtr> fields;
    for (const auto& name_element : group->getElements()) {
        auto f = boost::dynamic_pointer_cast<cedar::dyn::NeuralField>(name_element.second);
        if (f) fields.push_back(f);
    }

    auto clock = cedar::aux::GlobalClockSingleton::getInstance();
    auto step_all = [&]() {
        clock->addTime(STEP_TIME);
        cedar::proc::ArgumentsPtr args(new cedar::proc::StepTime(STEP_TIME, clock->getTime()));
        for (auto& f : fields) f->onTrigger(args, cedar::proc::TriggerPtr());
    };

    // Warm-up
    for (int t = 0; t < WARMUP_STEPS; ++t) step_all();

    std::FILE* fp = std::fopen(outfile.c_str(), "a");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", outfile.c_str()); return; }

    for (int run = 1; run <= N_RUNS; ++run) {
        auto t0 = std::chrono::high_resolution_clock::now();
        for (int t = 0; t < TIMED_STEPS; ++t) step_all();
        auto t1 = std::chrono::high_resolution_clock::now();

        const double elapsed = std::chrono::duration<double>(t1 - t0).count();
        const double sps     = TIMED_STEPS / elapsed;
        std::fprintf(fp,  "cedar,headless,%d,%d,%.2f\n", n, run, sps);
        std::printf("cedar headless  N=%4d  run=%d  %.1f steps/s\n", n, run, sps);
    }
    std::fclose(fp);
    std::error_code ec; fs::remove(tmp, ec);
}

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    cedar::aux::GlobalClockSingleton::getInstance()->start();

    const std::string outfile = (argc > 1) ? argv[1] : "timings-cedar.csv";
    std::printf("Cedar headless benchmark (real API) -> %s\n", outfile.c_str());
    for (int n : {10, 50, 100, 500, 1000})
        run_benchmark(n, outfile);
    return 0;
}
