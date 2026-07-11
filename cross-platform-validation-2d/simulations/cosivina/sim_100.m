%% Simulation sim_100 (2D) — type: multi_peak
% Auto-generated. Do not edit manually.

fieldSize = [50, 50];
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus2D('stimulus 1', fieldSize, 3, 3, 12, 12.5, 12.5, true, true, false));
sim.addElement(GaussStimulus2D('stimulus 2', fieldSize, 3, 3, 12, 37.5, 37.5, true, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus 1', 'stimulus 2'});

sim.addElement(NeuralField('field u', fieldSize, 25, -8.0, 100), 'stimulus sum');

sim.addElement(GaussKernel2D('u -> u', fieldSize, 2, 2, 5.0, true, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_100_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus 1', {'amplitude'}, {0});
sim.setElementParameters('stimulus 2', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_100_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus 1', {'amplitude'}, {12});
sim.setElementParameters('stimulus 2', {'amplitude'}, {12});
sim.init();
