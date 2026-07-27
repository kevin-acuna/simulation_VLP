function nr = df_angles_to_nr(incl_deg, az_deg)
% DF_ANGLES_TO_NR  PD (receiver) normal unit vectors (zenith-referenced).
%
%   nr = df_angles_to_nr(incl_deg, az_deg)
%
% Convention: the PD normal points AWAY from the floor toward the ceiling.
%   incl = 0  -> PD points to the zenith  ->  [0; 0; +1]  (straight up)
% For 'vertical' scans nr_incl = nr_az = 0 => nr = [0;0;1].
% For 'tilt'     scans nr_incl/nr_az are the commanded tilt of the PD.
%
% incl_deg, az_deg may be scalars or vectors (N elements). Returns a 3xN
% matrix whose columns are unit vectors, matching the 'nr' input expected by
% broadcast_distance (cos_psi = -nr' * nd).

    incl = incl_deg(:).';
    az   = az_deg(:).';
    nr = [ sind(incl) .* cosd(az);
           sind(incl) .* sind(az);
           cosd(incl) ];
end
