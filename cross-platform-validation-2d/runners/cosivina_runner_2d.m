%% cosivina_runner_2d.m
% Runs all 100 Cosivina 2D simulation scripts in simulations/cosivina/
% and saves flattened (row-major) 50x50 activation profiles to data/cosivina/.
%
% Each sim_NNN.m script embeds the full two-phase protocol and exports
% reshape(u', 1, []) so the CSV is a single row of 2500 values matching the
% other frameworks' row-major flatten.
%
% Usage (from MATLAB, cosivina on path):
%   cd('path/to/cross-platform-validation-2d');
%   run('runners/cosivina_runner_2d.m');

scriptDir = fileparts(mfilename('fullpath'));
rootDir   = fullfile(scriptDir, '..');                 % cross-platform-validation-2d/
simDir    = fullfile(rootDir, 'simulations', 'cosivina');
outDir    = fullfile(rootDir, 'data', 'cosivina');

cosivinaPath = 'C:/dev-files/cosivina';
if exist(cosivinaPath, 'dir') && ~contains(path, cosivinaPath)
    addpath(genpath(cosivinaPath));
    fprintf('Added cosivina to path: %s\n', cosivinaPath);
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

scripts = dir(fullfile(simDir, 'sim_*.m'));
scripts = sort({scripts.name});
nSims   = numel(scripts);
fprintf('Found %d 2D simulation scripts.\n', nSims);

nOK = 0; nFailed = 0;
for i = 1:nSims
    scriptName = scripts{i};
    scriptPath = fullfile(simDir, scriptName);
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
