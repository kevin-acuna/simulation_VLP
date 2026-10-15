Database Acquisition Tool - session data
=========================================
points.csv      one row per measurement (position x orientation), compact summary:
  meas_id/site_id     measurement / grid position id (see plan.csv); ix,iy,iz grid indices
  pass                repetition of the whole route (1..n_passes); same site_id + k in different passes =
                      same pose measured again -> group by (site_id, k) to get the variance per point
  k                   angle index: angle_cmd_deg = (angle_offset_deg + 360*k/K) mod 360 (session.json)
  *_cmd_*             commanded pose; x_mm,y_mm,z_mm,angle_deg measured pose (gantry/MTRS feedback)
  mtrs_tilt_cmd_deg   commanded MTRS tilt (fixed, or uniform random per position x orientation; session.json)
  mtrs_tilt_deg       measured MTRS tilt
  pd_tilt_deg         tilt of the 3D-printed adapter holding the PD on the MTRS - recorded only
  <f>kHz_fft_Vrms  FFT peak near f, full resolution (Python FFT, Hanning, whole record)
  <f>kHz_wave_Vrms    RMS amplitude of the f sinusoid over the whole continuous record (lock-in projection at f)
  *_std               std over the samples (only when n_samples > 1)
  clip_frac           fraction of waveform samples at the screen edge (> 0 means saturation)
  wave_ac_rms_V       total RMS of the waveform (signal + noise)
Each sample is ONE continuous record (100 ms at 10 MSa/s, 1,000,000 points); see session.json "record".
fft/mNNNNN.csv  FFT of every sample: frequency_Hz, acq_1..acq_n. Reduced to <= 4000 bins by taking
                the maximum of each group of bins (peaks preserved); the full-resolution spectrum can be
                recomputed from the waveform (hardware.scope.spectrum_vrms).
wave/mNNNNN.npz raw waveform, lossless ADC codes:
                  z = np.load(path); v = (z["codes"] - z["y_reference"][:, None]) * z["y_increment"][:, None]
                                         + z["y_origin"][:, None]          # volts, shape (n, samples)
                  t = np.arange(v.shape[1]) / z["fs"]; z["unix"] = start time of each sample
                (simulated scope: z["v"] holds the volts directly)
plan.csv        all planned measurements; trajectory.csv: gantry + MTRS telemetry at 10 Hz
session.json    plan configuration, devices and scope settings, final status
