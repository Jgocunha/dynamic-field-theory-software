%% cosivina_benchmark_2d.m
% Benchmarks Cosivina 2D DFT simulations in headless mode across the four canonical
% architectures (detection / selection / memory / multi-peak) and two grid sizes
% (25x25, 50x50), reusing the representative validation sim of each band with the 2D
% amplitude adjustments (positions on the 50-grid; selection kernel amp x4; memory
% exc/inh x2.5 + global -0.05). Appends results to data/timings-cosivina-2d.csv.
%
% Prerequisites:
%   - Cosivina on the MATLAB path
%   - Run from the benchmarking-2d/ root directory
%
% Output rows: cosivina,default,<arch>,<grid_side>,<mode>,<N>,<run>,<steps_per_second>

clc;

% Force single-threaded execution for a fair single-thread comparison.
maxNumCompThreads(1);
fprintf('maxNumCompThreads = %d\n', maxNumCompThreads);

SCRIPT_DIR  = fileparts(mfilename('fullpath'));
DATA_DIR    = fullfile(SCRIPT_DIR, '..', 'data');
OUTPUT_FILE = fullfile(DATA_DIR, 'timings-cosivina-2d.csv');

WARMUP_STEPS = 200;
TIMED_STEPS  = 2000;
N_RUNS       = 5;
NOISE_AMP    = 0.1;    % benchmark uses A>0 so the RNG cost is measured
BASE_GRID    = 50;     % reference grid side the arch positions are defined on

% Architecture x N x grid-size matrix: 4 canonical archs, across N and grid side.
ARCH_LIST    = {'detection', 'selection', 'memory', 'multi-peak'};
ARCH_N       = [5, 10, 50, 100];
GRID_SIZES   = [100, 200];

if ~exist(DATA_DIR, 'dir')
    mkdir(DATA_DIR);
end

fid = fopen(OUTPUT_FILE, 'a');
if fid == -1
    error('Cannot open %s for writing', OUTPUT_FILE);
end

for ai = 1:length(ARCH_LIST)
    for gi = 1:length(GRID_SIZES)
        run_arch(fid, ARCH_LIST{ai}, ARCH_N, GRID_SIZES(gi), BASE_GRID, ...
                 NOISE_AMP, WARMUP_STEPS, TIMED_STEPS, N_RUNS);
    end
end

fclose(fid);
fprintf('\nDone. Results appended to %s\n', OUTPUT_FILE);


% ===========================================================================
% Helpers
% ===========================================================================

function run_arch(fid, archName, N_VALUES, gridSide, baseGrid, noiseAmp, WARMUP_STEPS, TIMED_STEPS, N_RUNS)
    isMemory = strcmp(archName, 'memory');
    for ni = 1:length(N_VALUES)
        N = N_VALUES(ni);
        fprintf('=== Cosivina 2D  %s  grid=%dx%d  N=%d ===\n', archName, gridSide, gridSide, N);

        [sim, stimHandles] = build_sim(N, archName, gridSide, baseGrid, noiseAmp);
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
            fprintf(fid, 'cosivina,default,%s,%d,headless,%d,%d,%.2f\n', archName, gridSide, N, r, sps);
            fprintf('  headless  run=%d  %.1f steps/s\n', r, sps);
        end
    end
end

function [sim, stimHandles] = build_sim(N, archName, gridSide, baseGrid, noiseAmp)
    % Representative-sim parameters per architecture (validation sims
    % 001/021/041/081, 2D-adjusted). See generate_simulations_2d.py.
    fieldSize = [gridSide, gridSide];
    pos_scale = gridSide / baseGrid;
    sim = Simulator();
    sim.deltaT = 25;

    switch archName
        case 'detection'
            h = -8.0;  stimuli = [12.0 5 25];
            kernel = {'gauss', 3, 8.0, 0.0};
        case 'selection'
            h = -10.0; stimuli = [10.0 5 12.5; 10.5 5 37.5];
            kernel = {'gauss', 3, 20.0, -0.15};
        case 'memory'
            h = -5.0;  stimuli = [15.0 5 25];
            kernel = {'mexican_hat', 3.4, 44.25, 8.9, 33.75, -0.05};
        case 'multi-peak'
            h = -8.0;  stimuli = [12.0 5 12.5; 12.0 5 37.5];
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
            % GaussStimulus2D(name, size, sigmaY, sigmaX, amp, posY, posX, circY, circX, norm)
            stimHandle = GaussStimulus2D(name_s, fieldSize, ...
                stimuli(s,2), stimuli(s,2), stimuli(s,1), ...
                stimuli(s,3) * pos_scale, stimuli(s,3) * pos_scale, true, true, false);
            sim.addElement(stimHandle);
            stimHandles{end+1} = stimHandle; %#ok<AGROW>
        end

        sim.addElement(NormalNoise(name_n, fieldSize, noiseAmp));
        sim.addElement(SumInputs(name_sum, fieldSize), [stim_names, {name_n}]);
        sim.addElement(NeuralField(name_f, fieldSize, 25, h, 100), name_sum);

        switch kernel{1}
            case 'gauss'
                if kernel{4} == 0.0
                    % GaussKernel2D(name, size, sigmaY, sigmaX, amp, circY, circX, norm)
                    sim.addElement(GaussKernel2D(name_k, fieldSize, ...
                        kernel{2}, kernel{2}, kernel{3}, true, true, true), ...
                        name_f, 'output', name_f);
                else
                    % LateralInteractions2D(name, size, sExcY, sExcX, aExc, sInhY, sInhX, aInh, aGlobal, circY, circX, norm)
                    sim.addElement(LateralInteractions2D(name_k, fieldSize, ...
                        kernel{2}, kernel{2}, kernel{3}, 0, 0, 0, kernel{4}, ...
                        true, true, true), name_f, 'output', name_f);
                end
            case 'mexican_hat'
                sim.addElement(LateralInteractions2D(name_k, fieldSize, ...
                    kernel{2}, kernel{2}, kernel{3}, kernel{4}, kernel{4}, kernel{5}, kernel{6}, ...
                    true, true, true), name_f, 'output', name_f);
        end
    end
end
