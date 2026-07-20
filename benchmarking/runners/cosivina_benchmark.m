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
% Output rows: cosivina,default,<arch>,<field_size>,<mode>,<N>,<run>,<steps_per_second>
%
% To reproduce the architecture x N x field-size matrix, run as-is.
% Edit ARCH_LIST / ARCH_N / FIELD_SIZES below to change scope.

clc;

% Force single-threaded execution for a fair single-thread comparison.
maxNumCompThreads(1);
fprintf('maxNumCompThreads = %d\n', maxNumCompThreads);

SCRIPT_DIR  = fileparts(mfilename('fullpath'));
DATA_DIR    = fullfile(SCRIPT_DIR, '..', 'data');
OUTPUT_FILE = fullfile(DATA_DIR, 'timings-cosivina.csv');

WARMUP_STEPS = 200;
TIMED_STEPS  = 2000;
N_RUNS       = 5;
NOISE_AMP    = 0.1;    % benchmark uses A>0 so the RNG cost is measured
BASE_SIZE    = 100;    % reference grid the arch positions are defined on

% Architecture x N x field-size matrix: all 4 canonical archs, across N and field size.
% Full fresh re-run of the entire 1D Cosivina suite in one idle sitting (memory uses the
% two-phase protocol below). Empty timings-cosivina.csv before running so the fresh data
% cleanly replaces everything. Run on a freshly-idle machine to avoid the thermal
% turbo/throttle within-cell noise that affected the earlier piecemeal run.
ARCH_LIST    = {'detection', 'selection', 'memory', 'multi-peak'};
ARCH_N       = [5, 10, 50, 100];
FIELD_SIZES  = [100, 500];

if ~exist(DATA_DIR, 'dir')
    mkdir(DATA_DIR);
end

fid = fopen(OUTPUT_FILE, 'a');
if fid == -1
    error('Cannot open %s for writing', OUTPUT_FILE);
end

for ai = 1:length(ARCH_LIST)
    for fi = 1:length(FIELD_SIZES)
        run_arch(fid, ARCH_LIST{ai}, ARCH_N, FIELD_SIZES(fi), BASE_SIZE, ...
                 NOISE_AMP, WARMUP_STEPS, TIMED_STEPS, N_RUNS);
    end
end

fclose(fid);
fprintf('\nDone. Results appended to %s\n', OUTPUT_FILE);


% ===========================================================================
% Helpers
% ===========================================================================

function run_arch(fid, archName, N_VALUES, fieldSize, baseSize, noiseAmp, WARMUP_STEPS, TIMED_STEPS, N_RUNS)
    isMemory = strcmp(archName, 'memory');
    for ni = 1:length(N_VALUES)
        N = N_VALUES(ni);
        fprintf('=== Cosivina  %s  fs=%d  N=%d ===\n', archName, fieldSize, N);

        [sim, stimHandles] = build_sim(N, archName, fieldSize, baseSize, noiseAmp);
        sim.init();
        for t = 1:WARMUP_STEPS; sim.step(); end

        for r = 1:N_RUNS
            sim.init();
            % Two-phase memory protocol: sim.init() recomputes each stimulus's
            % output from its (untouched) amplitude property, so the bump is
            % always freshly established here; run 100 steps with it on, then
            % zero output IN PLACE (zeroing .amplitude instead would not
            % propagate, since GaussStimulus.output is only recomputed on
            % init()) so the timed run measures self-sustained memory only.
            if isMemory
                for t = 1:100; sim.step(); end
                for s = 1:numel(stimHandles)
                    stimHandles{s}.output(:) = 0;
                end
            end
            t0 = tic;
            for t = 1:TIMED_STEPS; sim.step(); end
            elapsed = toc(t0);
            sps = TIMED_STEPS / elapsed;
            fprintf(fid, 'cosivina,default,%s,%d,headless,%d,%d,%.2f\n', archName, fieldSize, N, r, sps);
            fprintf('  headless  run=%d  %.1f steps/s\n', r, sps);
        end
    end
end

function [sim, stimHandles] = build_sim(N, archName, fieldSize, baseSize, noiseAmp)
    % Representative-sim parameters per architecture (validation sims
    % 001/021/041/081). See cross-platform-validation/generate_simulations.py.
    pos_scale = fieldSize / baseSize;
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
        case 'multi-peak'
            h = -8.0;  stimuli = [12.0 5 25; 12.0 5 75];
            kernel = {'gauss', 2, 5.0, 0.0};
        otherwise
            error('Unknown arch: %s', archName);
    end

    stimHandles = {};
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
            stimHandle = GaussStimulus1D(name_s, fieldSize, ...
                stimuli(s,2), stimuli(s,1), stimuli(s,3) * pos_scale, true, false);
            sim.addElement(stimHandle);
            stimHandles{end+1} = stimHandle; %#ok<AGROW>
        end

        sim.addElement(NormalNoise(name_n, fieldSize, noiseAmp));
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
