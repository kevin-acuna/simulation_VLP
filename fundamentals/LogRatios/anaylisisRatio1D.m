clc;clear all;close all

z = 0.4; % altura del receptor
H = 2; % altura transmisor
h = H-z; % diferencia

N=1000; % samples

tilt = 45;
azimuth = 45;
n_r = [0,0,1]';
n_t = [0,0,-1;sind(tilt)*cosd(azimuth),sind(tilt)*sind(azimuth),-cosd(tilt)]';

T = [0,0,H]';
R_x = -2.5:0.05:2.5;
R_size = size(R_x');
R = [R_x', zeros(R_size),z*ones(R_size)]';

m=2;Adet=4.8e-3*5.5e-3;Pt=0.405;

d = R-T;
d_norm = sqrt(sum((R-T).^2));
d_unit = d./d_norm;

cos_psi = n_r'*(-d_unit);
psi = acos(cos_psi);
psi_degree = max(acosd(cos_psi))

cos_phi = n_t'*d_unit;
phi = acos(cos_phi);
phi_degree = max(max(acosd(cos_phi)))

Pri =Pt*(m+1)*Adet.*cos(phi).^m.*cos(psi)./(2*pi.*d_norm);
Pri = Pri.*(phi<deg2rad(90));

beta = (Pri(2,:)./Pri(1,:)).^(1/m);
log_beta = (1/m)*log(Pri(2,:)./Pri(1,:));

rng(40)
sigma2 = 3e-14;
n = sqrt(sigma2/N)*randn(size(Pri));

Pri_noise = Pri + n;
beta_noise = (Pri_noise(2,:)./Pri_noise(1,:)).^(1/m);
log_beta_noise = (1/m)*log(Pri_noise(2,:)./Pri_noise(1,:));


figure(1)
hold on
plot(R_x,Pri(1,:)),plot(R_x,Pri(2,:))
plot(R_x,Pri_noise(1,:)),plot(R_x,Pri_noise(2,:))

hold off
legend('nt_x=0°','nt_x=30°','nt_x=0°-noise','nt_x=30°-noise','Location','southeast')
grid minor


figure(2)
hold on
plot(R_x,beta),plot(R_x,log_beta)
plot(R_x,beta_noise),plot(R_x,log_beta_noise)
legend('beta','log-beta','beta-noise','log-beta-noise','Location','southeast')
grid minor