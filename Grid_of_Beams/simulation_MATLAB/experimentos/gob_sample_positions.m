function points = gob_sample_positions(c,count,stream)
points = zeros(3,count);
points(1:2,:) = c.half_width*(2*rand(stream,2,count)-1);
if c.dimensions==3
    u = rand(stream,1,count);
    points(3,:) = u;
    if c.frustum
        points(3,:) = 3-(27-19*u).^(1/3);
        points(1:2,:) = points(1:2,:).*(3-points(3,:))/3;
    end
end
end
