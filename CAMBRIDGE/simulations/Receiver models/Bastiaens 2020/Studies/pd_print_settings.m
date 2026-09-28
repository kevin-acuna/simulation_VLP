function pd_print_settings(p,e)
fprintf('\nBASTIAENS 2020 MODEL STUDY - fixed radiometry unless explicitly swept\n');
fprintf('LED position=%s m; normal=%s; Pt=%g W; half-power=%g deg\n',mat2str(p.transmitter.position_m'), ...
    mat2str(p.transmitter.normal'),p.transmitter.power_W,p.transmitter.half_angle_power_deg);
fprintf('Actual area=%g mm^2; responsivity=%g A/W; Ts=%g; optical gain=%g; noise=%g W^2/sample\n', ...
    p.receiver.area_m2*1e6,p.receiver.responsivity_A_per_W,p.receiver.filter_transmission,p.receiver.optical_gain,p.noise.variance_W2);
fprintf('Default N_i=%g; total-budget option=%g; coverage threshold=%g cm\n', ...
    p.acquisition.samples_per_orientation,p.acquisition.total_samples,rx_coverage_threshold(p));
fprintf('Design x=%s; y=%s; z=%s m\n',mat2str(p.environment.x_m),mat2str(p.environment.y_m),mat2str(p.environment.z_m));
fprintf('Validation x=%s; y=%s; z=%s m\n',mat2str(p.environment.validation_x_m),mat2str(p.environment.validation_y_m),mat2str(p.environment.validation_z_m));
fprintf('Published coefficients are rounded literature presets, not new measurements or a noise calibration.\n');
if isfield(e,'families'), fprintf('Selected receiver models, in curve order: %s\n',strjoin(cellstr(string(e.families)),', ')); end
if isfield(e,'cosine_fov_deg')
    fprintf('Receiver cosine FOV half-angle = %g deg; chosen cutoff, independent of LED half-power angle.\n',e.cosine_fov_deg);
    fprintf('SQ/other paper external FOV = %g deg; intrinsic zeros may occur earlier.\n',e.outer_fov_deg);
end
if isfield(e,'m_R')
    if isempty(e.m_R)
        fprintf('cosine uses the published receiver order for each device; cosine_1 always uses m_R=1.\n');
    else
        fprintf('cosine uses editable m_R=%g; cosine_1 remains 1; SQ does not use m_R.\n',e.m_R);
    end
end
if isfield(e,'orientation_std_deg')
    fprintf('Angular input: STANDARD DEVIATION %g deg/component; variance = %g deg^2/component.\n', ...
        e.orientation_std_deg,e.orientation_std_deg^2);
    if strcmp(e.orientation_structure,'independent')
        fprintf('Independent uncertainty of each global PD normal; the global reference frame is known. No additional common attitude error.\n');
    else
        fprintf('Common attitude-reference rotation uncertainty, shared by all PD normals; not independent reorientation errors.\n');
    end
    fprintf('Joint RSS/orientation-measurement nuisance CRLB. The angular error persists across optical samples; it is not divided by N_i.\n');
    fprintf('Angular plots span 0--90 deg; the computed tilt sweep is %g--%g deg (mechanical limit %g deg).\n', ...
        min(e.tilt_values_deg),max(e.tilt_values_deg),p.receiver.max_tilt_deg);
    fprintf('Coverage: all-grid fraction with finite regular PEB <= target. RMS: square root of mean squared PEB over finite points only.\n');
    fprintf('Map axes x/y are position in metres; z identifies a slice, not a known estimator height.\n');
end
if isfield(e,'angles_deg')
    fprintf('Response axes: x = incidence psi in degrees; y = R(psi)/R(0), dimensionless.\n');
    fprintf('Derivative axes: x = incidence psi in degrees; y = |dR/dpsi| per RADIAN, away from nonregular cutoffs.\n');
end
if isfield(e,'peb_reference_cosine_1'), fprintf('Nominal cos(psi) PEB derivation: %s\n',e.peb_reference_cosine_1); end
if isfield(e,'orientation_peb_reference'), fprintf('Orientation-uncertainty bound: %s\n',e.orientation_peb_reference); end
disp(e);
end
