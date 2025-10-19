% Construyo mi testbed de VLP
%run('definitions.m');        

AP_pos = vertcat(AP.pos);
AP_n   = vertcat(AP.n_t);        % Nx3
AP_ids = {AP.id};                % 1xN

UE_pos = UE.pos(:).';            % 1x3
UE_n   = UE.n_r(:).';            % 1x3

Nori = size(AP(1).set_n_t, 1);
Nap  = numel(AP);

figure('Color','w'); hold on; axis equal; grid on;
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
xlim(testbed.x); ylim(testbed.y); zlim(testbed.z);
view(45,25);

% Piso/techo (opcional)
patch('XData',testbed.x([1 2 2 1]), ...
      'YData',testbed.y([1 1 2 2]), ...
      'ZData',[UE.pos(3) UE.pos(3) UE.pos(3) UE.pos(3)], ...
      'FaceAlpha',0.05,'EdgeColor',[0.6 0.6 0.6]);
patch('XData',testbed.x([1 2 2 1]), ...
      'YData',testbed.y([1 1 2 2]), ...
      'ZData',[testbed.z(2) testbed.z(2) testbed.z(2) testbed.z(2)], ...
      'FaceAlpha',0.05,'EdgeColor',[0.6 0.6 0.6]);



L_arrow = 0.5;  % longitud visual de la flecha

for i_ap = 1:Nap
    
    plot3(AP(i_ap).pos(1), AP(i_ap).pos(2), AP(i_ap).pos(3), 's', ...
      'MarkerSize',10,'MarkerFaceColor',[0.2 0.5 1],'MarkerEdgeColor','k');

    for i_ori = 1:Nori
        n_t = angles2vec( AP(i_ap).set_n_t(i_ori,:) );
        quiver3(AP(i_ap).pos(1), AP(i_ap).pos(2), AP(i_ap).pos(3), ...
                L_arrow*n_t(:,1), L_arrow*n_t(:,2), L_arrow*n_t(:,3), ...
                0, 'LineWidth',1.5,'Color',[0.2 0.5 1]);
    end

    text(AP(i_ap).pos(1), AP(i_ap).pos(2), AP(i_ap).pos(3)+0.1, AP_ids{i_ap}, ...
    'HorizontalAlignment','center','VerticalAlignment','bottom', ...
    'FontWeight','bold');
end


% === (5) Plot de UE ===
plot3(UE_pos(1), UE_pos(2), UE_pos(3), 'o', ...
      'MarkerSize',9,'MarkerFaceColor',[1 0.4 0.1],'MarkerEdgeColor','k');
quiver3(UE_pos(1), UE_pos(2), UE_pos(3), ...
        0.4*UE_n(1), 0.4*UE_n(2), 0.4*UE_n(3), ...
        0, 'LineWidth',1.5,'Color',[1 0.4 0.1]);
text(UE_pos(1), UE_pos(2), UE_pos(3)+0.1, UE.id, ...
     'HorizontalAlignment','center','VerticalAlignment','bottom', ...
     'FontWeight','bold');

% === (6) (Opcional) Cono FOV del UE ===
drawFOVcone(UE_pos, UE_n, UE.FOV_deg, 0.6, [1 0.4 0.1]);  % L=0.6 m

%% ===== Helper: dibuja un cono de FOV dado origen, normal y ángulo =====
function h = drawFOVcone(origin, normal, FOV_deg, L, colorRGB)
    % normaliza
    n = normal(:)/norm(normal);
    % base ortonormal {u,v,n}
    tmp = [1;0;0];
    if abs(dot(n,tmp)) > 0.9, tmp = [0;1;0]; end
    u = tmp - (n'*tmp)*n; u = u/norm(u);
    v = cross(n,u);

    % geometría del cono
    th = linspace(0, 2*pi, 50);
    alpha = deg2rad(FOV_deg);
    r = L * tan(alpha);
    circle = origin(:) + n*L + u*r.*cos(th) + v*r.*sin(th);

    % malla de la superficie
    Nring = numel(th);
    X = [origin(1)*ones(1,Nring); circle(1,:)];
    Y = [origin(2)*ones(1,Nring); circle(2,:)];
    Z = [origin(3)*ones(1,Nring); circle(3,:)];

    hold on;
    h = surf([X; X(1,:)], [Y; Y(1,:)], [Z; Z(1,:)], ...
             'FaceAlpha',0.08,'EdgeAlpha',0.15, ...
             'FaceColor',colorRGB, 'EdgeColor',colorRGB);
    % aro de la base
    plot3(circle(1,:), circle(2,:), circle(3,:), '-', 'Color', colorRGB, 'LineWidth',1.2);
end