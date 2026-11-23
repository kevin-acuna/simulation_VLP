# Base de datos del paper TIM para Zenodo

Todo lo que se sube a Zenodo está en `upload/` (17 archivos, 10.9 GB), listo tal cual. El resto de la carpeta sirve
para regenerarlo y verificarlo.

| Elemento | Qué es |
|---|---|
| `upload/` | **Los archivos que se suben a Zenodo** (generados, ignorados por git: no hacer commit) |
| `zenodo_form.md` | Valores para copiar en el formulario de Zenodo |
| `build_package.py` | Genera `upload/` a partir de las sesiones originales (solo las lee) |
| `check_package.py` | Verifica `upload/` antes de subir |
| `verify_against_paper.m` | Comprueba que las tablas publicadas reproducen los resultados de D2 y D3 del paper |
| `static/` | Fuentes de los archivos de texto que se suben (README del dataset, licencia, ejemplos); se editan aquí, no en `upload/` |

## Contenido

- **D1** escaneo de calibración (19 881 registros, PD plano), **D2** malla (125 posiciones x K = 10), **D3** prueba
  ciega (131 posiciones x K = 5, con las estimaciones en vivo) y **R** registros repetidos para el ruido (47
  posiciones, 230 registros). Son exactamente los datos del paper.
- Para D1, D2 y D3, una tabla lista para usar (`*_RSS.csv`: X, Y, Z en m, ángulo, normal del PD, RSS) y las
  sesiones originales en ZIP (points.csv, plan.csv, trajectory.csv, estimates.csv, session.json y las formas de onda
  crudas `.npz`). R solo en ZIP.
- `README.md` en inglés: geometría, columnas, formato de las ondas, cómo citar. Ejemplos en Python y MATLAB.

## Verificado (23/11/2026)

- `python check_package.py`: 0 fallos (archivos y límites de Zenodo, MD5, CRC de los ZIP, conteos, cada onda
  referenciada presente, sin rutas locales, tablas = points.csv, RSS recalculado desde las ondas, columnas
  documentadas).
- `matlab -batch "verify_against_paper"`: las tablas publicadas dan 3.656514 cm (D2) y 4.100633 cm (D3), idénticos
  al pipeline del paper.
- Ejemplos de Python y MATLAB probados sobre una extracción de `D2_grid.zip`.

## Para el GO del profesor

1. **Permiso**: los datos se adquirieron en el LiFi R&D Centre (University of Cambridge); confirmar que se pueden
   publicar en abierto.
2. **Autores** del dataset (orden, afiliaciones, ORCID) y **persona de contacto**.
3. **Licencia**: propuesta CC BY 4.0 (la habitual para datos; obliga a citar).
4. **Momento**: publicar al enviar el paper (abierto, también para los revisores) o reservar el DOI ahora y
   publicar a la aceptación (o publicar con embargo).
5. **Agradecimientos y financiación** que deban figurar.
6. Título y descripción (en `zenodo_form.md`).

## Pasos después del GO

1. Completar el bloque `to complete before the upload` al inicio de `build_package.py` (CREATORS, ARTICLE,
   ACKNOWLEDGEMENTS, CONTACT).
2. En https://zenodo.org (se puede entrar con ORCID): **New upload**; en "Do you already have a DOI?" responder
   **No** y pulsar **Get a DOI now!**. El DOI queda reservado y solo se registra al publicar (si se borra el
   borrador, se pierde).
3. Poner ese DOI en `DOI = "..."` de `build_package.py` y ejecutar `python build_package.py` (1 min, los ZIP no se
   rehacen) y `python check_package.py`: debe terminar con 0 fallos y 0 placeholders.
4. Subir los 17 archivos de `upload/` (arrastrarlos al recuadro). Los cuatro ZIP de D1 pesan entre 2.1 y 2.7 GB:
   mejor con cable, de a uno o dos. Comprobar que los MD5 que muestra Zenodo coinciden con `upload/checksums.md5`.
5. Rellenar el formulario con `zenodo_form.md` y marcar `README.md` como vista previa por defecto (columna Preview).
6. **Save draft** y **Preview**. Para que el profesor lo revise antes de publicar: **Share**, pestaña Links,
   permiso "Can preview draft", y enviarle el enlace.
7. **Publish**. Después, los metadatos se pueden editar siempre, pero los archivos solo durante 30 días (luego hay que
   crear una nueva versión).
8. En el paper, añadir la disponibilidad de los datos, por ejemplo: "The dataset is openly available on Zenodo at
   https://doi.org/10.5281/zenodo.XXXXXXX." Cuando el paper tenga DOI, añadirlo en Zenodo en Related works como
   "Is supplement to" (editando los metadatos, sin nueva versión).

## Decisiones de preparación

- D3 = las 131 posiciones del paper: puntos 1-47 de la primera sesión y las 84 posiciones completas de la segunda.
  En el session.json de D3 se quitaron el resumen en vivo y la hora de fin (se referían a la sesión entera) y los
  conteos corresponden a lo publicado.
- No se suben los espectros reducidos `fft/*.csv` (se recalculan desde las ondas) ni el README.txt automático de
  cada sesión; se quitó la columna `fft_file` de points.csv.
- session.json: se quitaron las rutas locales, las IP, la copia de la configuración interna del software y el
  historial de renombrado y de conversión de z (las z ya están en mm reales). Lista exacta: `DROP_*` en
  `build_package.py`.
- Normales de las tablas `*_RSS.csv`: α0 = 66.5° (calibrado en el paper) y la inclinación del adaptador
  (`pd_tilt_deg`).
- El README no menciona el subconjunto de D1 usado para la calibración.
- Si cambia la selección de datos: `python build_package.py --force` (rehace los ZIP, 1-2 min) y volver a verificar.
