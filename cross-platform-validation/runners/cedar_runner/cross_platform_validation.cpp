// cedar_runner — Cross-framework algebraic equivalence test suite runner
//
// Reads every JSON file from simulations/cedar, runs the two-phase protocol
// (500 steps stimulus ON, 500 steps stimulus OFF), and saves activation
// profiles to data/cedar/ as CSV files.
//
// This runner implements Cedar's neural field equations independently
// (without linking against Cedar's libraries) to validate algebraic equivalence.
// The implementation uses:
//   - Cedar's AbsSigmoid:   σ(u) = 0.5 * (1 + β*u / (1 + β*|u|)),  β=100
//   - Cedar's Heaviside:    σ(u) = (u > threshold) ? 1.0f : 0.0f
//   - Euler integration:    u_{t+1} = u_t + (deltaT/tau)*(-u_t + h + k*σ(u_t) + S)
//   - Circular convolution with Gauss kernel, support = round_odd(limit * σ)
//   - Float32 arithmetic (matching Cedar's CV_32F precision)
//
// Build: requires a C++20 compiler and nlohmann/json.
//   cmake -B build && cmake --build build
//
// Usage: cedar_runner <simulations_dir> <output_dir>
//   simulations_dir: path to simulations/cedar  (contains sim_NNN_*.json)
//   output_dir:      path to data/cedar

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <numeric>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;
using json = nlohmann::json;

// ---------------------------------------------------------------------------
// Types — float32 to match Cedar's CV_32F
// ---------------------------------------------------------------------------

using f32 = float;
using Vec = std::vector<f32>;

// ---------------------------------------------------------------------------
// Sigmoid functions (matching Cedar exactly)
// ---------------------------------------------------------------------------

inline f32 sigmoid_abssigmoid(f32 u, f32 beta, f32 threshold = 0.0f)
{
    const f32 d = u - threshold;
    return 0.5f * (1.0f + beta * d / (1.0f + beta * std::abs(d)));
}

inline f32 sigmoid_heaviside(f32 u, f32 threshold = 0.0f)
{
    return u > threshold ? 1.0f : 0.0f;
}

// ---------------------------------------------------------------------------
// Gaussian kernel construction
// Cedar: total kernel size = round_to_odd(limit * sigma)
// ---------------------------------------------------------------------------

static int round_to_odd(f32 v)
{
    int n = static_cast<int>(std::round(v));
    if (n % 2 == 0) n += 1;
    return n;
}

// Build a normalised Gaussian kernel of size (2*half+1) with half-support=half.
// normalized=true matches Cedar's default.
static Vec build_gauss_kernel(f32 sigma, f32 amplitude, f32 limit, bool normalized)
{
    const int total = round_to_odd(limit * sigma);
    const int half  = total / 2;
    Vec kernel(total);
    f32 sum = 0.0f;
    for (int i = 0; i < total; ++i) {
        const f32 x = static_cast<f32>(i - half);
        kernel[i] = std::exp(-0.5f * (x / sigma) * (x / sigma));
        sum += kernel[i];
    }
    const f32 norm = normalized ? sum : 1.0f;
    for (auto& v : kernel) v = amplitude * v / norm;
    return kernel;
}

// ---------------------------------------------------------------------------
// Circular convolution (valid mode with wrap-around)
// Matching Cedar's borderType=Cyclic, mode=Same, conv.FFTW
// ---------------------------------------------------------------------------

static Vec circular_conv(const Vec& signal, const Vec& kernel)
{
    const int N = static_cast<int>(signal.size());
    const int K = static_cast<int>(kernel.size());
    const int half = K / 2;
    Vec out(N, 0.0f);
    for (int i = 0; i < N; ++i) {
        f32 acc = 0.0f;
        for (int k = 0; k < K; ++k) {
            const int j = ((i - half + k) % N + N) % N;
            acc += kernel[k] * signal[j];
        }
        out[i] = acc;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Parsed simulation parameters
// ---------------------------------------------------------------------------

struct Stimulus {
    f32 amplitude;
    f32 sigma;
    f32 position;  // 1-based (Cedar 0-based: stored as-is, comparison corrects offset)
};

struct KernelSpec {
    // Excitatory Gauss kernel
    f32 sigma_exc;
    f32 amplitude_exc;
    f32 limit_exc;
    // Optional inhibitory Gauss kernel (memory case — amplitude stored negative)
    bool has_inh = false;
    f32 sigma_inh;
    f32 amplitude_inh;  // already negative
    f32 limit_inh;
};

struct SimParams {
    int   field_size    = 100;
    f32   tau           = 25.0f;
    f32   h             = -8.0f;
    f32   global_inh    = 0.0f;  // Cedar's "global inhibition" param
    std::string act_fn; // "abssigmoid_b100" or "heaviside"
    f32   beta          = 100.0f;
    f32   threshold     = 0.0f;
    std::vector<Stimulus> stimuli;
    KernelSpec kernel;
};

// ---------------------------------------------------------------------------
// Cedar JSON parser
// ---------------------------------------------------------------------------

// Cedar JSON uses string values. Helper to get numeric field as float.
static f32 jf(const json& obj, const std::string& key, f32 def = 0.0f)
{
    if (!obj.contains(key)) return def;
    const auto& v = obj[key];
    if (v.is_string()) return std::stof(v.get<std::string>());
    return v.get<f32>();
}

static std::string js(const json& obj, const std::string& key, const std::string& def = "")
{
    if (!obj.contains(key)) return def;
    return obj[key].get<std::string>();
}

// Parse a single cedar.aux.kernel.Gauss JSON object.
static void parse_gauss_kernel_entry(const json& gk, f32& sigma, f32& amp, f32& limit)
{
    const auto& sigmas = gk["sigmas"];
    if (sigmas.is_array())
        sigma = std::stof(sigmas[0].get<std::string>());
    else
        sigma = jf(gk, "sigmas", 3.0f);

    amp   = jf(gk, "amplitude", 1.0f);
    limit = jf(gk, "limit", 10.0f);
}

// Parse Cedar's JSON into SimParams.
// Cedar JSON uses duplicate keys for memory (two cedar.aux.kernel.Gauss).
// We read the raw JSON text to handle duplicate keys manually.
static SimParams parse_cedar_json(const fs::path& path, const std::string& act_fn_hint)
{
    SimParams p;
    p.act_fn = act_fn_hint;

    // Read raw file text — needed to detect duplicate keys.
    std::ifstream raw_f(path);
    std::string raw((std::istreambuf_iterator<char>(raw_f)),
                     std::istreambuf_iterator<char>());

    json j = json::parse(raw);
    const json& steps = j["steps"];

    // ── Neural field ───────────────────────────────────────────────────────
    const json& nf = steps["cedar.dynamics.NeuralField"];
    p.tau        = jf(nf, "time scale", 25.0f);
    p.h          = jf(nf, "resting level", -8.0f);
    p.global_inh = jf(nf, "global inhibition", 0.0f);

    const json& sig = nf["sigmoid"];
    std::string sig_type = js(sig, "type");
    if (sig_type.find("HeavisideSigmoid") != std::string::npos) {
        p.act_fn  = "heaviside";
        p.threshold = jf(sig, "threshold", 0.0f);
    } else {
        p.act_fn  = "abssigmoid_b100";
        p.beta    = jf(sig, "beta", 100.0f);
        p.threshold = jf(sig, "threshold", 0.0f);
    }

    const auto& sizes = nf["sizes"];
    p.field_size = std::stoi(sizes[0].get<std::string>());

    // ── Stimuli ────────────────────────────────────────────────────────────
    // Cedar JSON may have one or two GaussInput steps (same key with different "name").
    // nlohmann::json keeps only the LAST value for duplicate keys.
    // We handle this by counting occurrences in the raw text.
    auto count_key = [&](const std::string& key) -> int {
        int count = 0;
        size_t pos = 0;
        while ((pos = raw.find('"' + key + '"', pos)) != std::string::npos) {
            ++count; pos += key.size() + 2;
        }
        return count;
    };

    int n_gauss_inputs = count_key("cedar.processing.sources.GaussInput");

    // For multi-stimulus: parse raw JSON differently.
    // For single stimulus: nlohmann already gives it.
    if (n_gauss_inputs == 1) {
        const json& gi = steps["cedar.processing.sources.GaussInput"];
        Stimulus s;
        s.amplitude = jf(gi, "amplitude", 12.0f);
        const auto& sigma_arr = gi["sigma"];
        s.sigma     = sigma_arr.is_array()
                    ? std::stof(sigma_arr[0].get<std::string>())
                    : jf(gi, "sigma", 5.0f);
        const auto& centers_arr = gi["centers"];
        // Cedar is 0-based; store as-is. Offset correction happens in analysis.R.
        s.position  = centers_arr.is_array()
                    ? std::stof(centers_arr[0].get<std::string>())
                    : jf(gi, "centers", 50.0f);
        p.stimuli.push_back(s);
    } else {
        // Multiple GaussInput steps: parse from raw text.
        // Find all "amplitude" and "centers" values within GaussInput blocks.
        // Simple approach: extract each block between consecutive GaussInput occurrences.
        std::string search = "\"cedar.processing.sources.GaussInput\"";
        std::vector<size_t> positions;
        size_t pos = 0;
        while ((pos = raw.find(search, pos)) != std::string::npos) {
            positions.push_back(pos);
            pos += search.size();
        }
        for (size_t i = 0; i < positions.size(); ++i) {
            // Extract block between this and next occurrence (or end of steps section)
            size_t start = raw.find('{', positions[i]);
            size_t end   = (i + 1 < positions.size())
                         ? positions[i + 1]
                         : raw.find("\"cedar.dynamics.NeuralField\"", positions[i]);
            std::string block = raw.substr(start, end - start);
            // Parse the block as JSON (may have trailing comma — remove it)
            if (!block.empty() && block.back() == ',') block.pop_back();
            // Balance braces
            int depth = 0;
            size_t close = 0;
            for (size_t k = 0; k < block.size(); ++k) {
                if (block[k] == '{') ++depth;
                else if (block[k] == '}') { --depth; if (depth == 0) { close = k; break; } }
            }
            block = block.substr(0, close + 1);
            try {
                json gi_j = json::parse(block);
                Stimulus s;
                s.amplitude = jf(gi_j, "amplitude", 12.0f);
                const auto& sigma_arr = gi_j["sigma"];
                s.sigma = sigma_arr.is_array()
                        ? std::stof(sigma_arr[0].get<std::string>())
                        : jf(gi_j, "sigma", 5.0f);
                const auto& centers = gi_j["centers"];
                s.position = centers.is_array()
                           ? std::stof(centers[0].get<std::string>())
                           : jf(gi_j, "centers", 50.0f);
                p.stimuli.push_back(s);
            } catch (...) {}
        }
    }

    // ── Kernels ────────────────────────────────────────────────────────────
    int n_gauss_kernels = count_key("cedar.aux.kernel.Gauss");

    const json& lk = nf["lateral kernels"];
    if (n_gauss_kernels == 1) {
        // Single Gauss kernel (detection / selection / insufficient / multi-peak)
        const json& gk = lk["cedar.aux.kernel.Gauss"];
        parse_gauss_kernel_entry(gk, p.kernel.sigma_exc, p.kernel.amplitude_exc, p.kernel.limit_exc);
        p.kernel.has_inh = false;
    } else {
        // Two Gauss kernels (memory: excitatory + inhibitory).
        // nlohmann keeps only the last one under the duplicate key.
        // We parse both from the raw text.
        std::string ksearch = "\"cedar.aux.kernel.Gauss\"";
        std::vector<size_t> kpos;
        size_t kp = 0;
        while ((kp = raw.find(ksearch, kp)) != std::string::npos) {
            kpos.push_back(kp); kp += ksearch.size();
        }
        // Parse first and second kernel blocks
        auto parse_kernel_block = [&](size_t from, size_t to) -> std::tuple<f32,f32,f32> {
            size_t st = raw.find('{', from);
            std::string blk = raw.substr(st, to - st);
            // Trim to balanced braces
            int depth = 0; size_t cl = 0;
            for (size_t k = 0; k < blk.size(); ++k) {
                if (blk[k] == '{') ++depth;
                else if (blk[k] == '}') { --depth; if (depth == 0) { cl = k; break; } }
            }
            blk = blk.substr(0, cl + 1);
            json gk_j = json::parse(blk);
            f32 sig, amp, lim;
            parse_gauss_kernel_entry(gk_j, sig, amp, lim);
            return {sig, amp, lim};
        };

        if (kpos.size() >= 2) {
            auto [s0, a0, l0] = parse_kernel_block(kpos[0], kpos[1]);
            size_t end2 = raw.find("\"lateral kernel convolution\"", kpos[1]);
            auto [s1, a1, l1] = parse_kernel_block(kpos[1], end2);

            // First kernel = excitatory (positive amplitude), second = inhibitory (negative)
            p.kernel.sigma_exc     = s0;
            p.kernel.amplitude_exc = a0;
            p.kernel.limit_exc     = l0;
            p.kernel.has_inh       = true;
            p.kernel.sigma_inh     = s1;
            p.kernel.amplitude_inh = a1; // stored as negative value already
            p.kernel.limit_inh     = l1;
        }
    }

    return p;
}

// ---------------------------------------------------------------------------
// Neural field step
// ---------------------------------------------------------------------------

static Vec apply_sigmoid(const Vec& u, const SimParams& p)
{
    Vec out(u.size());
    if (p.act_fn == "heaviside") {
        for (size_t i = 0; i < u.size(); ++i)
            out[i] = sigmoid_heaviside(u[i], p.threshold);
    } else {
        for (size_t i = 0; i < u.size(); ++i)
            out[i] = sigmoid_abssigmoid(u[i], p.beta, p.threshold);
    }
    return out;
}

static void run_simulation(Vec& u, const std::vector<Stimulus>& stimuli,
                           const SimParams& p, int n_steps)
{
    const int N = p.field_size;
    const f32 dt_over_tau = 25.0f / p.tau; // Cedar uses deltaT=1 internal, tau in ms

    // Build kernel(s)
    Vec kernel_exc = build_gauss_kernel(p.kernel.sigma_exc, p.kernel.amplitude_exc,
                                        p.kernel.limit_exc, true);
    Vec kernel_inh;
    if (p.kernel.has_inh)
        kernel_inh = build_gauss_kernel(p.kernel.sigma_inh, std::abs(p.kernel.amplitude_inh),
                                         p.kernel.limit_inh, true);

    // Build stimulus vector (Cedar 0-based; position stored as 0-based from JSON)
    Vec stim_vec(N, 0.0f);
    for (const auto& s : stimuli) {
        const f32 sigma = s.sigma;
        const f32 pos   = s.position; // 0-based
        f32 sum = 0.0f;
        std::vector<f32> g(N);
        for (int i = 0; i < N; ++i) {
            // Circular distance
            f32 dx = static_cast<f32>(i) - pos;
            while (dx >  N / 2.0f) dx -= N;
            while (dx < -N / 2.0f) dx += N;
            g[i] = std::exp(-0.5f * (dx / sigma) * (dx / sigma));
            sum += g[i];
        }
        // Cedar GaussInput is NOT normalised by default (amplitude = peak)
        for (int i = 0; i < N; ++i)
            stim_vec[i] += s.amplitude * g[i] / sum * sum; // non-normalized: just scale by amp
        // Actually Cedar GaussInput with no normalization: output = amp * exp(-0.5*(dx/sigma)^2)
        // Redo without normalization:
        for (int i = 0; i < N; ++i) stim_vec[i] = 0.0f; // reset
    }
    for (const auto& s : stimuli) {
        const f32 sigma = s.sigma;
        const f32 pos   = s.position;
        for (int i = 0; i < N; ++i) {
            f32 dx = static_cast<f32>(i) - pos;
            while (dx >  N / 2.0f) dx -= N;
            while (dx < -N / 2.0f) dx += N;
            stim_vec[i] += s.amplitude * std::exp(-0.5f * (dx / sigma) * (dx / sigma));
        }
    }

    for (int t = 0; t < n_steps; ++t) {
        // Compute sigmoid output
        const Vec sig_u = apply_sigmoid(u, p);

        // Lateral interaction: convolve sigmoid output with kernel
        Vec interaction = circular_conv(sig_u, kernel_exc);
        if (p.kernel.has_inh) {
            // Inhibitory kernel already has negative amplitude; subtract magnitude
            Vec inh = circular_conv(sig_u, kernel_inh);
            f32 inh_sign = (p.kernel.amplitude_inh < 0.0f) ? -1.0f : 1.0f;
            for (int i = 0; i < N; ++i)
                interaction[i] += inh_sign * inh[i];
        }

        // Global inhibition: Cedar applies to sum of sigma(u)
        f32 full_sum = 0.0f;
        for (f32 v : sig_u) full_sum += v;
        const f32 global_term = p.global_inh * full_sum;

        // Euler step: u_{t+1} = u_t + dt/tau * (-u_t + h + interaction + stim - global)
        for (int i = 0; i < N; ++i)
            u[i] += dt_over_tau * (-u[i] + p.h + interaction[i] + stim_vec[i] - global_term);
    }
}

// ---------------------------------------------------------------------------
// CSV save
// ---------------------------------------------------------------------------

static void save_csv(const Vec& data, const fs::path& path)
{
    std::ofstream f(path);
    if (!f) throw std::runtime_error("Cannot open: " + path.string());
    for (size_t i = 0; i < data.size(); ++i) {
        if (i > 0) f << ',';
        f << data[i];
    }
    f << '\n';
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

int main(int argc, char* argv[])
{
    const fs::path sim_dir = (argc >= 2)
        ? fs::path(argv[1])
        : fs::path(R"(C:\Users\gaspa\OneDrive - Universidade do Minho\phd-degree\journals\SoftwareX\cross-platform-validation\simulations\cedar)");

    const fs::path out_dir = (argc >= 3)
        ? fs::path(argv[2])
        : fs::path(R"(C:\Users\gaspa\OneDrive - Universidade do Minho\phd-degree\journals\SoftwareX\cross-platform-validation\data\cedar)");

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

    int ok = 0, failed = 0;

    for (const auto& json_path : json_files) {
        const std::string stem = json_path.stem().string(); // sim_NNN_act_fn

        // Infer activation function from filename
        std::string act_fn = stem.find("heaviside") != std::string::npos
                           ? "heaviside" : "abssigmoid_b100";

        try {
            SimParams p = parse_cedar_json(json_path, act_fn);

            // Initialise field at resting level
            Vec u(p.field_size, p.h);

            // Phase 1: stimulus ON
            run_simulation(u, p.stimuli, p, 500);
            save_csv(u, out_dir / (stem + "_with_stimulus.csv"));
            f32 peak_with = *std::max_element(u.begin(), u.end());

            // Phase 2: stimulus OFF (zero stimuli)
            std::vector<Stimulus> no_stim;
            run_simulation(u, no_stim, p, 500);
            save_csv(u, out_dir / (stem + "_without_stimulus.csv"));
            f32 peak_without = *std::max_element(u.begin(), u.end());

            std::cout << "[OK]  " << stem
                      << "  peak_with=" << peak_with
                      << "  peak_without=" << peak_without << '\n';
            ++ok;
        }
        catch (const std::exception& e) {
            std::cerr << "[ERR] " << stem << ": " << e.what() << '\n';
            ++failed;
        }
    }

    std::cout << "\nDone: " << ok << " OK, " << failed << " failed.\n";
    return failed > 0 ? 1 : 0;
}
