Experiment 02 - database acquisition
=====================================
points.csv      one row per measurement (position x orientation), compact summary:
  meas_id/site_id     measurement / grid position id (see plan.csv); ix,iy,iz grid indices; k angle index
  *_cmd_*             commanded pose; x_mm,y_mm,z_mm,angle_deg measured pose (gantry/MTRS feedback)
  mtrs_tilt_deg       measured MTRS tilt (kept at the config value, normally 0)
  pd_tilt_deg         mechanical tilt of the PD mount (3D-printed part) - recorded only
  <f>kHz_fft_Vrms  scope FFT peak near f (scope Math FFT, units Vrms)
  <f>kHz_wave_Vrms    RMS amplitude of the f sinusoid in the raw waveform (lock-in projection)
  *_std               std over the samples (only when n_samples > 1)
  clip_frac           fraction of waveform samples at the screen edge (> 0 means saturation)
  wave_ac_rms_V       total RMS of the waveform (signal + noise)
fft/mNNNNN.csv  scope FFT of every sample: frequency_Hz, acq_1..acq_n
wave/mNNNNN.npz raw waveform: np.load(...) -> v (n x samples, float32 V), fs (Sa/s), unix (s)
plan.csv        all planned measurements; trajectory.csv: gantry + MTRS telemetry at 10 Hz
session.json    plan configuration, devices and scope settings, final status
