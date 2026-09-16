function [x, probability] = rx_empirical_cdf(values, max_points)
if nargin<2
    max_points = 2000;
end
finite = sort(values(isfinite(values)));
finite = finite(:);
if isempty(finite)
    x = 0;
    probability = 0;
    return;
end
indices = unique(round(linspace(1, numel(finite), min(numel(finite), max_points))));
x = [0; finite(indices(:))];
probability = [0; indices(:)/numel(values)];
end
