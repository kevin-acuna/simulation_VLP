function centers = gob_footprints(m,height)
if nargin<2
    height = 0;
end
s = (height-m.origins(3,:))./m.directions(3,:);
centers = m.origins+m.directions.*s;
end
