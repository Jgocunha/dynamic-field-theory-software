% benchmark_N10.m (2D) — Cosivina benchmark setup, N=10 fields (50x50)
% Called by cosivina_benchmark_2d.m via run(). Creates 'sim' in caller workspace.
% Do NOT add stepping code here — runner controls all stepping.

fieldSize = [50, 50];
N = 10;
sim = Simulator();
sim.deltaT = 25;

% stimulus centers tiled across the 50x50 grid (x,y per row)
centers = [6.2500, 8.3333; 18.7500, 8.3333; 31.2500, 8.3333; 43.7500, 8.3333; 6.2500, 25.0000; 18.7500, 25.0000; 31.2500, 25.0000; 43.7500, 25.0000; 6.2500, 41.6667; 18.7500, 41.6667];

for i = 1:N
    px = centers(i, 1);
    py = centers(i, 2);
    name_s   = ['stimulus_' num2str(i)];
    name_n   = ['noise_'    num2str(i)];
    name_sum = ['sum_'      num2str(i)];
    name_f   = ['field_'    num2str(i)];
    name_k   = ['kernel_'   num2str(i)];

    % GaussStimulus2D(label, size, sigmaY, sigmaX, amplitude, positionY, positionX, circularY, circularX, normalized)
    sim.addElement(GaussStimulus2D(name_s, fieldSize, 5, 5, 10.0, py, px, true, true, false));
    sim.addElement(NormalNoise(name_n, fieldSize, 0));
    sim.addElement(SumInputs(name_sum, fieldSize), {name_s, name_n});
    sim.addElement(NeuralField(name_f, fieldSize, 25, -5.0, 100), name_sum);
    % GaussKernel2D(label, size, sigmaY, sigmaX, amplitude, circularY, circularX, normalized)
    sim.addElement(GaussKernel2D(name_k, fieldSize, 3, 3, 5.0, true, true, true), ...
        name_f, 'output', name_f);
end
