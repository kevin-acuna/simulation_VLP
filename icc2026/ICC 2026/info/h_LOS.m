function h = h_LOS(AP, UE, modeltype)

T = AP.pos;
R = UE.pos;
m = AP.m;

d_hat = (R-T)./norm(R-T);
d = norm(R-T);

cos_phi = dot(AP.n_t,d_hat);
phi = acosd(cos_phi);
        
cos_psi = dot(UE.n_r,-d_hat);
psi = acosd(cos_psi);

if (cos_phi > 0)
    if strcmp(modeltype,'datasheet')
%         R_phi =  irradiance(phi,'poly'); % Esto va de 0 a 1 !!!
        R_phi = (m+1)*irradiance(phi,'poly')/(2*pi);
    elseif strcmp(modeltype,'lambertian')
        R_phi = (m+1)*cos_phi^m/(2*pi); 
    else
        R_phi = (m+1)*cos_phi^m/(2*pi);
    end
else
    R_phi = 0;
end

% According to Barry,1997
if (psi <= UE.FOV_deg)
    A_eff = (UE.A_det)*(UE.Ts)*(UE.g_ri)*cos_psi;
else
    A_eff = 0;
end



h = (1/d^2)*R_phi*A_eff;

end