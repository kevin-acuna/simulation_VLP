function points = gob_boundary_positions(c)
heights = 0;
if c.dimensions==3, heights = [0,.5,1]; end
points = zeros(3,9*numel(heights)); index = 0;
for z = heights
    for x = [-1,0,1]
        for y = [-1,0,1]
            index = index+1; points(:,index) = [x*c.half_width;y*c.half_width;z];
        end
    end
end
if c.frustum, points(1:2,:) = points(1:2,:).*(3-points(3,:))/3; end
end
