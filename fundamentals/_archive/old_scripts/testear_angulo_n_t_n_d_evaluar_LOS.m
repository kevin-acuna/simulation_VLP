% Testea el angulo que forma el vector de orientacion del tranmisor n_t
% con la posicion más alejada del receptor a evaluar en el testbed.

clear all, close all, clc

theta_i=45;
rho_i=45;

n_t = zeros(1,3);
n_t(1,1) = sind(theta_i) * cosd(rho_i);  % x component
n_t(1,2) = sind(theta_i) * sind(rho_i);  % y component
n_t(1,3) = -cosd(theta_i);               % z component (negative because pointing down)

T = [0,0,3];
R = [-1.5,-1.5,1.2];

d = R-T;
n_d = d/norm(d);

cos_phi = n_t*n_d';
phi=acosd(cos_phi)