function [position, info] = rx_estimate_gls(mean_W, normals, p, counts, options)
if nargin<4
    counts = [];
end
if nargin<5
    options = struct();
end
[position, info] = rx_estimate('GLS', mean_W, normals, p, counts, options);
end
