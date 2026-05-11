% benchmark_N10.m — Cosivina benchmark setup, N=10 neural fields
% Called by cosivina_benchmark.m via run(). Creates 'sim' in caller workspace.
% Do NOT add stepping code here — runner controls all stepping.

fieldSize = 100;
N = 10;
sim = Simulator();
sim.deltaT = 25;

for i = 1:N
    pos_i = floor((2*i - 1) * fieldSize / (2*N));
    name_s   = ['stimulus_' num2str(i)];
    name_n   = ['noise_'    num2str(i)];
    name_sum = ['sum_'      num2str(i)];
    name_f   = ['field_'    num2str(i)];
    name_k   = ['kernel_'   num2str(i)];

    sim.addElement(GaussStimulus1D(name_s, fieldSize, 5, 10.0, pos_i, true, false));
    sim.addElement(NormalNoise(name_n, fieldSize, 0));
    sim.addElement(SumInputs(name_sum, fieldSize), {name_s, name_n});
    sim.addElement(NeuralField(name_f, fieldSize, 25, -5.0, 100), name_sum);
    sim.addElement(GaussKernel1D(name_k, fieldSize, 3, 5.0, true, true), ...
        name_f, 'output', name_f);
end
