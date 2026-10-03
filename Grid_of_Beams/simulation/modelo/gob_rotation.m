function R = gob_rotation(alpha,beta)
Rx = [1,0,0;0,cos(alpha),-sin(alpha);0,sin(alpha),cos(alpha)];
Ry = [cos(beta),0,sin(beta);0,1,0;-sin(beta),0,cos(beta)];
R = Ry*Rx;
end
