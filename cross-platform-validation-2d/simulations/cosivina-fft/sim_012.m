%% Simulation sim_012 (2D) — type: detection (cosivina-fft: spectral KernelFFT convolution)
% Auto-generated. Do not edit manually.

fieldSize = [50, 50];
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus2D('stimulus', fieldSize, 5, 5, 12.0, 25.0, 25.0, true, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus'});

sim.addElement(NeuralField('field u', fieldSize, 25, -8.0, 100), 'stimulus sum');

sim.addElement(KernelFFT('u -> u', fieldSize, [2, 2], 8.0, [1, 1], 0, 0.0, [true, true], true), 'field u', 'output', 'field u');

outputDir = 'C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina-fft';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_012_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_012_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus', {'amplitude'}, {12.0});
sim.init();
