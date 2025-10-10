function rmse = model(set)

% Intrasture
T = [0.4,0.4,0];
h = 2 - 0.75;

% Set of K-orientation (K=3)
% inclination, azimuth
Ndir = length(set)/2;

for i_dir = 1:Ndir
    incl = set(i_dir*2-1);
    azim = set(i_dir*2);
    n_t(i_dir,:)=[sind(incl)*cosd(azim), sind(incl)*sind(azim), -cosd(incl)];
end


% n_t(1,:)=[0,0,-1]
% n_t(2,:)=[-sind(incl),0,-cosd(incl)]
% n_t(3,:)=[0,-sind(incl),-cosd(incl)]


n_r = [0,0,1];

% create points to evaluate
x = -1:0.25:0;
y = -1:0.25:0;
[px,py] = meshgrid(x,y);
px = px(:); py=py(:);
pos = [px,py];
Npos = size(pos,1);

% Parameters
Pt = 0.405;
Rp = 0.6;
m = 1.52;
p = 4.8e-3; q = 5.5e-3; 
N_det = 1; 
A_det = p*q*N_det;

sigma2 = 30e6*10^(-21.0);

% Model
S=cell(Npos,Ndir);
for i_pos = 1:Npos
    for i_dir = 1:Ndir
        
        R = [pos(i_pos,:),-h];
        v_tr = (R-T)./norm(R-T);
        d = norm(R-T);
        cos_phi = dot(n_t(i_dir,:),v_tr);
        phi = acosd(cos_phi);
        cos_psi = dot(n_r,-v_tr);
        
        C = (m+1)*A_det/(2*pi); % constant
        %g_phi = cos_phi^m; % modelo de irradianza del LED
        g_phi = irradiance(phi,'poly');

        h_LOS = C*g_phi*cos_psi./d^2;
        w = sqrt(sigma2).*randn(1,1000);
        S{i_pos,i_dir} = Rp*Pt*h_LOS + w;
    end
end


pos_est = zeros(Npos,3);
for i_pos = 1:Npos
    
    V_n1 = mean(S{i_pos,1});  V_n1 = min(max(V_n1, 0.00000001), 100);
    V_n2 = mean(S{i_pos,2});  V_n2 = min(max(V_n2, 0.00000001), 100);
    V_n3 = mean(S{i_pos,3});  V_n3 = min(max(V_n3, 0.00000001), 100);

    try
        n_d = estimate_direction([V_n1,V_n2,V_n3], n_t, m, 'svd');
        escale = -h/n_d(3);
        pos_est(i_pos,:) = T + escale*n_d;
    catch
        % En el peor de los casos le coloco una posicion lejana
        n_d = [0,0,0];
        pos_est(i_pos,:)= [10,10,10];
    end

end

errors = sqrt(sum((pos - pos_est(:,1:2)).^2, 2))*100;
rmse = sqrt(mean(errors.^2));


end