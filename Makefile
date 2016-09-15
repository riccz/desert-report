NAME=desert-report
TEXSRCS=introduction.tex single-hop.tex multi-hop.tex conclusions.tex
BIBTEXSRCS=desert-report.bib

USE_PDFLATEX=1
VIEWPDF=xdg-open
VIEWPDF_FLAGS=
VIEWPDF_LANDSCAPE_FLAGS=

include /usr/share/latex-mk/latex.gmk
