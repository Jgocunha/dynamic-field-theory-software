%% Simulation sim_019 — type: detection
% Auto-generated. Do not edit manually.

fieldSize = 100;
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus1D('stimulus', fieldSize, 4, 15.0, 50, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus'});

sim.addElement(NeuralField('field u', fieldSize, 25, -8.0, 100), 'stimulus sum');

sim.addElement(GaussKernel1D('u -> u', fieldSize, 4, 7.0, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/dev-files/dynamic-field-theory-software/cross-platform-validation/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_019_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_019_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus', {'amplitude'}, {15.0});
sim.init();
