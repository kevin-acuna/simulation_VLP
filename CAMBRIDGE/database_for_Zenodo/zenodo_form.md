# Formulario de Zenodo: valores para copiar

Campos del formulario **New upload** de https://zenodo.org. Lo que está entre [corchetes] queda por completar con el
profesor. Los textos que se pegan están en inglés, como el README.

| Campo | Valor |
|---|---|
| Files | Los 17 archivos de `upload/`; vista previa por defecto: `README.md` |
| Do you already have a DOI? | No → **Get a DOI now!** (copiar el DOI en `build_package.py`, ver LEEME.md) |
| Resource type | Dataset |
| Title | Single-LED 3-D Visible Light Positioning With a Reorientable Photodiode: Measured RSS and Raw Waveforms |
| Publication date | La del día de publicación (valor por defecto) |
| Creators | Acuña-Condori, Kevin — ORCID [ ] — [LISV, Université Paris-Saclay (UVSQ)]; [co-autores del paper, en el mismo orden, con ORCID y afiliación] |
| Licenses | Creative Commons Attribution 4.0 International (CC BY 4.0) |
| Keywords | visible light positioning; VLP; indoor positioning; received signal strength; RSS; single LED; photodiode; reorientable receiver; optical wireless communications; 3-D positioning |
| Languages | English |
| Dates | Collected: 2026-10-13/2026-10-16 (description: "Acquisition of the datasets") |
| Version | 1.0 |
| Publisher | Zenodo (valor por defecto) |
| Related works | Is supplement to: [DOI del paper], resource type Publication / Journal article (se puede añadir después de publicar, editando los metadatos) |
| Funding | [Financiador y número de proyecto, si corresponde] |
| Contributors (opcional) | [Supervisores o responsables del laboratorio anfitrión, p. ej. role "Supervisor"] |
| Locations (opcional) | [LiFi R&D Centre, University of Cambridge, United Kingdom, si el profesor está de acuerdo] |
| Communities (opcional) | [Comunidad Zenodo del laboratorio o de la universidad, si existe] |
| Visibility | Public; o Restricted con embargo hasta [fecha], según se decida |

## Description (pegar en el campo Description)

This dataset contains the measurements of the article "3-D Visible Light Positioning With a Single LED and a Single
Reorientable Photodiode: Bounds, Calibration, and Experimental Validation". A photodiode, tilted by a fixed adapter
and turned by a motorized rotation stage, measures the received signal strength (RSS) of a ceiling-mounted LED, 3 m
above the floor, at a few known orientations; a Cartesian gantry places the receiver at known positions, which
provide the ground truth. Four LEDs on the same ceiling are modulated at 300, 500, 700 and 900 kHz and recorded
together.

The dataset contains four parts: D1, a scan of 141 × 141 positions (10 mm step) with the photodiode facing up, used to
characterize and calibrate the LEDs; D2, a regular grid of 125 positions at five heights with 10 orientations each;
D3, a blind test of 131 random positions with 5 orientations each, estimated live by a real-time demonstrator; and
R, repeated records at fixed positions for the noise of the RSS. Each part is provided as the original session files,
with every raw 100-ms oscilloscope record (10 MSa/s) from which the RSS was computed, and D1 to D3 also as an
analysis-ready table (position, orientation, photodiode normal and RSS of each record). README.md documents the
geometry, the columns and the file formats; example scripts in Python and MATLAB read the tables and the raw
waveforms.
