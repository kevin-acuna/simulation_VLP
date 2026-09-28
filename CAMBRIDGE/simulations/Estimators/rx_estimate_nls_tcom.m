function [position, info] = rx_estimate_nls_tcom(mean_W, normals, p, counts, options)
if nargin<4
    counts = [];
end
if nargin<5
    options = struct();
end
[position, info] = rx_estimate('NLS_TCOM', mean_W, normals, p, counts, options);
end
