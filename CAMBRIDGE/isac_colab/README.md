# ISAC acquisition - single LED, photodetector on the MTRS

Data registration for integrated sensing and communication (ISAC) with one ceiling LED: the AWG drives the LED
(bias tee RF input) with a repeating cycle of a **pilot tone** (positioning) followed by an **OFDM burst**
(communication); the photodetector (PD) on the MTRS, carried by the gantry, is recorded by the oscilloscope.
For every capture the program stores the pilot RMS amplitude (Vrms) and the communication results (BER,
training-averaged BER, EVM, frames) in Excel, plus the raw record. No position is estimated.

The signal chain (waveform, AWG upload, oscilloscope capture, receiver) is the ICS Python program of the
communication software (port of the working MATLAB bench), reorganised and without the interactive console:
for the same inputs it gives bit-identical results.

## Transmitted cycle (defaults = test of 13/11/2026)

```
| pilot 500 kHz: 1 ms lead + 10 ms observation + 1 ms tail | OFDM 64-QAM: 15 frames = 10.4448 ms |  -> repeated
|<------------------------- 12 ms ------------------------>|<----------- 10.4448 ms ----------->|
cycle 22.4448 ms, 359 MB in the AWG (16 GSa/s, 1 Vpp, channel 1)
```

OFDM: NFFT 1024, CP 64, 33 carriers from 305 to 794 kHz, 2 QPSK training + 8 payload symbols per frame
(nominal 2.27 Mb/s during the burst). A 100 ms capture (10 ms/div, 2 Mpts, 20 MSa/s) holds ~3 complete cycles:
~3 pilot windows and ~45 OFDM frames.

## Folder

```
01_check_instruments.py   step 1: VISA, AWG and oscilloscope check (read only)
02_single_capture.py      step 2: one capture at the current pose (the ICS sequence, no console)
03_isac_acquisition.py    step 3: GUI acquisition with gantry + MTRS (plan and manual)
config/devices.toml       instrument addresses and device settings (once per PC)
isac/                     signal chain: waveform, AWG/scope I/O (VISA), receiver, storage, simulation
hardware/                 gantry (igus, CRI) and MTRS (Thorlabs Kinesis) drivers
acquisition/              plan, control engine and GUI of step 3
tests/                    offline tests (no hardware)
data/                     sessions (created by the scripts, ignored by git)
```

Hyperparameters (waveform, plan, timing) are at the top of each script; device settings only in
`config/devices.toml`.

## Setup on a new PC

Requirements: Windows, 64-bit Python >= 3.12, Keysight IO Libraries Suite (VISA), Thorlabs Kinesis (MTRS),
Keysight M8195A soft front panel. In a terminal opened in this folder:

```
py -3.12 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m unittest discover -s tests -t .
```

Then check `config/devices.toml`: AWG address (`TCPIP0::localhost::inst0::INSTR`), oscilloscope address
(`USB0::0x0957::0x17BC::MY63420113::0::INSTR`), Keysight DLL folder, gantry IP, Kinesis path.

## Use

Before: M8195A soft front panel running with FOUR DAC mode, DIV4 (16 GSa/s), channel 1 in extended memory,
1 Vpp, 0 V offset, outputs 2-4 off (the program checks these settings, it never changes them); no other program
(MATLAB, BenchVue) connected to the AWG or the oscilloscope; oscilloscope with the working vertical scale and
trigger (the program only sets the timebase, Normal acquisition and the transfer format); gantry referenced in
iRC; MTRS homed in Kinesis and Kinesis closed. Only the ISAC LED should be modulated: the other LED tones
(300 / 700 / 900 kHz) fall in the OFDM band and in the pilot quality band (200-900 kHz).

1. `.venv\Scripts\python.exe 01_check_instruments.py` - VISA library and resources, AWG profile, oscilloscope
   settings. Changes nothing.
2. `.venv\Scripts\python.exe 02_single_capture.py` - loads the waveform (or reuses it, see below), captures,
   prints the ICS summary (`ToneRMS_mV`, `OriginalBER`, `AveragedBER`, frames, `CombinedCriteriaMet`) and saves a
   session. Compare with the ICS / MATLAB result before step 3.
3. `.venv\Scripts\python.exe 03_isac_acquisition.py` - GUI:
   - **Start plan**: grid `X_MM x Y_MM x Z_MM` (or `SITES_MM`) x `K_ORIENTATIONS` MTRS angles x `N_CAPTURES`;
     serpentine route, angles in increasing / decreasing order on alternate sites, MTRS tilt commanded again at
     every site. **Pause / Resume**, **Skip**, **STOP** (the plan can then be continued: *Continue plan*).
   - **Go & measure**: moves to the typed X, Y, Z [mm] and rotation [deg] and captures; **Measure here**:
     captures without moving.
   - Errors of the instruments or of the motion pause the plan: *Resume* retries, *Skip* records the
     measurement as failed. A high BER or a rejected pilot window is a result, not an error.
   - Closing the window ends the session (AWG output off if `AWG_OFF_AT_EXIT`).

Add `--sim` to steps 2 and 3 to run everything with simulated devices.

**AWG waveform reuse.** At start the AWG is stopped and its memory is compared with the prepared waveform
(length + the tone/OFDM boundaries + 32 evenly spaced 128-sample blocks read back). If it is the same waveform it is only restarted (no upload); otherwise a
different waveform is backed up to `data/awg_backups/` and the new one is uploaded (359 MB).

## Output: `data/isac_<date>_<plan>[_<label>]/`

| file | content |
|---|---|
| `results.xlsx` | sheets `captures`, `tone_windows`, `ofdm_slots` (= the CSV files) and `session` |
| `captures.csv` | one row per capture (columns below) |
| `tone_windows.csv` | one row per pilot window: cycle, start, Vrms, DC, purity, peak frequency, valid, status |
| `ofdm_slots.csv` | one row per OFDM burst: measured durations, frames, bit errors, BER, averaged BER, EVM |
| `wave/cNNNNN.npz` | raw record: WORD codes + scale, `V = (codes - y_reference) * y_increment + y_origin` |
| `figures/cNNNNN.png` | record (pilot windows / OFDM slots), spectrum of the whole record and OFDM constellation (`SAVE_FIGURES`) |
| `session.json` | hyperparameters, devices, instruments, AWG load / reuse, oscilloscope settings (scale, offset, coupling, impedance, BW limit, acquisition; at the start and, in step 3, at the end), status |
| `experiment.npz`, `transmission.npz` | prepared waveform (needed to re-process the raw records) and AWG metadata |

`captures` columns: identification (`capture_id`, time, `mode` = plan / manual / here / single, `site_id`,
`k`, `rep`); commanded and measured pose (`x|y|z_cmd_mm`, `angle_cmd_deg`, `tilt_cmd_deg`, `x|y|z_mm`,
`angle_deg`, `tilt_deg`, errors, drift, move time); pilot (`tone_Vrms` = first valid window, as the ICS
`ToneRMS`; `tone_Vrms_mean` / `_std` over the valid windows, number of windows, minimum purity, DC);
communication (`ber`, `bit_errors`, `ber_avg`, `bit_errors_avg`, `n_bits`, `evm_pct`, frames accepted / rejected /
expected, cycles, `timing_ok`, `ofdm_target_met`, `isac_ok` = ICS `CombinedCriteriaMet`, `reason`); record
(`fs_Sa_s`, points, duration, mean / min / max, `wave_file`, `error`).

The CSV files are written row by row; `results.xlsx` is rebuilt after every capture. If it is open in Excel it
is updated after Excel closes it.

Re-process a raw record:

```python
from isac import process
from isac.storage import load_experiment, load_capture
exp = load_experiment(session_dir)
state = process(load_capture(session_dir, 12, exp), exp)
```
