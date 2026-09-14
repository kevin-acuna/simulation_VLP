function [row,example] = gob_trace_beam(c,channel,count,seed)
if nargin<3, count = 200000; end
if nargin<4, seed = 193; end
m = gob_model(c); R = c.radii(1); stream = RandStream('mt19937ar','Seed',seed);
random = randn(stream,4,floor(count/2)); random = [random,-random]; count = size(random,2);
waist_xy = m.local_xy(:,channel)+c.waist/2*random(1:2,:);
slopes = c.wavelength/(2*pi*c.waist)*random(3:4,:);
incoming = [slopes;ones(1,count)]; incoming = incoming./vecnorm(incoming);
entry = [waist_xy+c.array_lens_distance*slopes;repmat(c.array_lens_distance,1,count)];
[inside,valid] = gob_snell(incoming,repmat([0;0;1],1,count),1/c.index);
valid = valid & sum(entry(1:2,:).^2,1)<=(c.diameter/2)^2;
center = [0;0;c.array_lens_distance+m.center_thicknesses(1)-R];
shifted = entry-center; b = sum(shifted.*inside,1);
discriminant = b.^2-sum(shifted.^2,1)+R^2;
valid = valid & discriminant>=0;
distance = -b+sign(R)*sqrt(max(discriminant,0));
exit_points = entry+inside.*distance;
valid = valid & distance>0 & sum(exit_points(1:2,:).^2,1)<=(c.diameter/2)^2;
normal = (exit_points-center)/R;
[output,refracted] = gob_snell(inside,normal,c.index);
tir_fraction = mean(valid & ~refracted); valid = valid & refracted & output(3,:)>0;
target_distance = (3-exit_points(3,:))./max(output(3,:),1e-12);
intercepts = exit_points(:,valid)+output(:,valid).*target_distance(valid);
xy = intercepts(1:2,:); centroid = mean(xy,2); covariance = cov(xy.');
widths = 2*sqrt(sort(eig(covariance))); v = m.local_directions(:,channel,1);
origin = [m.local_xy(:,channel);c.array_lens_distance+m.thicknesses(channel,1)];
s = (3-origin(3))/v(3); prediction = origin+s*v;
q = m.local_q(channel,1)+s; w2 = c.wavelength/pi*abs(q)^2/imag(q);
predicted_covariance = w2/4*(eye(2)+v(1:2)*v(1:2)'/v(3)^2);
predicted_widths = 2*sqrt(sort(eig(predicted_covariance)));
residual = xy-centroid; mahalanobis2 = sum(residual.*(covariance\residual),1);
row = struct('radius_mm',R*1000,'edge_thickness_mm',c.edge_thickness*1000, ...
    'channel_1based',channel,'rays',count,'transmitted_fraction',mean(valid),'tir_fraction',tir_fraction, ...
    'centroid_offset_mm',1000*norm(centroid-prediction(1:2)), ...
    'ray_width_minor_mm',1000*widths(1),'ray_width_major_mm',1000*widths(2), ...
    'abcd_width_minor_mm',1000*predicted_widths(1),'abcd_width_major_mm',1000*predicted_widths(2), ...
    'minor_width_ratio',widths(1)/predicted_widths(1),'major_width_ratio',widths(2)/predicted_widths(2), ...
    'gaussian_fourth_moment_ratio',mean(mahalanobis2.^2)/8);
example = struct('xy',xy(:,1:min(4000,size(xy,2))),'centroid',centroid, ...
    'covariance',covariance,'predicted_centroid',prediction(1:2),'predicted_covariance',predicted_covariance);
end
