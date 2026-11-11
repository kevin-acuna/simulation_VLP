# AGENTS.md

## Environment notes
- `python` = 3.13 (has numpy, PyMuPDF/fitz, no pptx/matplotlib); `py -3.14` has python-pptx, python-docx, Pillow, numpy.
- MATLAB R2026b available (`matlab -batch "<fn>"`, run from the folder containing the function).
- LaTeX (TeX Live 2026: pdflatex, pdftotext, pdftoppm) and Microsoft 365 PowerPoint (COM) are installed.

## OPTI-6G ArchWG presentation (`OPTI-6G/ArchWG_Presentation/`)
Pipeline (all outputs stay inside that folder; experiment data folders are read-only):
1. `cd scripts/matlab; matlab -batch "run_exp3_analysis"` -> runs `ExpValidation_Journal/Experiments/exp3_SpatialDF/lib/df_run_analysis.m` on all sessions, saves `results/exp3_results.mat`.
2. `cd scripts/matlab; matlab -batch "make_exp3_figures"` -> slide figures in `figures/exp3_*.png` + `results/exp3_metrics.txt`.
3. `py -3.13 scripts/make_equations.py` -> LaTeX equations as PNG in `figures/eq/`.
4. `py -3.14 scripts/build_presentation.py` -> builds the .pptx on the template `OPTI-6G/Material/OPTI-6G RSSwithML Main Results- v2.pptx`.
5. Verify: `powershell -File scripts/render_pptx.ps1 -PptxPath <pptx> -OutDir _render` then `py -3.14 scripts/montage.py _render _render/m_all.png 3`.
- Template body font is the theme minor font (Bookman); text boxes use the major font `+mj-lt` (Open Sans) for consistency.
