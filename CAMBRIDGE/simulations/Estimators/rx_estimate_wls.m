function [position, info] = rx_estimate_wls(mean_W, normals, p, counts, options)
if nargin<4
    counts = [];
end
if nargin<5
    options = struct();
end
[position, info] = rx_estimate('WLS', mean_W, normals, p, counts, options);
end
