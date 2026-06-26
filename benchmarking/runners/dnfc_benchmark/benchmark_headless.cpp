// dnfc_benchmark_headless — headless timing benchmark for dnfc.
//
// Programmatically creates N independent neural fields (no JSON loading),
// each with 1 GaussStimulus + 1 GaussKernel (lateral) + 1 NormalNoise (amp=0).
// Times 5000 Euler steps and records steps/second.
//
// Usage: dnfc_benchmark_headless [output_csv]
//   output_csv defaults to "timings.csv"

#include <chrono>
#include <cstdio>
#include <memory>
#include <string>
#include <vector>

#include "simulation/simulation.h"
#include "elements/neural_field.h"
#include "elements/gauss_stimulus.h"
#include "elements/gauss_kernel.h"
#include "elements/mexican_hat_kernel.h"
#include "elements/normal_noise.h"

using namespace dnf_composer;
using namespace dnf_composer::element;

static constexpr int    FIELD_SIZE   = 100;
static constexpr double TAU          = 25.0;
static constexpr int    WARMUP_STEPS = 200;
static constexpr int    TIMED_STEPS  = 5000;
static constexpr int    N_RUNS       = 10;

// ── Architecture definitions ────────────────────────────────────────────────
// The five benchmark architectures reuse the representative sim of each band in
// the cross-platform-validation suite (detection 001, selection 021, memory 041,
// insufficient 061, multi-peak 081). Same params, only the field is replicated N
// times. This lets the benchmark exercise the kernel/coupling regimes real DFT
// models use (Gaussian, Mexican-hat, global inhibition, multi-stimulus) rather
// than a single trivial path.

enum class KernelType { Gauss, MexicanHat };

struct Stim { double amp, sigma, pos; };

struct Arch {
    std::string name;
    double      h;
    KernelType  kernel;
    // Gauss kernel params (kernel == Gauss)
    double      kWidth, kAmp, kGlobal;
    // Mexican-hat params (kernel == MexicanHat)
    double      kWidthExc, kAmpExc, kWidthInh, kAmpInh;
    // Stimuli (positions are relative offsets within each field's tile; see below)
    std::vector<Stim> stimuli;
};

// Representative-sim parameters (see generate_simulations.py). Stimulus positions
// here are the absolute in-field positions from the validation sims; for N>1 each
// field is tiled, so we shift them by the field's tile centre offset (keeping the
// relative geometry — e.g. selection's two stimuli 50 apart — intact).
static const Arch& get_arch(const std::string& name)
{
    static const std::vector<Arch> archs = {
        // detection 001
        {"detection",    -8.0,  KernelType::Gauss,      3.0, 8.0, 0.0,   0,0,0,0,
            {{12.0, 5.0, 50.0}}},
        // selection 021 (2 stimuli, global inhibition -0.15)
        {"selection",   -10.0,  KernelType::Gauss,      3.0, 5.0, -0.15, 0,0,0,0,
            {{10.0, 5.0, 25.0}, {10.5, 5.0, 75.0}}},
        // memory 041 (Mexican-hat, self-sustaining)
        {"memory",       -5.0,  KernelType::MexicanHat, 0,0,0,           3.4,17.7,8.9,13.5,
            {{15.0, 5.0, 50.0}}},
        // insufficient 061 (subthreshold)
        {"insufficient",-12.0,  KernelType::Gauss,      3.0, 3.0, 0.0,   0,0,0,0,
            {{5.0, 5.0, 50.0}}},
        // multi-peak 081 (2 narrow stimuli, narrow kernel)
        {"multi-peak",   -8.0,  KernelType::Gauss,      2.0, 5.0, 0.0,   0,0,0,0,
            {{12.0, 5.0, 25.0}, {12.0, 5.0, 75.0}}},
    };
    for (const auto& a : archs)
        if (a.name == name) return a;
    std::fprintf(stderr, "Unknown arch '%s'; defaulting to detection\n", name.c_str());
    return archs[0];
}

static std::shared_ptr<Simulation> build_simulation(int N, const Arch& arch)
{
    auto sim = std::make_shared<Simulation>("bench", 25.0, 0.0, 0.0);

    for (int i = 0; i < N; ++i) {
        const std::string si = std::to_string(i);

        // Neural field (logistic sigmoid, steepness=100)
        auto field = std::make_shared<NeuralField>(
            ElementCommonParameters{"field_" + si,
                ElementDimensions{FIELD_SIZE}},
            NeuralFieldParameters{TAU, arch.h, SigmoidFunction{0.0, 100.0}});
        sim->addElement(field);

        // Stimuli (1–3 per field depending on architecture)
        for (size_t s = 0; s < arch.stimuli.size(); ++s) {
            const Stim& st = arch.stimuli[s];
            auto stim = std::make_shared<GaussStimulus>(
                ElementCommonParameters{"stimulus_" + si + "_" + std::to_string(s),
                    ElementDimensions{FIELD_SIZE}},
                GaussStimulusParameters{st.sigma, st.amp, st.pos, true, false});
            sim->addElement(stim);
            field->addInput(stim);
        }

        // Lateral kernel: Gauss (detection/selection/insufficient/multi-peak) or
        // Mexican-hat (memory).
        if (arch.kernel == KernelType::Gauss) {
            auto kernel = std::make_shared<GaussKernel>(
                ElementCommonParameters{"kernel_" + si,
                    ElementDimensions{FIELD_SIZE}},
                GaussKernelParameters{arch.kWidth, arch.kAmp, arch.kGlobal, true, true});
            sim->addElement(kernel);
            kernel->addInput(field);
            field->addInput(kernel);
        } else {
            auto kernel = std::make_shared<MexicanHatKernel>(
                ElementCommonParameters{"kernel_" + si,
                    ElementDimensions{FIELD_SIZE}},
                MexicanHatKernelParameters{arch.kWidthExc, arch.kAmpExc,
                                           arch.kWidthInh, arch.kAmpInh, 0.0, true, true});
            sim->addElement(kernel);
            kernel->addInput(field);
            field->addInput(kernel);
        }

        // Normal noise (amplitude=0 — present to match element count)
        auto noise = std::make_shared<NormalNoise>(
            ElementCommonParameters{"noise_" + si,
                ElementDimensions{FIELD_SIZE}},
            NormalNoiseParameters{0.0});
        sim->addElement(noise);
        field->addInput(noise);
    }
    return sim;
}

static void run_benchmark(int N, const Arch& arch, const std::string& outfile)
{
    auto sim = build_simulation(N, arch);
    sim->init();

    // Warm-up
    for (int t = 0; t < WARMUP_STEPS; ++t) sim->step();

    FILE* fp = std::fopen(outfile.c_str(), "a");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", outfile.c_str()); return; }

    for (int run = 0; run < N_RUNS; ++run) {
        sim->init();

        auto t0 = std::chrono::high_resolution_clock::now();
        for (int t = 0; t < TIMED_STEPS; ++t) sim->step();
        auto t1 = std::chrono::high_resolution_clock::now();

        double elapsed = std::chrono::duration<double>(t1 - t0).count();
        double sps     = TIMED_STEPS / elapsed;
        std::fprintf(fp,  "dnfc,default,%s,headless,%d,%d,%.2f\n", arch.name.c_str(), N, run + 1, sps);
        std::printf("dnfc %-12s N=%4d run=%d  %.1f steps/s\n", arch.name.c_str(), N, run + 1, sps);
    }
    std::fclose(fp);
}

static std::vector<int> parse_n_list(const std::string& s)
{
    std::vector<int> ns;
    size_t pos = 0;
    while (pos < s.size()) {
        size_t comma = s.find(',', pos);
        const std::string tok = s.substr(pos, comma == std::string::npos ? std::string::npos : comma - pos);
        if (!tok.empty()) ns.push_back(std::stoi(tok));
        if (comma == std::string::npos) break;
        pos = comma + 1;
    }
    return ns;
}

int main(int argc, char* argv[])
{
    // Usage: benchmark_headless [output_csv] [arch] [N_csv]
    //   output_csv  default "timings-dnfc.csv"
    //   arch        detection|selection|memory|insufficient|multi-peak (default detection)
    //   N_csv       comma-separated field counts (default "10,50,100,500,1000")
    std::string      outfile = (argc > 1) ? argv[1] : "timings-dnfc.csv";
    std::string      archName = (argc > 2) ? argv[2] : "detection";
    std::vector<int> Ns       = (argc > 3) ? parse_n_list(argv[3])
                                           : std::vector<int>{10, 50, 100};
    const Arch& arch = get_arch(archName);
    std::printf("dnfc headless benchmark [arch=%s] -> %s\n", arch.name.c_str(), outfile.c_str());
    for (int N : Ns)
        run_benchmark(N, arch, outfile);
    return 0;
}
