%% cosivina_benchmark.m
% Benchmarks Cosivina DFT simulations in headless and GUI (drawnow) modes.
% Appends results to data/timings.csv.
%
% Prerequisites:
%   - Cosivina on the MATLAB path
%   - Run from the benchmarking/ root directory
%
% Output rows: cosivina,<mode>,<N>,<run>,<steps_per_second>

clc;

SCRIPT_DIR  = fileparts(mfilename('fullpath'));
SIM_DIR     = fullfile(SCRIPT_DIR, '..', 'simulations', 'cosivina');
DATA_DIR    = fullfile(SCRIPT_DIR, '..', 'data');
OUTPUT_FILE = fullfile(DATA_DIR, 'timings-cosivina.csv');

WARMUP_STEPS = 200;
TIMED_STEPS  = 5000;
N_RUNS       = 3;
N_VALUES     = [10, 50, 100, 500, 1000];

if ~exist(DATA_DIR, 'dir')
    mkdir(DATA_DIR);
end

fid = fopen(OUTPUT_FILE, 'a');
if fid == -1
    error('Cannot open %s for writing', OUTPUT_FILE);
end

for ni = 1:length(N_VALUES)
    N = N_VALUES(ni);
    fprintf('=== Cosivina  N=%d ===\n', N);

    script_path = fullfile(SIM_DIR, sprintf('benchmark_N%d.m', N));
    if ~exist(script_path, 'file')
        warning('Script not found: %s — skipping N=%d', script_path, N);
        continue;
    end

    %% --- Headless timing ---
    run(script_path);   % creates 'sim' in this workspace
    sim.init();
    for t = 1:WARMUP_STEPS; sim.step(); end

    for r = 1:N_RUNS
        sim.init();
        t0 = tic;
        for t = 1:TIMED_STEPS; sim.step(); end
        elapsed = toc(t0);
        sps = TIMED_STEPS / elapsed;
        fprintf(fid, 'cosivina,headless,%d,%d,%.2f\n', N, r, sps);
        fprintf('  headless  run=%d  %.1f steps/s\n', r, sps);
    end
end

fclose(fid);
fprintf('\nDone. Results appended to %s\n', OUTPUT_FILE);
