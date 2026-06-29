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
#include "cedar/processing/Triggerable.h"
#include "cedar/dynamics/fields/NeuralField.h"
#include "cedar/auxiliaries/GlobalClock.h"
#include "cedar/units/Time.h"
#include "cedar/units/prefixes.h"

#include <QCoreApplication>
#include <opencv2/core.hpp>

#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

// Protocol / field constants (match the 1D benchmark spec).
static constexpr int    BASE_SIZE    = 100;    // reference grid the arch positions are defined on
static constexpr double TAU          = 25.0;
static constexpr double BETA         = 100.0;
static constexpr double NOISE_GAIN   = 0.1;    // benchmark uses A>0 so the RNG cost is measured
static constexpr int    WARMUP_STEPS = 200;
static constexpr int    TIMED_STEPS  = 5000;
static constexpr int    N_RUNS       = 10;

static const cedar::unit::Time STEP_TIME(25.0 * cedar::unit::milli * cedar::unit::second);

// ---------------------------------------------------------------------------
// Architecture definitions — reuse the representative validation sim of each band
// (detection 001, selection 021, memory 041, multi-peak 081). Matches the dnfc
// benchmark runner's Arch set and the cross-platform-validation Cedar JSON
// generator (build_cedar_json_str in generate_simulations.py).
// ---------------------------------------------------------------------------

enum class KernelType { Gauss, MexicanHat };

struct Stim { double amp, sigma, pos; };

struct Arch {
    std::string name;
    double      h;
    KernelType  kernel;
    double      kSigma, kAmp, kGlobal;            // Gauss kernel
    double      kSigmaExc, kAmpExc, kSigmaInh, kAmpInh;  // Mexican-hat
    std::vector<Stim> stimuli;
};

static const Arch& get_arch(const std::string& name)
{
    static const std::vector<Arch> archs = {
        {"detection",    -8.0,  KernelType::Gauss,      3.0, 8.0, 0.0,   0,0,0,0,
            {{12.0, 5.0, 50.0}}},
        {"selection",   -10.0,  KernelType::Gauss,      3.0, 5.0, -0.15, 0,0,0,0,
            {{10.0, 5.0, 25.0}, {10.5, 5.0, 75.0}}},
        {"memory",       -5.0,  KernelType::MexicanHat, 0,0,0,           3.4,17.7,8.9,13.5,
            {{15.0, 5.0, 50.0}}},
        {"multi-peak",   -8.0,  KernelType::Gauss,      2.0, 5.0, 0.0,   0,0,0,0,
            {{12.0, 5.0, 25.0}, {12.0, 5.0, 75.0}}},
    };
    for (const auto& a : archs)
        if (a.name == name) return a;
    std::fprintf(stderr, "Unknown arch '%s'; defaulting to detection\n", name.c_str());
    return archs[0];
}

// ---------------------------------------------------------------------------
// Architecture JSON generation (N independent fields)
// ---------------------------------------------------------------------------

// Emit the "lateral kernels" block for an architecture. Mexican-hat is two Gauss
// entries (excitatory + negative inhibitory), matching the validation generator.
static std::string lateral_kernels_block(const Arch& arch)
{
    std::ostringstream k;
    if (arch.kernel == KernelType::Gauss) {
        k << "{\"cedar.aux.kernel.Gauss\": {\n"
             "                \"dimensionality\": \"1\", \"anchor\": [\"0\"], \"amplitude\": \"" << arch.kAmp << "\",\n"
             "                \"sigmas\": [\"" << arch.kSigma << "\"], \"normalize\": \"true\", \"shifts\": [\"0\"], \"limit\": \"5\"\n"
             "            }}";
    } else {
        k << "{\n"
             "                \"cedar.aux.kernel.Gauss\": {\n"
             "                    \"dimensionality\": \"1\", \"anchor\": [\"0\"], \"amplitude\": \"" << arch.kAmpExc << "\",\n"
             "                    \"sigmas\": [\"" << arch.kSigmaExc << "\"], \"normalize\": \"true\", \"shifts\": [\"0\"], \"limit\": \"5\"\n"
             "                },\n"
             "                \"cedar.aux.kernel.Gauss\": {\n"
             "                    \"dimensionality\": \"1\", \"anchor\": [\"0\"], \"amplitude\": \"-" << arch.kAmpInh << "\",\n"
             "                    \"sigmas\": [\"" << arch.kSigmaInh << "\"], \"normalize\": \"true\", \"shifts\": [\"0\"], \"limit\": \"5\"\n"
             "                }\n"
             "            }";
    }
    return k.str();
}

static std::string build_architecture_json(int n, const Arch& arch, const std::string& variant,
                                           int field_size)
{
    const double pos_scale = static_cast<double>(field_size) / BASE_SIZE;
    const std::string lateral = lateral_kernels_block(arch);
    const std::string global_inh =
        (arch.kernel == KernelType::Gauss && arch.kGlobal != 0.0)
            ? std::to_string(arch.kGlobal) : "0";
    // Convolution engine: OpenCV spatial filter2D (default) or FFTW Fourier-domain.
    const std::string engine = (variant == "fftw") ? "cedar.aux.conv.FFTW"
                                                    : "cedar.aux.conv.OpenCV";

    std::ostringstream steps, conns;
    bool first_step = true, first_conn = true;
    for (int i = 0; i < n; ++i) {
        const std::string nf = "Neural Field " + std::to_string(i);

        // Stimuli for this field (1–3 GaussInput sources).
        for (size_t s = 0; s < arch.stimuli.size(); ++s) {
            const Stim& st = arch.stimuli[s];
            const std::string gi =
                "Gauss Input " + std::to_string(i) + "_" + std::to_string(s);
            if (!first_step) steps << ",\n"; first_step = false;
            steps <<
              "        \"cedar.processing.sources.GaussInput\": {\n"
              "            \"name\": \"" << gi << "\",\n"
              "            \"dimensionality\": \"1\", \"sizes\": [\"" << field_size << "\"],\n"
              "            \"amplitude\": \"" << st.amp << "\", \"centers\": [\"" << (st.pos * pos_scale) << "\"],\n"
              "            \"sigma\": [\"" << st.sigma << "\"], \"cyclic\": \"true\", \"comments\": \"\"\n"
              "        }";
            if (!first_conn) conns << ",\n"; first_conn = false;
            conns <<
              "        {\"source\": \"" << gi << ".Gauss input\", \"target\": \"" << nf << ".input\"}";
        }

        if (!first_step) steps << ",\n"; first_step = false;
        steps <<
          "        \"cedar.dynamics.NeuralField\": {\n"
          "            \"name\": \"" << nf << "\",\n"
          "            \"dimensionality\": \"1\", \"sizes\": [\"" << field_size << "\"],\n"
          "            \"time scale\": \"" << TAU << "\", \"resting level\": \"" << arch.h << "\",\n"
          "            \"input noise gain\": \"" << NOISE_GAIN << "\",\n"
          "            \"sigmoid\": {\"type\": \"cedar.aux.math.AbsSigmoid\", \"threshold\": \"0\", \"beta\": \"" << BETA << "\"},\n"
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
// Benchmark one N value
// ---------------------------------------------------------------------------

static void run_benchmark(int n, const Arch& arch, const std::string& variant,
                          int field_size, const std::string& outfile)
{
    // Write the architecture to a temp JSON and load it.
    const fs::path tmp = fs::temp_directory_path() /
        ("cedar_bench_" + arch.name + "_" + variant + "_fs" + std::to_string(field_size) +
         "_N" + std::to_string(n) + ".json");
    { std::ofstream f(tmp); f << build_architecture_json(n, arch, variant, field_size); }

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

    // Guard: if any field entered an exception state during warm-up (e.g. the FFTW
    // engine throwing "kernel size is too big for FFTW convolution" when the kernel
    // is wider than the field), the steps did no real work and the resulting "sps"
    // would be meaningless exception-handling throughput. Skip the cell entirely.
    for (auto& f : fields) {
        const auto st = f->getState();
        if (st == cedar::proc::Triggerable::STATE_EXCEPTION ||
            st == cedar::proc::Triggerable::STATE_EXCEPTION_ON_START) {
            std::fprintf(stderr,
                "SKIP cedar/%s %s fs=%d N=%d — field in exception state (kernel does not fit field?); no rows written\n",
                variant.c_str(), arch.name.c_str(), field_size, n);
            std::error_code ec; fs::remove(tmp, ec);
            return;
        }
    }

    std::FILE* fp = std::fopen(outfile.c_str(), "a");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", outfile.c_str()); return; }

    for (int run = 1; run <= N_RUNS; ++run) {
        auto t0 = std::chrono::high_resolution_clock::now();
        for (int t = 0; t < TIMED_STEPS; ++t) step_all();
        auto t1 = std::chrono::high_resolution_clock::now();

        const double elapsed = std::chrono::duration<double>(t1 - t0).count();
        const double sps     = TIMED_STEPS / elapsed;
        std::fprintf(fp,  "cedar,%s,%s,%d,headless,%d,%d,%.2f\n",
                     variant.c_str(), arch.name.c_str(), field_size, n, run, sps);
        std::printf("cedar/%-6s %-12s fs=%4d N=%4d run=%d  %.1f steps/s\n",
                    variant.c_str(), arch.name.c_str(), field_size, n, run, sps);
    }
    std::fclose(fp);
    std::error_code ec; fs::remove(tmp, ec);
}

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    cv::setNumThreads(0);   // force single-threaded OpenCV convolution (fair single-thread timing)
    cedar::aux::GlobalClockSingleton::getInstance()->start();

    // Usage: benchmark [output_csv] [arch] [variant] [N_csv] [field_size]
    //   variant:    opencv (default) | fftw  — selects the convolution engine
    //   field_size: field length (default 100)
    const std::string outfile  = (argc > 1) ? argv[1] : "timings-cedar.csv";
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

    const int field_size = (argc > 5) ? std::stoi(argv[5]) : BASE_SIZE;

    std::printf("Cedar headless benchmark [arch=%s variant=%s fs=%d] (real API, cv threads=0) -> %s\n",
                arch.name.c_str(), variant.c_str(), field_size, outfile.c_str());
    for (int n : Ns)
        run_benchmark(n, arch, variant, field_size, outfile);
    return 0;
}
