"""Render the LaTeX equations used in the slides to transparent PNGs (pdflatex + PyMuPDF)."""
import os, subprocess, tempfile, shutil
import fitz

OUT = os.path.join(os.path.dirname(__file__), "..", "figures", "eq")
os.makedirs(OUT, exist_ok=True)

COLOR = "1F3F7A"
EQS = {
    "eq_rss": r"\mu_i \;=\; \underbrace{\frac{C\,\cos\psi}{d^{2}}}_{\eta}\,\big(\mathbf{n}_{t,i}^{\top}\mathbf{n}_d\big)^{m},\qquad i=1,\dots,K",
    "eq_ratio": r"\Big(\frac{\mu_a}{\mu_b}\Big)^{1/m}\!=\frac{\mathbf{n}_{t,a}^{\top}\mathbf{n}_d}{\mathbf{n}_{t,b}^{\top}\mathbf{n}_d}"
                r"\;\Longrightarrow\;\big(\mathbf{n}_{t,a}-\rho_{ab}\,\mathbf{n}_{t,b}\big)^{\top}\mathbf{n}_d=0",
    "eq_dir": r"\hat{\mathbf{n}}_d=\arg\min_{\|\mathbf{n}\|=1}\;\mathbf{n}^{\top}\mathbf{B}^{\top}\mathbf{B}\,\mathbf{n}\quad(\text{eigenvector: GLS / WLS; or NLS})",
    "eq_range": r"\hat{\eta}=\frac{\sum_i \mu_i\,\hat Q_i^{m}}{\sum_i \hat Q_i^{2m}},\qquad \hat d=\sqrt{\frac{C\,\cos\hat\psi}{\hat\eta}},\qquad \hat{\mathbf r}=\mathbf t+\hat d\,\hat{\mathbf n}_d",
}

TEX = r"""\documentclass[border=2pt]{standalone}
\usepackage{amsmath,amssymb,bm}
\usepackage{xcolor}
\usepackage[T1]{fontenc}
\begin{document}
\color[HTML]{%s}
$\displaystyle %s$
\end{document}
"""

tmp = tempfile.mkdtemp()
try:
    for name, eq in EQS.items():
        tex = os.path.join(tmp, name + ".tex")
        with open(tex, "w", encoding="utf-8") as f:
            f.write(TEX % (COLOR, eq))
        r = subprocess.run(["pdflatex", "-interaction=nonstopmode", "-halt-on-error", name + ".tex"],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout[-2000:])
            raise SystemExit(f"LaTeX failed for {name}")
        doc = fitz.open(os.path.join(tmp, name + ".pdf"))
        pix = doc[0].get_pixmap(dpi=600, alpha=True)
        pix.save(os.path.join(OUT, name + ".png"))
        print(name, pix.width, pix.height)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
