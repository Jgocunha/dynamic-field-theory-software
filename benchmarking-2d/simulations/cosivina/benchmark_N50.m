% benchmark_N50.m (2D) — Cosivina benchmark setup, N=50 fields (50x50)
% Called by cosivina_benchmark_2d.m via run(). Creates 'sim' in caller workspace.
% Do NOT add stepping code here — runner controls all stepping.

fieldSize = [50, 50];
N = 50;
sim = Simulator();
sim.deltaT = 25;

% stimulus centers tiled across the 50x50 grid (x,y per row)
centers = [3.1250, 3.5714; 9.3750, 3.5714; 15.6250, 3.5714; 21.8750, 3.5714; 28.1250, 3.5714; 34.3750, 3.5714; 40.6250, 3.5714; 46.8750, 3.5714; 3.1250, 10.7143; 9.3750, 10.7143; 15.6250, 10.7143; 21.8750, 10.7143; 28.1250, 10.7143; 34.3750, 10.7143; 40.6250, 10.7143; 46.8750, 10.7143; 3.1250, 17.8571; 9.3750, 17.8571; 15.6250, 17.8571; 21.8750, 17.8571; 28.1250, 17.8571; 34.3750, 17.8571; 40.6250, 17.8571; 46.8750, 17.8571; 3.1250, 25.0000; 9.3750, 25.0000; 15.6250, 25.0000; 21.8750, 25.0000; 28.1250, 25.0000; 34.3750, 25.0000; 40.6250, 25.0000; 46.8750, 25.0000; 3.1250, 32.1429; 9.3750, 32.1429; 15.6250, 32.1429; 21.8750, 32.1429; 28.1250, 32.1429; 34.3750, 32.1429; 40.6250, 32.1429; 46.8750, 32.1429; 3.1250, 39.2857; 9.3750, 39.2857; 15.6250, 39.2857; 21.8750, 39.2857; 28.1250, 39.2857; 34.3750, 39.2857; 40.6250, 39.2857; 46.8750, 39.2857; 3.1250, 46.4286; 9.3750, 46.4286];

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
