# Columns of the session files

Every session folder `data/isac_<date>_<plan>[_<label>]/` contains three tables, written as CSV row by row and
together in `results.xlsx` (one sheet each), plus a `session` sheet (= `session.json`). Empty cell = not
applicable or not available (e.g. no valid pilot window, a skipped measurement).

Waveform figures used below (defaults, ICS test of 13/11/2026): pilot 500 kHz, pilot slot 12 ms (1 ms lead +
10 ms observation + 1 ms tail); OFDM slot 15 frames = 10.4448 ms; cycle 22.4448 ms (OFDM = 46.5 % of the cycle).
One OFDM frame = 2 QPSK training + 8 payload symbols, 1088 samples each at 15.625 MSa/s = 0.69632 ms; 33 carriers
(305-794 kHz) x 6 bits (64-QAM) x 8 payload symbols = 1584 payload bits per frame. A 100 ms capture holds 3 or 4
complete cycles (45 or 60 frames).

## `captures`: one row per capture

### Identification and pose

| Column | Unit | Definition |
|---|---|---|
| `capture_id` | | 1, 2, ... in the session; raw record `wave/cNNNNN.npz`, figure `figures/cNNNNN.png` |
| `iso_time` | | local time when the row was saved (ISO 8601) |
| `unix_time_s` | s | time just after the capture (seconds since 1970) |
| `mode` | | `plan` (Start plan), `manual` (Go & measure), `here` (Measure here), `single` (02_single_capture.py) |
| `site_id` | | site of the plan, 1-based (empty outside the plan) |
| `k` | | orientation index: the angle is `ANGLE_OFFSET_DEG + 360 k / K` (empty outside the plan) |
| `rep` | | repetition at the same pose, 0 .. `N_CAPTURES` - 1 |
| `x_cmd_mm`, `y_cmd_mm`, `z_cmd_mm` | mm | commanded gantry position (empty for `here` / `single`) |
| `angle_cmd_deg`, `tilt_cmd_deg` | deg | commanded MTRS rotation and motorized tilt |
| `x_mm`, `y_mm`, `z_mm`, `angle_deg`, `tilt_deg` | mm, deg | measured pose: mean of the readings just before and just after the capture |
| `pos_err_mm` | mm | distance between measured and commanded position |
| `angle_err_deg` | deg | measured - commanded rotation (wrapped to +/-180) |
| `pos_drift_mm` | mm | gantry displacement between the readings before and after the capture |
| `move_time_s` | s | time from the start of the motion to the arrival (0 = no motion) |

### Pilot (sensing)

| Column | Unit | Definition |
|---|---|---|
| `tone_freq_Hz` | Hz | pilot frequency |
| `tone_Vrms` | V | pilot RMS amplitude of the **first valid pilot window** (ICS `ToneRMS`): least-squares fit of cos + sin + DC at the pilot frequency over the 10 ms observation window |
| `tone_Vrms_mean`, `tone_Vrms_std` | V | mean and standard deviation of the pilot RMS over all valid windows of the capture (std empty with one window) |
| `snr_pilot_dB` | dB | 20 log10(`tone_Vrms` / sigma), sigma = sqrt(N0 / 2T) = std of a least-squares amplitude over the window T (10 ms) in white noise of one-sided density N0; N0 = median noise level within +/-100 kHz of the pilot (+/-3 kHz excluded). Same definition as RSS / sigma |
| `tone_windows_valid`, `tone_windows` | | valid / detected pilot windows in the capture |
| `tone_purity_min` | | lowest purity of the windows: fraction of the 200-900 kHz power explained by the pilot (1 = pure tone; a window needs >= 0.8) |
| `tone_dc_V` | V | DC term of the fit in the first valid window (about 0 with AC coupling) |

### Rates (communication)

| Column | Unit | Definition |
|---|---|---|
| `goodput_Mbps` | Mb/s | payload bits decoded **correctly** / airtime of all the expected frames = (`n_bits` - `bit_errors`) / (`frames_expected` x 0.69632 ms). Rejected frames count as 0 bits. At a very high BER the bits that are right by chance still count (about 50 % of the accepted bits), so it never falls to 0 while frames are accepted |
| `goodput_frames_Mbps` | Mb/s | **frame (packet) goodput**: payload of the accepted frames with **no** bit error / airtime of all the expected frames = error-free frames x 1584 bits / (`frames_expected` x 0.69632 ms). Without error correction a frame with one wrong bit is lost: this is the rate that falls to 0 in difficult places |
| `goodput_avg_Mbps` | Mb/s | `goodput_Mbps` with the training-averaged decisions (empty when averaging is not available) |
| `goodput_cycle_Mbps` | Mb/s | `goodput_Mbps` averaged over the whole cycle (x OFDM fraction of the cycle, 0.465 by default): grows when the OFDM slot is longer and the pilot slot shorter |
| `rate_nominal_Mbps` | Mb/s | payload rate sent during the OFDM slot = 1584 bits / 0.69632 ms = 2.2748 (ICS `NominalOFDMslotPayload_Mbps`). Depends only on the waveform (QAM order, carriers), not on the pose |
| `rate_nominal_cycle_Mbps` | Mb/s | `rate_nominal_Mbps` x OFDM fraction of the cycle = 1.0586 by default (ICS `NominalCyclePayload_Mbps`) |
| `shannon_est_Mbps` | Mb/s | **estimate, not a measurement**: the same frame structure with log2(1 + SNR) bits per carrier instead of 6 (SNR from `snr_comm_dB`) |

### Communication details

| Column | Unit | Definition |
|---|---|---|
| `ber` | | `bit_errors` / `n_bits`: bit error rate of the accepted frames, channel estimated from each frame's own 2 training symbols (ICS `OriginalBER`) |
| `bit_errors`, `n_bits` | bits | errors and decoded bits over the accepted frames (`n_bits` = accepted frames x 1584) |
| `ber_avg`, `bit_errors_avg` | | the same with the channel estimated from the training of the **other** frames of the same burst (leave-one-out average, ICS `AveragedBER`); only when every frame was accepted |
| `evm_pct` | % | RMS error vector magnitude of the equalized payload symbols vs the transmitted ones (accepted frames) |
| `snr_comm_dB` | dB | -20 log10(EVM): effective SNR of the demodulated symbols (noise, interference, quantization and channel-estimation error included) |
| `frames_accepted`, `frames_rejected`, `frames_expected` | | frames that passed / failed the synchronization and training checks; expected = complete cycles x 15 |
| `cycles_complete` | | complete pilot + OFDM cycles in the record (cycles cut by the record edges are excluded) |
| `cycles_timing_ok` | | complete cycles whose measured pilot / OFDM / cycle durations match the plan within +/-0.3 ms |
| `timing_ok` | | every complete cycle has a valid timing (and there are at least 2) |
| `ofdm_target_met` | | averaged BER <= target (1e-3) with every frame accepted (original BER if training averaging is off) |
| `isac_ok` | | ICS `CombinedCriteriaMet`: valid timing, no rejected pilot window, a valid pilot and `ofdm_target_met` |
| `reason` | | receiver message (why a capture failed a criterion) |

### Record

| Column | Unit | Definition |
|---|---|---|
| `fs_Sa_s` | Sa/s | sample rate of the oscilloscope record |
| `n_points` | | samples in the record |
| `duration_ms` | ms | record duration |
| `wave_mean_V`, `wave_min_V`, `wave_max_V` | V | mean, minimum and maximum of the record |
| `wave_file` | | raw record (see below) |
| `error` | | instrument / motion error of a failed or skipped measurement (empty otherwise) |

## `tone_windows`: one row per pilot window

| Column | Unit | Definition |
|---|---|---|
| `capture_id` | | capture of the window |
| `window`, `cycle` | | window number in the capture; cycle it belongs to |
| `start_ms`, `duration_ms` | ms | start (from the beginning of the record) and length of the observation window |
| `n_samples` | | samples in the window |
| `tone_Vrms`, `dc_V` | V | pilot RMS and DC term of the least-squares fit |
| `purity` | | fraction of the 200-900 kHz power explained by the pilot |
| `peak_freq_Hz` | Hz | FFT peak near the pilot frequency |
| `accepted` | | tone quality passed (purity >= 0.8 and peak at the pilot frequency) |
| `valid` | | full window inside a pilot slot with valid timing (usable observation) |
| `status` | | validation message |

## `ofdm_slots`: one row per OFDM burst (one per complete cycle)

| Column | Unit | Definition |
|---|---|---|
| `capture_id`, `cycle` | | capture and cycle |
| `tone_start_ms` | ms | detected start of the pilot slot of this cycle |
| `tone_ms`, `ofdm_ms`, `cycle_ms` | ms | measured pilot slot, OFDM slot and cycle durations (detector resolution 0.1 ms) |
| `timing_ok` | | durations match the plan within +/-0.3 ms |
| `frames_expected`, `frames_located`, `frames_accepted`, `frames_rejected` | | frames of the burst (15 expected) |
| `n_bits`, `bit_errors`, `ber` | | as in `captures`, for this burst |
| `bit_errors_avg`, `ber_avg` | | training-averaged decisions for this burst |
| `evm_pct` | % | EVM of the burst |
| `goodput_Mbps`, `goodput_frames_Mbps` | Mb/s | as in `captures`, for the 15 frames of this burst |
| `reason` | | decoder message |

## `session` sheet (`session.json`)

`name`, `started`, `finished`, `status` (`done`, `closed (n/N plan measurements done)`, `interrupted`, `error`);
`script`; `hyperparameters` (ISAC waveform + plan values at the top of the script); `angles_deg`, `n_plan`,
`n_captures`; `devices` (`config/devices.toml`); `testbed` (gantry / MTRS information); `waveform` (text summary);
`instruments` (identification strings); `transmission` (`reused` = the waveform already in the AWG was kept,
`transmittedAt`, `Vpp`); `scope_settings` (at the start) and `scope_settings_end` (at the end of a
03_isac_acquisition.py session): channel, vertical scale `ch_scale_V_div`, `ch_offset_V`, `ch_coupling`,
`ch_impedance`, `ch_bw_limit`, `ch_probe`, `ch_invert`, `acquire_type`, `sample_rate_Sa_s`, `timebase_s_div`,
`timebase_mode`, `trigger_sweep`; `reprocessed` (time the tables were rebuilt from the raw records, if they were).

## Other files

| File | Content |
|---|---|
| `wave/cNNNNN.npz` | raw record, lossless: `codes` (uint16 WORD codes), `fs`, `x_increment`, `x_origin`, `x_reference`, `y_increment`, `y_origin`, `y_reference`, `preamble`, `captured_at`. Volts: V = (`codes` - `y_reference`) x `y_increment` + `y_origin`; time: t = (i - `x_reference`) x `x_increment` + `x_origin` |
| `figures/cNNNNN.png` | record (pilot windows green, OFDM slots blue), spectrum of the whole record (0-5 MHz) and constellation of the first accepted frame |
| `experiment.npz` | prepared waveform (OFDM packet + timing plan): needed to decode the raw records again (`isac.storage.load_experiment` / `load_capture`) |
| `transmission.npz` | AWG load / reuse metadata |
