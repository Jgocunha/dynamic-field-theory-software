// cedar_benchmark — headless timing benchmark for Cedar DFT computation.
//
// Implements Cedar's float32 Euler integration directly (no Cedar library needed),
// matching the same approach used in the cross-platform validation cedar_runner.
//
// Architecture: N independent neural fields, each with 1 Gaussian stimulus,
// 1 Gaussian kernel (lateral), and 1 zero-amplitude noise element.
// Total: 4N elements per benchmark configuration.
//
// Usage: cedar_benchmark [output_csv]
//   output_csv defaults to "timings.csv"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <chrono>
#include <string>
#include <vector>
#include <algorithm>
#include <initializer_list>

static constexpr int   FIELD_SIZE   = 100;
static constexpr float TAU          = 25.0f;
static constexpr float DT           = 25.0f;
static constexpr float H            = -5.0f;
static constexpr float BETA         = 100.0f;
static constexpr float K_SIGMA      = 3.0f;
static constexpr float K_AMP        = 5.0f;
static constexpr float K_LIMIT      = 10.0f;   // Cedar kernel limit factor
static constexpr float S_SIGMA      = 5.0f;
static constexpr float S_AMP        = 10.0f;
static constexpr int   WARMUP_STEPS = 200;
static constexpr int   TIMED_STEPS  = 5000;
static constexpr int   N_RUNS       = 3;

// AbsSigmoid matching Cedar's cedar.aux.math.AbsSigmoid (beta=100, threshold=0)
static inline float abs_sigmoid(float x)
{
    float bx = BETA * x;
    return 0.5f * (1.0f + bx / (1.0f + std::abs(bx)));
}

// Build a normalised Gaussian kernel with Cedar's limit convention.
// half_width = round_odd( limit * sigma ) where round_odd rounds to odd integer.
static std::vector<float> make_gauss_kernel(float sigma, float amplitude)
{
    int half_w = static_cast<int>(std::round(K_LIMIT * sigma));
    int ksize  = 2 * half_w + 1;
    std::vector<float> k(ksize);
    float sum = 0.0f;
    for (int i = 0; i < ksize; ++i) {
        float x = static_cast<float>(i - half_w);
        k[i] = std::exp(-x * x / (2.0f * sigma * sigma));
        sum += k[i];
    }
    for (auto& v : k) v *= (amplitude / sum);
    return k;
}

// Circular convolution of sigmoid(u) with kernel k → out.
static void convolve(const std::vector<float>& u,
                     const std::vector<float>& k,
                     std::vector<float>& out)
{
    int half = static_cast<int>(k.size()) / 2;
    for (int i = 0; i < FIELD_SIZE; ++i) {
        float s = 0.0f;
        for (int j = 0; j < static_cast<int>(k.size()); ++j) {
            int idx = ((i - half + j) % FIELD_SIZE + FIELD_SIZE) % FIELD_SIZE;
            s += k[j] * abs_sigmoid(u[idx]);
        }
        out[i] = s;
    }
}

// Circular Gaussian stimulus (not normalised, matching Cedar's default).
static std::vector<float> make_gauss_stimulus(int center, float sigma, float amplitude)
{
    std::vector<float> s(FIELD_SIZE);
    for (int i = 0; i < FIELD_SIZE; ++i) {
        float x = static_cast<float>(i - center);
        if (x >  FIELD_SIZE / 2.0f) x -= FIELD_SIZE;
        if (x < -FIELD_SIZE / 2.0f) x += FIELD_SIZE;
        s[i] = amplitude * std::exp(-x * x / (2.0f * sigma * sigma));
    }
    return s;
}

static void run_benchmark(int N, const std::string& outfile)
{
    // Pre-build shared kernel (same parameters for all fields)
    auto kernel = make_gauss_kernel(K_SIGMA, K_AMP);

    // Per-field state
    std::vector<std::vector<float>> fields(N, std::vector<float>(FIELD_SIZE, H));
    std::vector<std::vector<float>> stimuli(N);
    std::vector<std::vector<float>> conv_buf(N, std::vector<float>(FIELD_SIZE, 0.0f));
    // noise_buf stays zero (amplitude=0), present to count element overhead
    std::vector<std::vector<float>> noise_buf(N, std::vector<float>(FIELD_SIZE, 0.0f));

    for (int i = 0; i < N; ++i) {
        int pos = static_cast<int>((2 * i + 1) * FIELD_SIZE / (2 * N));
        stimuli[i] = make_gauss_stimulus(pos, S_SIGMA, S_AMP);
    }

    // One full Euler step for all N fields
    auto step_all = [&]() {
        for (int i = 0; i < N; ++i) {
            convolve(fields[i], kernel, conv_buf[i]);
            for (int x = 0; x < FIELD_SIZE; ++x) {
                fields[i][x] += (DT / TAU) * (
                    -fields[i][x] + H
                    + conv_buf[i][x]
                    + stimuli[i][x]
                    + noise_buf[i][x]);  // noise = 0
            }
        }
    };

    // Warm-up
    for (int t = 0; t < WARMUP_STEPS; ++t) step_all();

    // Timed runs
    FILE* fp = std::fopen(outfile.c_str(), "a");
    if (!fp) { std::fprintf(stderr, "Cannot open %s\n", outfile.c_str()); return; }

    for (int run = 0; run < N_RUNS; ++run) {
        // Reset fields to resting level
        for (auto& f : fields) std::fill(f.begin(), f.end(), H);

        auto t0 = std::chrono::high_resolution_clock::now();
        for (int t = 0; t < TIMED_STEPS; ++t) step_all();
        auto t1 = std::chrono::high_resolution_clock::now();

        double elapsed = std::chrono::duration<double>(t1 - t0).count();
        double sps     = TIMED_STEPS / elapsed;
        std::fprintf(fp,  "cedar,headless,%d,%d,%.2f\n", N, run + 1, sps);
        std::printf("cedar headless  N=%3d  run=%d  %.1f steps/s\n", N, run + 1, sps);
    }
    std::fclose(fp);
}

int main(int argc, char* argv[])
{
    std::string outfile = (argc > 1) ? argv[1] : "timings-cedar.csv";
    std::printf("Cedar headless benchmark → %s\n", outfile.c_str());
    for (int N : {10, 50, 100, 500, 1000})
        run_benchmark(N, outfile);
    return 0;
}
