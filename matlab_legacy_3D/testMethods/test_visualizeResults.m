clear all, close all, clc

import visualization.*

n_t_s = [30,0,30,120,30,240];

step = 0.2;

X_r = -1.2:step:1.2;
Y_r = -1.2:step:1.2;
Z_r = -1.2;

[x_real, y_real, z_real] = meshgrid(X_r, Y_r, Z_r);


visualizeResults3D(n_t_s, x_real, y_real, z_real, x_real+0.05, y_real+0.04, z_real+0.02);