%% Simulation sim_080 (2D) — type: insufficient
% Auto-generated. Do not edit manually.

fieldSize = [50, 50];
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus2D('stimulus', fieldSize, 6, 6, 7.0, 25.0, 25.0, true, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus'});

sim.addElement(NeuralField('field u', fieldSize, 25, -13.0, 100), 'stimulus sum');

sim.addElement(GaussKernel2D('u -> u', fieldSize, 3, 3, 3.5, true, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_080_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_080_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus', {'amplitude'}, {7.0});
sim.init();
