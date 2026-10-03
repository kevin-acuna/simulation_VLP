function m = gob_model(c)
if nargin<1
    c = gob_config();
end
assert(ismember(c.tiles,[1,9]) && ~isempty(c.radii),'gob:Geometry','Use one or nine tiles and at least one state.');
positive = [c.wavelength,c.waist,c.pitch,c.array_lens_distance,c.diameter,c.edge_thickness,c.pd_area,c.power];
assert(all(isfinite(positive) & positive>0) && c.index>1,'gob:Geometry','Invalid optical dimensions or index.');
assert(c.fov_deg>0 && c.fov_deg<=90 && c.transmission>0 && c.transmission<=1,'gob:Geometry','Invalid FOV or transmission.');
[x,y] = meshgrid((-2:2)*c.pitch,(2:-1:-2)*c.pitch);
x = reshape(x.',1,[]); y = reshape(y.',1,[]); rho2 = x.^2+y.^2;
aperture = c.diameter/2;
assert(max(rho2)<aperture^2 && aperture<.015,'gob:Geometry','Aperture or reference mounting geometry is invalid.');
K = numel(c.radii); M = 25*c.tiles*K;
m = struct('config',c,'local_xy',[x;y],'n_channels',M);
m.origins = zeros(3,M); m.directions = zeros(3,M); m.q = complex(zeros(M,1));
m.local_directions = zeros(3,25,K); m.local_q = complex(zeros(25,K));
m.thicknesses = zeros(25,K); m.center_thicknesses = zeros(1,K);
m.clipping_bounds = zeros(25,K); m.state_ids = zeros(M,1); m.tile_ids = zeros(M,1);
zr = pi*c.waist^2/c.wavelength; qin = c.array_lens_distance+1i*zr;
dc = c.array_lens_distance+c.edge_thickness+.015-sqrt(.015^2-aperture^2);
alpha = deg2rad(c.tilt_deg)*[-1,-1,-1,0,0,0,1,1,1];
beta = deg2rad(c.tilt_deg)*[-1,0,1,1,0,-1,-1,0,1];
offsets = c.tile_spacing*[1,0,-1,1,0,-1,1,0,-1;1,1,1,0,0,0,-1,-1,-1];
tiles = 1:9;
if c.tiles==1
    tiles = 5;
end
channel = 0;
for k = 1:K
    R = c.radii(k); magnitude = abs(R); sgn = sign(R);
    assert(isfinite(R) && magnitude>aperture && R^2>c.index^2*max(rho2), ...
        'gob:Geometry','Invalid spherical cap or total internal reflection of a chief ray.');
    tc = c.edge_thickness+sgn*(magnitude-sqrt(R^2-aperture^2));
    tau = tc+sgn*(sqrt(R^2-rho2)-magnitude);
    assert(tc>0 && all(tau>0),'gob:Geometry','Non-positive lens thickness.');
    root = sqrt(R^2-rho2);
    factor = (sqrt(R^2-c.index^2*rho2)-c.index*root)/(magnitude*R);
    v = [factor.*x;factor.*y;c.index+factor*sgn.*root];
    B = tau/c.index; C = (1-c.index)/R; D = 1+B*C;
    qout = (qin+B)./(C*qin+D);
    wexit = sqrt(c.wavelength/pi*abs(qout).^2./imag(qout));
    clipping = exp(-2*(aperture-sqrt(rho2)).^2./wexit.^2);
    assert(max(clipping)<=.01,'gob:Geometry','Clipping exceeds the accepted bound.');
    m.local_directions(:,:,k) = v; m.local_q(:,k) = qout.';
    m.thicknesses(:,k) = tau.'; m.center_thicknesses(k) = tc;
    m.clipping_bounds(:,k) = clipping.';
    local_exit = [x;y;c.array_lens_distance+tau];
    for tile = tiles
        rotation = gob_rotation(alpha(tile),pi+beta(tile));
        array_origin = rotation*[0;0;dc]+[-offsets(1,tile);offsets(2,tile);c.array_height+dc];
        ids = channel+(1:25);
        m.origins(:,ids) = rotation*local_exit+array_origin;
        m.directions(:,ids) = rotation*v; m.q(ids) = qout.';
        m.state_ids(ids) = k; m.tile_ids(ids) = tile;
        channel = channel+25;
    end
end
end
