function [power_W,J,beam] = gob_power(m,positions_m,normal)
if nargin<3
    normal = [0;0;1];
end
assert(size(positions_m,1)==3 && all(isfinite(positions_m),'all'),'gob:Position','Positions must be finite 3 x N columns.');
assert(isequal(size(normal),[3,1]) && abs(norm(normal)-1)<1e-10,'gob:Normal','Supply a unit normal column.');
dx = positions_m(1,:)-m.origins(1,:)';
dy = positions_m(2,:)-m.origins(2,:)';
dz = positions_m(3,:)-m.origins(3,:)';
vx = m.directions(1,:)'; vy = m.directions(2,:)'; vz = m.directions(3,:)';
axial = dx.*vx+dy.*vy+dz.*vz;
tx = dx-axial.*vx; ty = dy-axial.*vy; tz = dz-axial.*vz;
rho2 = tx.^2+ty.^2+tz.^2;
a = axial+real(m.q); b = imag(m.q); c = m.config;
width2 = c.wavelength/pi*(a.^2+b.^2)./b;
cosine = -m.directions'*normal;
visible = cosine>=cosd(c.fov_deg) & axial>0;
coefficient = 2*c.power*c.transmission*c.pd_area/pi;
power_W = coefficient*max(cosine,0)./width2.*exp(-2*rho2./width2).*visible;
if nargout>1
    factor = 2*c.wavelength/pi*a./b;
    radial = 2*rho2./width2.^2-1./width2;
    M = m.n_channels; N = size(positions_m,2);
    J = zeros(M,3,N);
    J(:,1,:) = reshape(power_W.*(radial.*factor.*vx-4*tx./width2),M,1,N);
    J(:,2,:) = reshape(power_W.*(radial.*factor.*vy-4*ty./width2),M,1,N);
    J(:,3,:) = reshape(power_W.*(radial.*factor.*vz-4*tz./width2),M,1,N);
end
if nargout>2
    beam = struct('axial_m',axial,'radius_squared_m2',width2,'transverse_squared_m2',rho2, ...
        'incidence_cosine',cosine,'visible',visible);
end
end
