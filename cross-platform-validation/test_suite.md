# Cross-Framework Algebraic Equivalence — Test Suite

100 neural field simulations spanning five DFT architecture types.

## Fixed parameters (all simulations)

| Parameter | Value |
|---|---|
| Field size | 100 |
| tau | 25 ms |
| deltaT | 25 ms |
| Noise amplitude | 0 (algebraic equivalence) |
| circular | true |
| Kernel normalized | true |
| Cosivina / dnfc cutoffFactor | 5.0 |
| Cedar kernel limit | 10 |
| Steps phase 1 (stimulus ON) | 500 |
| Steps phase 2 (stimulus OFF) | 500 |

## Activation function variants

| Framework | Activation functions | Files per simulation |
|---|---|---|
| Cosivina | Logistic sigmoid β=100 | 1 `.m` |
| dnfc | AbsSigmoid β=100, Heaviside, Logistic sigmoid β=100 | 3 `.json` |
| Cedar | AbsSigmoid β=100, Heaviside | 2 `.json` |

## Output file naming

```
data/{framework}/sim_{NNN}_{act_fn}_{phase}.csv
```
Each CSV: single row, 100 comma-separated activation values.

- `act_fn` ∈ `{abssigmoid_b100, heaviside, sigmoid_b100}`
- `phase` ∈ `{with_stimulus, without_stimulus}`

---

## Architecture types

| Type | IDs | Architecture | Kernel | Distinguishing feature |
|---|---|---|---|---|
| Detection | 001–020 | 1 stimulus + NF + GaussKernel | Excitatory Gauss | Field transitions from sub- to suprathreshold |
| Selection | 021–040 | 2 stimuli + NF + GaussKernel + global inh | Excitatory + global | WTA: one stimulus suppresses the other |
| Memory | 041–060 | 1 stimulus + NF + MexicanHatKernel | Exc + Inh Gauss | Bump persists after stimulus removed |
| Insufficient | 061–080 | 1 stimulus + NF + GaussKernel | Excitatory (weak) | Field remains subthreshold |
| Multi-peak | 081–100 | 2–3 stimuli + NF + GaussKernel | Narrow excitatory, no global inh | Multiple bumps coexist |

---

## Detection (001–020)

Architecture: `GaussStimulus → NeuralField ← GaussKernel`

| ID | h | stim_amp | stim_sigma | stim_pos | k_amp | k_sigma |
|---|---|---|---|---|---|---|
| 001 | -8.0 | 12.0 | 5 | 50 | 8.0 | 3 |
| 002 | -8.0 | 10.0 | 5 | 50 | 8.0 | 3 |
| 003 | -8.0 | 14.0 | 5 | 50 | 8.0 | 3 |
| 004 | -9.0 | 12.0 | 5 | 50 | 8.0 | 3 |
| 005 | -7.0 | 12.0 | 5 | 50 | 8.0 | 3 |
| 006 | -8.0 | 12.0 | 3 | 50 | 8.0 | 3 |
| 007 | -8.0 | 12.0 | 7 | 50 | 8.0 | 3 |
| 008 | -8.0 | 12.0 | 5 | 25 | 8.0 | 3 |
| 009 | -8.0 | 12.0 | 5 | 75 | 8.0 | 3 |
| 010 | -8.0 | 12.0 | 5 | 50 | 6.0 | 3 |
| 011 | -8.0 | 12.0 | 5 | 50 | 10.0 | 3 |
| 012 | -8.0 | 12.0 | 5 | 50 | 8.0 | 2 |
| 013 | -8.0 | 12.0 | 5 | 50 | 8.0 | 4 |
| 014 | -8.0 | 12.0 | 5 | 50 | 8.0 | 5 |
| 015 | -9.0 | 14.0 | 5 | 50 | 8.0 | 3 |
| 016 | -7.0 | 10.0 | 5 | 50 | 8.0 | 3 |
| 017 | -8.0 | 12.0 | 5 | 33 | 8.0 | 3 |
| 018 | -8.0 | 12.0 | 5 | 67 | 8.0 | 3 |
| 019 | -8.0 | 15.0 | 4 | 50 | 7.0 | 4 |
| 020 | -10.0 | 16.0 | 6 | 50 | 9.0 | 3 |

---

## Selection (021–040)

Architecture: `2×GaussStimulus → NeuralField ← GaussKernel(amp_exc, amp_global)`

In Cosivina/dnfc: `LateralInteractions1D` / `GaussKernel` with `amplitudeGlobal`.
In Cedar: `GaussKernel` (excitatory) + `global inhibition` field parameter.

| ID | h | s1_amp | s1_pos | s2_amp | s2_pos | k_amp | k_sigma | amp_global |
|---|---|---|---|---|---|---|---|---|
| 021 | -10.0 | 10.0 | 25 | 10.5 | 75 | 5.0 | 3 | -0.15 |
| 022 | -10.0 | 10.0 | 25 | 11.0 | 75 | 5.0 | 3 | -0.15 |
| 023 | -10.0 | 12.0 | 25 | 12.5 | 75 | 5.0 | 3 | -0.15 |
| 024 | -10.0 | 10.0 | 30 | 10.5 | 70 | 5.0 | 3 | -0.15 |
| 025 | -10.0 | 10.0 | 20 | 10.5 | 80 | 5.0 | 3 | -0.15 |
| 026 | -11.0 | 11.0 | 25 | 11.5 | 75 | 5.0 | 3 | -0.15 |
| 027 | -9.0  | 10.0 | 25 | 10.5 | 75 | 5.0 | 3 | -0.15 |
| 028 | -10.0 | 10.0 | 25 | 10.5 | 75 | 6.0 | 3 | -0.15 |
| 029 | -10.0 | 10.0 | 25 | 10.5 | 75 | 5.0 | 4 | -0.15 |
| 030 | -10.0 | 10.0 | 25 | 10.5 | 75 | 5.0 | 3 | -0.20 |
| 031 | -10.0 | 10.0 | 25 | 10.5 | 75 | 5.0 | 3 | -0.10 |
| 032 | -10.0 |  8.0 | 25 |  8.5 | 75 | 5.0 | 3 | -0.15 |
| 033 | -10.0 | 14.0 | 25 | 14.5 | 75 | 5.0 | 3 | -0.15 |
| 034 | -10.0 | 10.0 | 25 | 10.5 | 50 | 5.0 | 3 | -0.15 |
| 035 | -10.0 | 10.0 | 33 | 10.5 | 67 | 5.0 | 3 | -0.15 |
| 036 | -10.0 | 10.0 | 25 | 10.5 | 75 | 4.0 | 3 | -0.15 |
| 037 | -12.0 | 13.0 | 25 | 13.5 | 75 | 5.0 | 3 | -0.15 |
| 038 | -10.0 | 10.0 | 25 | 10.5 | 75 | 5.0 | 2 | -0.15 |
| 039 | -10.0 | 10.0 | 25 | 10.5 | 75 | 7.0 | 4 | -0.20 |
| 040 | -10.0 | 10.0 | 25 | 12.0 | 75 | 5.0 | 3 | -0.15 |

---

## Memory (041–060)

Architecture: `GaussStimulus → NeuralField ← MexicanHatKernel`

In Cosivina: `LateralInteractions1D(sigma_exc, amp_exc, sigma_inh, amp_inh, 0)`.
In dnfc: `MexicanHatKernel(widthExc, amplitudeExc, widthInh, amplitudeInh)`.
In Cedar: Two `cedar.aux.kernel.Gauss` entries (duplicate key, Cedar-specific format).

| ID | h | stim_amp | stim_pos | sigma_exc | amp_exc | sigma_inh | amp_inh |
|---|---|---|---|---|---|---|---|
| 041 | -5.0 | 15.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 042 | -5.0 | 12.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 043 | -5.0 | 18.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 044 | -6.0 | 15.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 045 | -4.0 | 15.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 046 | -5.0 | 15.0 | 25 | 3.4 | 17.7 | 8.9 | 13.5 |
| 047 | -5.0 | 15.0 | 75 | 3.4 | 17.7 | 8.9 | 13.5 |
| 048 | -5.0 | 15.0 | 50 | 3.0 | 17.7 | 8.9 | 13.5 |
| 049 | -5.0 | 15.0 | 50 | 4.0 | 17.7 | 8.9 | 13.5 |
| 050 | -5.0 | 15.0 | 50 | 3.4 | 15.0 | 8.9 | 13.5 |
| 051 | -5.0 | 15.0 | 50 | 3.4 | 20.0 | 8.9 | 13.5 |
| 052 | -5.0 | 15.0 | 50 | 3.4 | 17.7 | 7.0 | 13.5 |
| 053 | -5.0 | 15.0 | 50 | 3.4 | 17.7 | 10.0 | 13.5 |
| 054 | -5.0 | 15.0 | 50 | 3.4 | 17.7 | 8.9 | 11.0 |
| 055 | -5.0 | 15.0 | 50 | 3.4 | 17.7 | 8.9 | 16.0 |
| 056 | -5.0 | 15.0 | 33 | 3.4 | 17.7 | 8.9 | 13.5 |
| 057 | -5.0 | 15.0 | 67 | 3.4 | 17.7 | 8.9 | 13.5 |
| 058 | -6.0 | 18.0 | 50 | 3.4 | 17.7 | 8.9 | 13.5 |
| 059 | -4.0 | 12.0 | 50 | 4.0 | 20.0 | 8.9 | 13.5 |
| 060 | -5.0 | 15.0 | 50 | 3.0 | 16.0 | 9.5 | 14.0 |

---

## Insufficient activation (061–080)

Architecture: `GaussStimulus → NeuralField ← GaussKernel` (stimulus too weak or h too negative)

| ID | h | stim_amp | stim_sigma | stim_pos | k_amp | k_sigma |
|---|---|---|---|---|---|---|
| 061 | -12.0 | 5.0 | 5 | 50 | 3.0 | 3 |
| 062 | -12.0 | 4.0 | 5 | 50 | 3.0 | 3 |
| 063 | -12.0 | 6.0 | 5 | 50 | 3.0 | 3 |
| 064 | -14.0 | 5.0 | 5 | 50 | 3.0 | 3 |
| 065 | -10.0 | 5.0 | 5 | 50 | 3.0 | 3 |
| 066 | -12.0 | 5.0 | 3 | 50 | 3.0 | 3 |
| 067 | -12.0 | 5.0 | 7 | 50 | 3.0 | 3 |
| 068 | -12.0 | 5.0 | 5 | 25 | 3.0 | 3 |
| 069 | -12.0 | 5.0 | 5 | 75 | 3.0 | 3 |
| 070 | -12.0 | 5.0 | 5 | 50 | 2.0 | 3 |
| 071 | -12.0 | 5.0 | 5 | 50 | 4.0 | 3 |
| 072 | -12.0 | 5.0 | 5 | 50 | 3.0 | 2 |
| 073 | -12.0 | 5.0 | 5 | 50 | 3.0 | 4 |
| 074 | -15.0 | 7.0 | 5 | 50 | 3.0 | 3 |
| 075 | -12.0 | 3.0 | 5 | 50 | 3.0 | 3 |
| 076 | -12.0 | 5.0 | 5 | 50 | 1.0 | 3 |
| 077 | -12.0 | 5.0 | 5 | 33 | 3.0 | 3 |
| 078 | -12.0 | 5.0 | 5 | 67 | 3.0 | 3 |
| 079 | -11.0 | 6.0 | 4 | 50 | 4.0 | 3 |
| 080 | -13.0 | 7.0 | 6 | 50 | 3.5 | 3 |

---

## Multi-peak (081–100)

Architecture: `2–3 × GaussStimulus → NeuralField ← GaussKernel` (narrow, no global inhibition)

| ID | n | h | stim_configs (amp, pos, sigma) | k_amp | k_sigma | amp_global |
|---|---|---|---|---|---|---|
| 081 | 2 | -8.0 | (12,25,5),(12,75,5) | 5.0 | 2 | 0.0 |
| 082 | 2 | -8.0 | (12,25,5),(12,75,5) | 4.0 | 2 | 0.0 |
| 083 | 2 | -8.0 | (12,25,5),(12,75,5) | 3.0 | 1 | 0.0 |
| 084 | 2 | -8.0 | (12,20,5),(12,80,5) | 5.0 | 2 | 0.0 |
| 085 | 2 | -8.0 | (12,30,5),(12,70,5) | 5.0 | 2 | 0.0 |
| 086 | 3 | -8.0 | (12,20,5),(12,50,5),(12,80,5) | 5.0 | 2 | 0.0 |
| 087 | 3 | -8.0 | (10,20,5),(12,50,5),(10,80,5) | 4.0 | 2 | 0.0 |
| 088 | 2 | -7.0 | (12,25,5),(12,75,5) | 5.0 | 2 | 0.0 |
| 089 | 2 | -9.0 | (14,25,5),(14,75,5) | 5.0 | 2 | 0.0 |
| 090 | 2 | -8.0 | (12,25,4),(12,75,4) | 5.0 | 2 | 0.0 |
| 091 | 2 | -8.0 | (12,25,6),(12,75,6) | 5.0 | 2 | 0.0 |
| 092 | 2 | -8.0 | (12,25,5),(12,75,5) | 6.0 | 2 | 0.0 |
| 093 | 2 | -8.0 | (12,25,5),(12,75,5) | 5.0 | 3 | 0.0 |
| 094 | 2 | -8.0 | (12,25,5),(14,75,5) | 5.0 | 2 | 0.0 |
| 095 | 3 | -8.0 | (12,17,4),(12,50,4),(12,83,4) | 4.0 | 2 | 0.0 |
| 096 | 2 | -8.0 | (12,25,5),(12,75,5) | 5.0 | 2 | -0.05 |
| 097 | 2 | -8.0 | (15,25,5),(15,75,5) | 5.0 | 2 | 0.0 |
| 098 | 3 | -8.0 | (10,25,5),(10,50,5),(10,75,5) | 4.0 | 2 | 0.0 |
| 099 | 2 | -8.0 | (12,25,5),(12,75,5) | 7.0 | 3 | 0.0 |
| 100 | 2 | -8.0 | (12,25,3),(12,75,3) | 5.0 | 2 | 0.0 |
