function [transmitted,valid] = gob_snell(directions,normals,ratio)
cosine = sum(directions.*normals,1);
discriminant = 1-ratio^2*(1-cosine.^2);
valid = discriminant>=0 & cosine>0;
transmitted = ratio*directions+normals.*(sqrt(max(discriminant,0))-ratio*cosine);
end
