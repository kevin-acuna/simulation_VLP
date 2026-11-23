# AGENTS.md

## Environment notes
- `python` = 3.13 (has numpy, PyMuPDF/fitz, no pptx/matplotlib); `py -3.14` has python-pptx, python-docx, Pillow, numpy,
  scikit-learn 1.7.2 / scipy 1.16.3 (installed 2026-11-18 for the ML slide).
- MATLAB R2026b available (`matlab -batch "<fn>"`, run from the folder containing the function).
- LaTeX (TeX Live 2026: pdflatex, pdftotext, pdftoppm) and Microsoft 365 PowerPoint (COM) are installed.

## OPTI-6G ArchWG presentation (`OPTI-6G/ArchWG_Presentation/`)
Pipeline (all outputs stay inside that folder; experiment data folders are read-only):
1. `cd scripts/matlab; matlab -batch "run_exp3_analysis"` -> runs `ExpValidation_Journal/Experiments/exp3_SpatialDF/lib/df_run_analysis.m` on all sessions, saves `results/exp3_results.mat`.
2. `cd scripts/matlab; matlab -batch "make_exp3_figures"` -> slide figures in `figures/exp3_*.png` + `results/exp3_metrics.txt`.
3. `py -3.13 scripts/make_equations.py` -> LaTeX equations as PNG in `figures/eq/`.
4. `py -3.14 scripts/build_presentation.py` built v1 of the .pptx on the template `OPTI-6G/Material/OPTI-6G RSSwithML Main Results- v2.pptx`.
   The deck was then edited by hand (2026-11-18): do NOT rebuild it from scratch. `py -3.14 scripts/revise_v2.py` re-applies the
   second revision (2 m x 2 m target-zone metrics, new figures, wording) on top of `_backup/OPTI-6G_ArchWG_..._user-edit_2026-11-18_1243.pptx`.
5. Verify: `powershell -File scripts/render_pptx.ps1 -PptxPath <pptx> -OutDir _render` then `py -3.14 scripts/montage.py _render _render/m_all.png 3`.
- Template body font is the theme minor font (Bookman); text boxes use the major font `+mj-lt` (Open Sans) for consistency.
- 3D KPI evaluation: target zone |x|,|y| <= 1 m under the AP (577 of 808 positions), K = 9, NLS, nadir C; zone metrics are in `results/exp3_metrics.txt`.
- ML slide (Extra-Trees + MLP correcting the NLS estimate, 5-fold CV grouped by location, never the same location in
  train and test): `cd scripts/matlab; matlab -batch "export_nls_estimates"` -> `results/nls_estimates.csv`;
  `py -3.14 scripts/ml_positioning.py` -> `results/ml_predictions.csv`, `results/ml_metrics.txt`;
  `cd scripts/matlab; matlab -batch "make_ml_figure"` -> `figures/exp3_ml_cdf.png`.
  Stricter splits (spatial blocks, whole sessions): `py -3.14 scripts/ml_split_check.py`; inference time: `scripts/ml_latency.py`.

## Cambridge final-meeting deck (`CAMBRIDGE/PPTs/final_meeting/`, 2026-11-23)
7-slide summary of the visit for Iman (English, high level): title, TIM manuscript (no submission status, user choice),
other results, software + digital twin (embedded video), ISAC with the AWG (+ user photo photos_videos/ISAC.jpeg),
collaborations (in the group: Rizwana, Hossein / new contacts: ProrokLab, MSR), next steps / keeping in touch.
Built on the master of `PPTs/2026-11-03 UVSQ Follow-up Meeting.pptx` (titles Helvetica 24 bold, accent1 lighter 40 %).
1. `py -3.14 make_assets.py` -> `assets/` (paper pages via pdftoppm, author placeholder line hidden; RSS maps; ISAC crops;
   images reused from earlier decks).
2. `assets/dbacq_ui.png`: `database_acquisition/.venv/Scripts/python.exe app/run.py --sim --no-browser --no-log --output <temp>`,
   POST a plan (/api/plan) + /api/start, then msedge --headless=new --window-size=1920,1200 --screenshot=...
   "http://127.0.0.1:8765/?snapshot=1&view=3d&config=1".
3. Video: `py -3.14 crop_video.py <temp>/twin.mp4` (16:9 crop drops the preview bar) then
   `powershell -File compress_video.ps1 -Video <temp>/twin.mp4 -OutMp4 assets/digital_twin.mp4` (PowerPoint Resample:
   bitrate is only a cap, ~3 MB; Save() keeps the original media, SaveAs writes the resampled one).
4. `py -3.14 build_deck.py` -> `PPTs/2026-11-24 Final meeting - Visit summary.pptx`; verify with the OPTI-6G
   `render_pptx.ps1` + `montage.py`.
