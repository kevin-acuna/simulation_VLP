function [positions_m, grid] = rx_testbed(p, mode)
if nargin < 2
    mode = 'design';
end
switch mode
    case 'design'
        x = p.environment.x_m;
        y = p.environment.y_m;
        z = p.environment.z_m;
    case 'validation'
        x = p.environment.validation_x_m;
        y = p.environment.validation_y_m;
        z = p.environment.validation_z_m;
    otherwise
        error('cambridge:GridMode', 'Unknown grid: %s.', mode);
end
[X, Y, Z] = ndgrid(x, y, z);
positions_m = [X(:)'; Y(:)'; Z(:)'];
grid = struct('x_m', x, 'y_m', y, 'z_m', z, 'size', size(X));
end
