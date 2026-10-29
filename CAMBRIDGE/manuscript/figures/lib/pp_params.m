function p = pp_params(cfg, model, A, m, led_xy_mm, noise_V)
% Parameter structure of the simulation library for the calibrated model RSS = A R(psi) cos^m(phi) / d^2.
% The transmitted power is chosen so that the radiometric constant C of the library equals A, so that the
% library returns volts. noise_V (optional) is the standard deviation of one RSS record (V).
base = system_parameters();
base.acquisition.samples_per_orientation = 1;
switch model
    case 'SQ'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'SQ', 90);
        p.receiver.response_parameters.psi_3db_rad = cfg.psi3db;
    case 'cosine_mR'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'cosine', cfg.cos_fov_deg, cfg.m_R);
    case 'cosine'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'cosine_1', cfg.cos_fov_deg);
    otherwise
        error('Unknown receiver model %s.', model);
end
p.transmitter.position_m = [led_xy_mm(:)/1e3; cfg.H_led];
p.transmitter.normal = [0; 0; -1];
p.transmitter.half_angle_power_deg = acosd(2^(-1/m));
p.transmitter.pattern_asymmetry = 0;
p.transmitter.power_W = 2*pi*A/((m + 1)*p.receiver.area_m2*p.receiver.filter_transmission*p.receiver.optical_gain);
p.calibration = struct('A', A, 'm', m, 'led_xy_mm', led_xy_mm, 'model', model);
if nargin > 5 && ~isempty(noise_V)
    p.noise.variance_W2 = noise_V^2;
end
end
