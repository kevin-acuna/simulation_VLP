%% generate_trajectories.m — Realistic indoor trajectories for broadcast OWP
%
% Three use cases at different heights (demonstrates 3D broadcast capability):
%
%   U1: Robot vacuum cleaner (z ~ 0.10 m)
%       Boustrophedon zigzag — systematic floor coverage, minimal z noise
%
%   U2: Pedestrian with smartphone in hand (z ~ 0.80 m)
%       Random waypoints + spline, human gait sway + vertical bob
%
%   U3: Warehouse AGV / logistics cart (z ~ 0.50 m)
%       Aisle-following U-turns, slight wheel drift, stable height
%
% Output: trajectories.mat
% Author: Kevin Acuna-Condori — 27 May 2026

clear; clc; close all;
rng(2026);

N_users = 3;  N_steps = 100;
L = 3;  W = 3;  margin = 0.10;
t_fine = linspace(0, 1, N_steps)';

traj_true = cell(N_users,1);
traj_info = cell(N_users,1);
colors = [0.20 0.50 0.80; 0.85 0.35 0.10; 0.15 0.60 0.35];

%% ===== U1: Robot Vacuum — Boustrophedon at z ~ 0.10 m =====
n_lanes = 6;
lane_sp = (W - 2*margin) / (n_lanes - 1);
wp = [];
for il = 1:n_lanes
    yl = -W/2 + margin + (il-1)*lane_sp;
    if mod(il,2)==1, wp=[wp; -L/2+margin, yl; L/2-margin, yl];
    else,            wp=[wp;  L/2-margin, yl;-L/2+margin, yl]; end
end
t_wp = [0; cumsum(sqrt(sum(diff(wp).^2,2)))];
t_wp = t_wp/t_wp(end);
x1 = interp1(t_wp, wp(:,1), t_fine, 'pchip') + 0.005*randn(N_steps,1);
y1 = interp1(t_wp, wp(:,2), t_fine, 'pchip') + 0.005*randn(N_steps,1);
z1 = 0.10 + 0.002*randn(N_steps,1);
x1=max(min(x1,L/2-0.05),-L/2+0.05); y1=max(min(y1,W/2-0.05),-W/2+0.05); z1=max(z1,0.02);

traj_true{1} = [x1, y1, z1];
traj_info{1} = struct('z_mean',0.10, 'label','U1: Robot vacuum ($z{\approx}0.10$ m)', 'type','vacuum');

%% ===== U2: Pedestrian with Smartphone — Random walk at z ~ 0.80 m =====
Nwp = 10;  gait_f = 1.8;
wpx = -L/2+margin + (L-2*margin)*rand(Nwp,1);
wpy = -W/2+margin + (W-2*margin)*rand(Nwp,1);
twp = [0; cumsum(sqrt(diff(wpx).^2+diff(wpy).^2))]; twp=twp/twp(end);
x2 = interp1(twp,wpx,t_fine,'pchip');
y2 = interp1(twp,wpy,t_fine,'pchip');
dx=gradient(x2); dy=gradient(y2); ds=sqrt(dx.^2+dy.^2)+1e-10;
nx=-dy./ds; ny=dx./ds;
sway = 0.03*sin(2*pi*gait_f*t_fine) + 0.01*randn(N_steps,1);
x2 = x2 + sway.*nx;  y2 = y2 + sway.*ny;
z2 = 0.80 + 0.025*abs(sin(2*pi*gait_f*t_fine)) + 0.01*randn(N_steps,1);
x2=max(min(x2,L/2-0.05),-L/2+0.05); y2=max(min(y2,W/2-0.05),-W/2+0.05); z2=max(min(z2,1.2),0.3);

traj_true{2} = [x2, y2, z2];
traj_info{2} = struct('z_mean',0.80, 'label','U2: Pedestrian, smartphone ($z{\approx}0.80$ m)', 'type','pedestrian');

%% ===== U3: Warehouse AGV — Aisle pattern at z ~ 0.50 m =====
wp3 = [-1.0,-1.2; -1.0,1.0; -0.3,1.0; -0.3,-1.0; 0.4,-1.0; 0.4,1.0; 1.1,1.0; 1.1,-0.5];
twp3 = [0; cumsum(sqrt(sum(diff(wp3).^2,2)))]; twp3=twp3/twp3(end);
x3 = interp1(twp3,wp3(:,1),t_fine,'pchip') + 0.008*randn(N_steps,1);
y3 = interp1(twp3,wp3(:,2),t_fine,'pchip') + 0.008*randn(N_steps,1);
z3 = 0.50 + 0.003*randn(N_steps,1);
x3=max(min(x3,L/2-0.05),-L/2+0.05); y3=max(min(y3,W/2-0.05),-W/2+0.05); z3=max(z3,0.2);

traj_true{3} = [x3, y3, z3];
traj_info{3} = struct('z_mean',0.50, 'label','U3: Warehouse AGV ($z{\approx}0.50$ m)', 'type','agv');

%% ===== Visualization =====
figure('Position', [100,100,900,650], 'Color', 'w');
hold on;

for iu = 1:N_users
    tr = traj_true{iu}; col = colors(iu,:);
    plot3(tr(:,1), tr(:,2), tr(:,3), '-', 'LineWidth', 1.8, 'Color', col);
    plot3(tr(:,1), tr(:,2), tr(:,3), '.', 'MarkerSize', 6, 'Color', col, ...
        'HandleVisibility','off');
    plot3(tr(1,1),tr(1,2),tr(1,3), 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor','k', 'HandleVisibility','off');
    plot3(tr(end,1),tr(end,2),tr(end,3), 's', 'MarkerSize', 9, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor','k', 'HandleVisibility','off');
end

% Room floor + ceiling wireframe
for zz = [0, 2]
    plot3([-L/2 L/2 L/2 -L/2 -L/2], [-W/2 -W/2 W/2 W/2 -W/2], ...
        zz*ones(1,5), '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.4, 'HandleVisibility','off');
end
for cx = [-L/2 L/2], for cy = [-W/2 W/2]
    plot3([cx cx],[cy cy],[0 2],'-','Color',[0.85 0.85 0.85],'LineWidth',0.3,'HandleVisibility','off');
end, end

plot3(0,0,2,'p','MarkerSize',16,'MarkerFaceColor',[1 0.8 0],'MarkerEdgeColor',[0.7 0.5 0],'LineWidth',1);

xlabel('$x$ [m]','Interpreter','latex','FontSize',11);
ylabel('$y$ [m]','Interpreter','latex','FontSize',11);
zlabel('$z$ [m]','Interpreter','latex','FontSize',11);
title('Indoor Trajectories: 3 Simultaneous Use Cases','Interpreter','latex','FontSize',12);
legend(cellfun(@(c) c.label, traj_info, 'UniformOutput',false), ...
    'Interpreter','latex','FontSize',9,'Location','northeastoutside');
view(35,25); grid on; axis equal;
xlim([-L/2 L/2]); ylim([-W/2 W/2]); zlim([0 2.1]);
set(gca,'FontSize',9);

%% ===== Save =====
save(fullfile(pwd,'trajectories.mat'), 'traj_true','traj_info','N_users','N_steps','colors');
fprintf('Saved %d trajectories (%d steps) to trajectories.mat\n', N_users, N_steps);

fprintf('\n%-6s %8s %8s %8s  %s\n', 'User', 'Len[m]', 'z_m[m]', 'z_s[cm]', 'Type');
for iu = 1:N_users
    tr=traj_true{iu}; pl=sum(sqrt(sum(diff(tr).^2,2)));
    fprintf('U%-5d %8.2f %8.2f %8.2f  %s\n', iu, pl, mean(tr(:,3)), std(tr(:,3))*100, traj_info{iu}.type);
end
