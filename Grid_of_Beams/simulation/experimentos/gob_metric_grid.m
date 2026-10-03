function points = gob_metric_grid(c,resolution)
heights = 1;
if c.dimensions==3, heights = 5; end
points = gob_grid([-c.half_width,c.half_width;-c.half_width,c.half_width;0,1],[resolution,resolution,heights]);
if c.frustum, points(1:2,:) = points(1:2,:).*(3-points(3,:))/3; end
end
