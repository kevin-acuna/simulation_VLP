function cfg = pp_config()
% Shared configuration of the manuscript figures: dataset locations, testbed geometry and the calibration
% used by the live demo (fixed before the blind random test). Paths are resolved from this file.
lib = fileparts(mfilename('fullpath'));
cfg.figdir = fileparts(lib);
cfg.cambridge = fileparts(fileparts(cfg.figdir));
cfg.sim = fullfile(cfg.cambridge, 'simulations');
cfg.analysis = fullfile(cfg.cambridge, 'analysis');
acq = fullfile(cfg.cambridge, 'database_acquisition', 'data');
demo = fullfile(cfg.cambridge, 'demo', 'data');

% D1: flat-PD scan (0 deg adapter, K = 1), 141 x 141 points, 10 mm, four LEDs
cfg.scan_dir = fullfile(acq, 'campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z180_K1-off65_pd0_tilt0_100ms');
cfg.scan_z_mm = 180;
cfg.cal_n = 14294;                       % first 14,294 scan points (x <= 1.01 m): calibration subset used by the demo
% D2: regular grid, 125 sites (5 x 5 x 5 heights), K = 10, 15 deg adapter
cfg.grid_dirs = {fullfile(acq, 'campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z180to360_K10-off65_pd15_tilt0_100ms'), ...
                 fullfile(acq, 'campaign_20261015-000723_grid5x5x3-xy100to1300-s300-z0to120_K10-off65_pd15_tilt0_100ms')};
% D3: blind random test of the live demo, K = 5 (points after the rotation-stage tilt fault of 16/10 excluded)
cfg.random_dirs = {fullfile(demo, 'demo_20261016-113422_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms'), ...
                   fullfile(demo, 'demo_20261016-174621_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms')};
cfg.random_keep = [47 Inf];
% repeated records (n_samples > 1, flat PD) for the record-to-record repeatability
cfg.repeat_dirs = {fullfile(acq, 'campaign_20261013-101402_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx2'), ...
                   fullfile(acq, 'campaign_20261013-103703_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-2to2_100msx10'), ...
                   fullfile(acq, 'campaign_20261013-113114_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx5')};

% geometry (metres): PD centre height = base height at gantry z = 0 + z + PD elevation (tape + CAD)
cfg.H_led = 3.0;
cfg.H_base0 = 0.858;                     % gantry base 1.038 m at z = 180 mm (tape)
cfg.pd_elev = 0.09696;                   % gantry base -> PD centre (MTRS + adapter, CAD)
cfg.led_freqs_khz = [300 500 700 900];
cfg.freq_khz = 500;                      % positioning LED
% calibration used by the demo (D1 for A, m, LED XY; D2 for the MTRS offset)
cfg.led_xy_mm = [281.1 904.8];
cfg.led_xy_max_mm = [270 890];           % grid point of maximum RSS in D1
cfg.A = 0.062707;
cfg.m = 6.0918;
cfg.offset_deg = 66.5;
cfg.nominal_offset_deg = 65;
cfg.tilt_deg = 15;
% receiver responses (PDA100A2, Bastiaens 2020)
cfg.psi3db = 0.61;
cfg.m_R = 1.9;
cfg.cos_fov_deg = 64;
end
