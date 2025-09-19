clc; clear; close all

%% Parámetros
z = 0.4;      % altura del receptor
H = 2;        % altura transmisor
h = H - z;    % diferencia vertical

tilt = 45;                % inclinación [deg]
azimuth = 45;            % azimut [deg]
n_r = [0,0,1]';           % normal receptor (mirando al techo)
n_t = [0,0,-1; ...
       sind(tilt)*cosd(azimuth), sind(tilt)*sind(azimuth), -cosd(tilt)]'; % 3x2

T = [0,0,H]';             % posición del Tx

%% Grilla 2D
dx = 0.02;
Rx = -2:dx:2;
Ry = -2:dx:2;
[XX,YY] = meshgrid(Rx,Ry);
NN = numel(XX);
R = [XX(:)'; YY(:)'; z*ones(1,NN)];  % puntos del receptor

%% Modelo fotométrico
m = 2;
Adet = 4.8e-3*5.5e-3;
Pt = 0.405;

d      = R - T;
d_norm = sqrt(sum(d.^2,1));
d_unit = d ./ d_norm;

cos_psi = n_r' * (-d_unit);     % 1xN (incidencia en el receptor)
cos_phi = n_t' * d_unit;        % 2xN (emisión para ambos modos)
phi     = acos(cos_phi);        % 2xN

K   = Pt*(m+1)*Adet/(2*pi);
Pri = K * (cos_phi.^m) .* (cos_psi ./ d_norm);  % 2xN
Pri = Pri .*(phi<deg2rad(90));    % anula donde el modo no ilumina

%% Beta (sin y con ruido)
beta = (Pri(2,:)./Pri(1,:)).^(1/m);
invalid = (Pri(1,:)<=0) | (Pri(2,:)<=0) | ~isfinite(beta);
beta(invalid) = NaN;

rng(40)
sigma2 = 3e-14; N = 1000;
n = sqrt(sigma2/N)*randn(size(Pri));
Pri_noise = Pri + n;
beta_noise = (Pri_noise(2,:)./Pri_noise(1,:)).^(1/m);
beta_noise( (Pri_noise(1,:)<=0) | (Pri_noise(2,:)<=0) | ~isfinite(beta_noise) ) = NaN;

BETA       = reshape(beta, size(XX));
BETA_NOISE = reshape(beta_noise, size(XX));

%% --- FIGURA 1: β en 3D (sin y con ruido) ---
figure(1); set(gcf,'Color','w')
tiledlayout(1,2,'Padding','compact','TileSpacing','compact')

% β sin ruido
nexttile
s1 = surf(XX,YY,BETA,'EdgeColor','none'); 
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('\beta')
title('\beta (sin ruido)')
axis tight; box on
shading interp; colormap parula
view(45,30); camlight headlight; lighting gouraud; material dull
cb1 = colorbar; cb1.Label.String = '\beta';

% β con ruido
nexttile
s2 = surf(XX,YY,BETA_NOISE,'EdgeColor','none');
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('\beta')
title('\beta (con ruido)')
axis tight; box on
shading interp; colormap parula
view(45,30); camlight headlight; lighting gouraud; material dull
cb2 = colorbar; cb2.Label.String = '\beta';

%% --- Preparación para FIGURA 2: Pri y Pri_noise ---
PR1   = reshape(Pri(1,:), size(XX));        % modo 1 (vertical)
PR2   = reshape(Pri(2,:), size(XX));        % modo 2 (inclinado, con huecos por FOV)
PR1n  = reshape(Pri_noise(1,:), size(XX));
PR2n  = reshape(Pri_noise(2,:), size(XX));

% Escala de color común para comparar todas las superficies
allVals = [PR1(:); PR2(:); PR1n(:); PR2n(:)];
allVals = allVals(isfinite(allVals) & (allVals>0));
cmin = min(allVals); 
cmax = max(allVals);

%% --- FIGURA 2: Pri y Pri_noise en 3D (estética) ---
figure(2); set(gcf,'Color','w')
tiledlayout(2,2,'Padding','compact','TileSpacing','compact')

% Pri - modo vertical
nexttile
surf(XX,YY,PR1,'EdgeColor','none');
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('P_{ri} [W]')
title('P_{ri} (modo vertical)')
axis tight; box on
shading interp; colormap parula; caxis([cmin cmax])
view(45,30); camlight headlight; lighting gouraud; material dull
cb = colorbar; cb.Label.String = 'P_{ri} [W]';

% Pri - modo inclinado
nexttile
surf(XX,YY,PR2,'EdgeColor','none');
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('P_{ri} [W]')
title('P_{ri} (modo inclinado)')
axis tight; box on
shading interp; colormap parula; caxis([cmin cmax])
view(45,30); camlight headlight; lighting gouraud; material dull
cb = colorbar; cb.Label.String = 'P_{ri} [W]';

% Pri_noise - modo vertical
nexttile
surf(XX,YY,PR1n,'EdgeColor','none');
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('P_{ri} [W]')
title('P_{ri} (modo vertical) con ruido')
axis tight; box on
shading interp; colormap parula; caxis([cmin cmax])
view(45,30); camlight headlight; lighting gouraud; material dull
cb = colorbar; cb.Label.String = 'P_{ri} [W]';

% Pri_noise - modo inclinado
nexttile
surf(XX,YY,PR2n,'EdgeColor','none');
xlabel('R_x [m]'); ylabel('R_y [m]'); zlabel('P_{ri} [W]')
title('P_{ri} (modo inclinado) con ruido')
axis tight; box on
shading interp; colormap parula; caxis([cmin cmax])
view(45,30); camlight headlight; lighting gouraud; material dull
cb = colorbar; cb.Label.String = 'P_{ri} [W]';

