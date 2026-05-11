%% cosivina_runner.m
% Runs all 100 Cosivina simulation scripts in simulations/cosivina/
% and saves activation profiles to data/cosivina/.
%
% Each sim_NNN.m script already embeds the full two-phase protocol:
%   Phase 1: 500 steps (stimulus ON)  → data/cosivina/sim_NNN_sigmoid_b100_with_stimulus.csv
%   Phase 2: 500 steps (stimulus OFF) → data/cosivina/sim_NNN_sigmoid_b100_without_stimulus.csv
%
% Usage: run this script from MATLAB with cosivina on the path.
%   addpath('C:/dev-files/cosivina');   % or wherever cosivina is installed
%   cd('path/to/cross-platform-validation');
%   run('runners/cosivina_runner.m');

%% Setup
scriptDir = fileparts(mfilename('fullpath'));
rootDir   = fullfile(scriptDir, '..');    % cross-platform-validation/
simDir    = fullfile(rootDir, 'simulations', 'cosivina');
outDir    = fullfile(rootDir, 'data', 'cosivina');

% Ensure cosivina is on path
cosivinaPath = 'C:/dev-files/cosivina';
if exist(cosivinaPath, 'dir') && ~contains(path, cosivinaPath)
    addpath(genpath(cosivinaPath));
    fprintf('Added cosivina to path: %s\n', cosivinaPath);
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Collect scripts
scripts = dir(fullfile(simDir, 'sim_*.m'));
scripts = sort({scripts.name});
nSims   = numel(scripts);
fprintf('Found %d simulation scripts.\n', nSims);

%% Run each script
nOK     = 0;
nFailed = 0;

for i = 1:nSims
    scriptName = scripts{i};
    scriptPath = fullfile(simDir, scriptName);
    simID      = regexp(scriptName, 'sim_(\d+)', 'tokens', 'once');
    simID      = simID{1};

    fprintf('[%3d/%d] Running %s ... ', i, nSims, scriptName);

    try
        run(scriptPath);
        nOK = nOK + 1;
        fprintf('OK\n');
    catch ME
        nFailed = nFailed + 1;
        fprintf('FAILED: %s\n', ME.message);
    end
end

fprintf('\nDone: %d OK, %d failed.\n', nOK, nFailed);
fprintf('Output: %s\n', outDir);
