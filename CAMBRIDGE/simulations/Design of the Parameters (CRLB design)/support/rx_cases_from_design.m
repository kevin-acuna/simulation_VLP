function cases = rx_cases_from_design(design, indices)
if ischar(design) || isstring(design)
    saved = load(design, 'results');
    assert(isfield(saved, 'results'), 'cambridge:DesignFile', 'Expected a design_results.mat dataset.');
    design = saved.results;
end
if nargin < 2
    indices = 1:numel(design.best);
end
validateattributes(indices, {'numeric'}, {'integer', 'positive', '<=', numel(design.best), 'nonempty'});
items = cell(1, numel(indices));
for j = 1:numel(indices)
    b = design.best(indices(j));
    c = rx_cone_cases(design.parameters, b.half_angle_deg, b.cone_tilt_deg, b.K_recommended);
    c.fov_deg = b.fov_deg;
    c.normals = b.normals;
    c.family = 'explicit';
    c.tilt_deg = NaN;
    c.azimuth_offset_deg = NaN;
    items{j} = c;
end
cases = [items{:}];
end
