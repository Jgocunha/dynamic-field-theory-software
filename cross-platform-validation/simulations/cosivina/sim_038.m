%% Simulation sim_038 — type: selection
% Auto-generated. Do not edit manually.

fieldSize = 100;
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus1D('stimulus 1', fieldSize, 5, 10.0, 25, true, false));
sim.addElement(GaussStimulus1D('stimulus 2', fieldSize, 5, 10.5, 75, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus 1', 'stimulus 2'});

sim.addElement(NeuralField('field u', fieldSize, 25, -10.0, 100), 'stimulus sum');

sim.addElement(LateralInteractions1D('u -> u', fieldSize, 2, 5.0, 0, 0, -0.15, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/Users/gaspa/OneDrive - Universidade do Minho/phd-degree/journals/SoftwareX/cross-platform-validation/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_038_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus 1', {'amplitude'}, {0});
sim.setElementParameters('stimulus 2', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_038_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus 1', {'amplitude'}, {10.0});
sim.setElementParameters('stimulus 2', {'amplitude'}, {10.5});
sim.init();
