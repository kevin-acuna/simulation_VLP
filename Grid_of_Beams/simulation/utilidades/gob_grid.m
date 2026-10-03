function points = gob_grid(bounds,counts,height)
if nargin<3, height = 0; end
d = size(bounds,1); axes = cell(1,d); mesh = cell(1,d);
for j = 1:d
    if counts(j)==1
        axes{j} = bounds(j,1);
    else
        axes{j} = linspace(bounds(j,1),bounds(j,2),counts(j));
    end
end
[mesh{:}] = ndgrid(axes{:});
points = zeros(3,prod(counts));
for j = 1:d
    points(j,:) = reshape(permute(mesh{j},d:-1:1),1,[]);
end
if d==2
    points(3,:) = height;
end
end
