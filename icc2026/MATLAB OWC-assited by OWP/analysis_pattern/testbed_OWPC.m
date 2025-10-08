clc, close all, clear all

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

% Asumiendo un phi = [0, 20, 20].

t_OWP = [-0.40,-0.40, 2];
t_OWC = [0, 0, 2];

% testbed
z0 = 0.76;
x_max=0.75;x_min=-0.75;
y_max=0.75;y_min=-0.75;
Xr = [x_min, x_max, x_max, x_min, x_min];
Yr = [y_min, y_min, y_max, y_max, y_min];
Zr = z0*ones(1,5);

% sample points
step = 0.25;
Rx = x_min:step:x_max;
Ry = y_min:step:y_max;
[XX,YY] = meshgrid(Rx,Ry);
NN = numel(XX)
R = [XX(:)'; YY(:)'; z0*ones(1,NN)];  % puntos del receptor


figure(1)
hold on
plot3(t_OWP(1),t_OWP(2),t_OWP(3),'o','LineWidth',2, 'Color',  colorsMATLAB(2,:))
plot3(t_OWC(1),t_OWC(2),t_OWC(3),'o','LineWidth',2, 'Color',  colorsMATLAB(5,:))
plot3(R(1,:),R(2,:),R(3,:),'o','LineWidth',0.75, 'Color',  colorsMATLAB(1,:))
plot3(Xr, Yr, Zr, '-','LineWidth',1,'Color','k')
axis([-2 2 -2 2 0 2]);
grid minor;
