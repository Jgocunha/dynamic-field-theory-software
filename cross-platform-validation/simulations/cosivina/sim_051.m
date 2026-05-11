%% Simulation sim_051 — type: memory
% Auto-generated. Do not edit manually.

fieldSize = 100;
sim = Simulator();
sim.deltaT = 25;

sim.addElement(GaussStimulus1D('stimulus', fieldSize, 5, 15.0, 50, true, false));
sim.addElement(SumInputs('stimulus sum', fieldSize), {'stimulus'});

sim.addElement(NeuralField('field u', fieldSize, 25, -5.0, 100), 'stimulus sum');

sim.addElement(LateralInteractions1D('u -> u', fieldSize, 3.4, 20.0, 8.9, 13.5, 0.0, true, true), 'field u', 'output', 'field u');

outputDir = 'C:/Users/gaspa/OneDrive - Universidade do Minho/phd-degree/journals/SoftwareX/cross-platform-validation/data/cosivina';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_051_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
sim.setElementParameters('stimulus', {'amplitude'}, {0});
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_051_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
sim.setElementParameters('stimulus', {'amplitude'}, {15.0});
sim.init();
