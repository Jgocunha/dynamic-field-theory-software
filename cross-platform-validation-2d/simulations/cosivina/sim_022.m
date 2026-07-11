%% Simulation sim_022 (2D) — type: selection
% Auto-generated. Do not edit manually.

fieldSize = [50, 50];
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus2D('stimulus 1', fieldSize, 5, 5, 10.0, 12.5, 12.5, true, true, false));
sim.addElement(GaussStimulus2D('stimulus 2', fieldSize, 5, 5, 11.0, 37.5, 37.5, true, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus 1', 'stimulus 2'});

sim.addElement(NeuralField('field u', fieldSize, 25, -10.0, 100), 'stimulus sum');

sim.addElement(LateralInteractions2D('u -> u', fieldSize, 3, 3, 20.0, 0, 0, 0, -0.15, true, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_022_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus 1', {'amplitude'}, {0});
sim.setElementParameters('stimulus 2', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_022_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus 1', {'amplitude'}, {10.0});
sim.setElementParameters('stimulus 2', {'amplitude'}, {11.0});
sim.init();
