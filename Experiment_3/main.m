clear, clc

n_t_s = [0,50,5,120,5,240, 5,0];
cdf90_val = POM_WLS_RMSE(n_t_s);
fprintf('CDF 90%% RMS Error: %.4f m\n', cdf90_val);