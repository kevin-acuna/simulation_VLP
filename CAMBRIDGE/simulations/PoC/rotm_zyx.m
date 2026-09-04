function R = rotm_zyx(yaw_deg, pitch_deg, roll_deg)
%ROTM_ZYX  Body-to-world rotation matrix from yaw (z), pitch (y), roll (x) [deg].
%   R = Rz(yaw) * Ry(pitch) * Rx(roll);   v_world = R * v_body
cy = cosd(yaw_deg);   sy = sind(yaw_deg);
cp = cosd(pitch_deg); sp = sind(pitch_deg);
cr = cosd(roll_deg);  sr = sind(roll_deg);
Rz = [cy -sy 0; sy cy 0; 0 0 1];
Ry = [cp 0 sp; 0 1 0; -sp 0 cp];
Rx = [1 0 0; 0 cr -sr; 0 sr cr];
R = Rz * Ry * Rx;
end
