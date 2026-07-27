function nt = df_angles_to_nt(incl_deg, az_deg)
% DF_ANGLES_TO_NT  LED orientation unit vectors (nadir-referenced).
%
%   nt = df_angles_to_nt(incl_deg, az_deg)
%
% Convention used by sub3_spatial.cpp / experiment_config.h CODEBOOK:
%   incl = 0  -> LED points to the nadir  ->  [0; 0; -1]  (straight down)
%   incl,az measured in degrees. incl from the -Z (down) axis, az about +Z.
%
% incl_deg, az_deg may be scalars or vectors (N elements). Returns a 3xN
% matrix whose columns are unit vectors, matching the 'nt' input expected by
% vlp_gls / vlp_wls / broadcast_distance.
%
% This matches the simulation helper 'orient_to_vectors' in
% F_broadcast_Konly/simulations/system_params_F.m.

    incl = incl_deg(:).';
    az   = az_deg(:).';
    nt = [ sind(incl) .* cosd(az);
           sind(incl) .* sind(az);
          -cosd(incl) ];
end
