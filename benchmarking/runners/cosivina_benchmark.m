%% cosivina_benchmark.m
% Benchmarks Cosivina DFT simulations in headless mode across the five
% architectures (detection / selection / memory / insufficient / multi-peak),
% reusing the representative validation sim of each band. Appends results to
% data/timings-cosivina.csv.
%
% Prerequisites:
%   - Cosivina on the MATLAB path
%   - Run from the benchmarking/ root directory
%
% Output rows: cosivina,<arch>,<mode>,<N>,<run>,<steps_per_second>
%
% To reproduce the architecture matrix and the detection scaling sweep, run as-is.
% Edit ARCH_LIST / the per-arch N values below to change scope.

clc;

% Force single-threaded execution for a fair single-thread comparison.
maxNumCompThreads(1);
fprintf('maxNumCompThreads = %d\n', maxNumCompThreads);

SCRIPT_DIR  = fileparts(mfilename('fullpath'));
DATA_DIR    = fullfile(SCRIPT_DIR, '..', 'data');
OUTPUT_FILE = fullfile(DATA_DIR, 'timings-cosivina.csv');

WARMUP_STEPS = 200;
TIMED_STEPS  = 5000;
N_RUNS       = 10;

% Architecture realism matrix: all 5 archs at reduced N.
ARCH_LIST    = {'detection', 'selection', 'memory', 'insufficient', 'multi-peak'};
ARCH_N       = [10, 50, 100];
% Scaling sweep: detection across the full N range (comparable to prior tables).
SCALING_ARCH = 'detection';
SCALING_N    = [10, 50, 100, 500, 1000];

if ~exist(DATA_DIR, 'dir')
    mkdir(DATA_DIR);
end

fid = fopen(OUTPUT_FILE, 'a');
if fid == -1
    error('Cannot open %s for writing', OUTPUT_FILE);
end

% --- Architecture realism matrix (5 archs x reduced N) ---
for ai = 1:length(ARCH_LIST)
    run_arch(fid, ARCH_LIST{ai}, ARCH_N, WARMUP_STEPS, TIMED_STEPS, N_RUNS);
end

% --- Detection scaling sweep (full N), the extra (500/1000) cells only ---
extra_N = setdiff(SCALING_N, ARCH_N);
if ~isempty(extra_N)
    run_arch(fid, SCALING_ARCH, extra_N, WARMUP_STEPS, TIMED_STEPS, N_RUNS);
end

fclose(fid);
fprintf('\nDone. Results appended to %s\n', OUTPUT_FILE);


% ===========================================================================
% Helpers
% ===========================================================================

function run_arch(fid, archName, N_VALUES, WARMUP_STEPS, TIMED_STEPS, N_RUNS)
    for ni = 1:length(N_VALUES)
        N = N_VALUES(ni);
        fprintf('=== Cosivina  %s  N=%d ===\n', archName, N);

        sim = build_sim(N, archName);
        sim.init();
        for t = 1:WARMUP_STEPS; sim.step(); end

        for r = 1:N_RUNS
            sim.init();
            t0 = tic;
            for t = 1:TIMED_STEPS; sim.step(); end
            elapsed = toc(t0);
            sps = TIMED_STEPS / elapsed;
            fprintf(fid, 'cosivina,%s,headless,%d,%d,%.2f\n', archName, N, r, sps);
            fprintf('  headless  run=%d  %.1f steps/s\n', r, sps);
        end
    end
end

function sim = build_sim(N, archName)
    % Representative-sim parameters per architecture (validation sims
    % 001/021/041/061/081). See cross-platform-validation/generate_simulations.py.
    fieldSize = 100;
    sim = Simulator();
    sim.deltaT = 25;

    switch archName
        case 'detection'
            h = -8.0;  stimuli = [12.0 5 50];
            kernel = {'gauss', 3, 8.0, 0.0};
        case 'selection'
            h = -10.0; stimuli = [10.0 5 25; 10.5 5 75];
            kernel = {'gauss', 3, 5.0, -0.15};
        case 'memory'
            h = -5.0;  stimuli = [15.0 5 50];
            kernel = {'mexican_hat', 3.4, 17.7, 8.9, 13.5};
        case 'insufficient'
            h = -12.0; stimuli = [5.0 5 50];
            kernel = {'gauss', 3, 3.0, 0.0};
        case 'multi-peak'
            h = -8.0;  stimuli = [12.0 5 25; 12.0 5 75];
            kernel = {'gauss', 2, 5.0, 0.0};
        otherwise
            error('Unknown arch: %s', archName);
    end

    for i = 1:N
        suffix = num2str(i);
        name_n   = ['noise_' suffix];
        name_sum = ['sum_'   suffix];
        name_f   = ['field_' suffix];
        name_k   = ['kernel_' suffix];

        stim_names = cell(1, size(stimuli, 1));
        for s = 1:size(stimuli, 1)
            name_s = ['stimulus_' suffix '_' num2str(s)];
            stim_names{s} = name_s;
            sim.addElement(GaussStimulus1D(name_s, fieldSize, ...
                stimuli(s,2), stimuli(s,1), stimuli(s,3), true, false));
        end

        sim.addElement(NormalNoise(name_n, fieldSize, 0));
        sim.addElement(SumInputs(name_sum, fieldSize), [stim_names, {name_n}]);
        sim.addElement(NeuralField(name_f, fieldSize, 25, h, 100), name_sum);

        switch kernel{1}
            case 'gauss'
                if kernel{4} == 0.0
                    sim.addElement(GaussKernel1D(name_k, fieldSize, ...
                        kernel{2}, kernel{3}, true, true), name_f, 'output', name_f);
                else
                    sim.addElement(LateralInteractions1D(name_k, fieldSize, ...
                        kernel{2}, kernel{3}, 0, 0, kernel{4}, true, true), ...
                        name_f, 'output', name_f);
                end
            case 'mexican_hat'
                sim.addElement(LateralInteractions1D(name_k, fieldSize, ...
                    kernel{2}, kernel{3}, kernel{4}, kernel{5}, 0.0, true, true), ...
                    name_f, 'output', name_f);
        end
    end
end
