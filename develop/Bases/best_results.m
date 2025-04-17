%Resultados

% PopulationSize = 100; MaxGenerations=100; CrossoverFraction=0.6
% N0 = 10^(-21.8); % Nivel de ruido, SNR=15dB
bO_15dB = [8.2262  146.0060    5.3857  177.4186    3.1030   82.8723];
RMS_orientation(bO_15dB)

% PopulationSize = 100; MaxGenerations=100; CrossoverFraction=0.6
% N0 = 10^(-21.8); % Nivel de ruido, SNR=15dB
bO_15dB = [1.8927  306.1582    5.8992  208.0751    7.4300  122.4785];
RMS_orientation(bO_15dB)
%%

% PopulationSize = 50; MaxGenerations=50; CrossoverFraction=0.6
% N0 = 10^(-22.8); % Nivel de ruido, SNR=25dB
bO_25dB = [6.8  282.9    5.8  48.7   7.3   184.6];
RMS_orientation(bO_25dB)


%%

bO_15dB_complex = [9.6899  282.0432    0.2344   40.9939    5.3106  208.9957];
RMS_orientation(bO_15dB_complex)


%%
% PopulationSize = 50; MaxGenerations=50; CrossoverFraction=0.6
% N0 = 10^(-21); % Nivel de ruido, SNR=10dB
bO_10dB = [ 5.8013  216.7135    5.2021   39.4218    5.7168  342.7494];
RMS_orientation(bO_10dB)