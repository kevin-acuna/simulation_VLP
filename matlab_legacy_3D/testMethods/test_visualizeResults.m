clear all, close all, clc

n_t_s = [30,0,30,120,30,240];

step = 0.1;

X_r = -1.2:step:1.2;
Y_r = -1.2:step:1.2;
Z_r = -1.2:step:1.2;

[x_real, y_real, z_real] = meshgrid(X_r, Y_r, Z_r);

scatter3(x_real(:), y_real(:), z_real(:), 'o', 'MarkerEdgeColor', 'k'); 

%visualizeResults3D(n_t_s, x_real, y_real, x_est, y_est);