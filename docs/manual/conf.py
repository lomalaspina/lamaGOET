"""Sphinx configuration for the lamaGOET manual."""

from __future__ import annotations

from datetime import date
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def revision() -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unversioned"


project = "lamaGOET"
author = "Lorraine A. Malaspina and contributors"
copyright = f"{date.today().year}, {author}"
release = revision()
version = release

extensions = [
    "myst_parser",
    "sphinx.ext.autosectionlabel",
    "sphinx.ext.mathjax",
    "sphinx_copybutton",
    "sphinx_design",
]

source_suffix = {".md": "markdown"}
master_doc = "index"
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]
templates_path = ["_templates"]
autosectionlabel_prefix_document = True

myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "dollarmath",
    "fieldlist",
    "substitution",
]
myst_heading_anchors = 4

html_theme = "furo"
html_title = "lamaGOET manual"
html_short_title = "lamaGOET manual"
html_logo = str(ROOT / "llama.png")
html_favicon = str(ROOT / "Tonto_logo.png")
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_theme_options = {
    "light_css_variables": {
        "color-brand-primary": "#174f74",
        "color-brand-content": "#176d78",
        "color-admonition-background": "#f3f8fa",
    },
    "dark_css_variables": {
        "color-brand-primary": "#79c5e8",
        "color-brand-content": "#71d0cf",
    },
    "source_repository": "https://github.com/lomalaspina/lamaGOET/",
    "source_branch": "cleanup",
    "source_directory": "docs/manual/",
}

latex_engine = "xelatex"
latex_documents = [
    (
        master_doc,
        "lamaGOET-Scientific-Manual.tex",
        "lamaGOET Scientific Manual",
        author,
        "manual",
    )
]
latex_logo = str(ROOT / "llama.png")
latex_show_urls = "footnote"
latex_elements = {
    "papersize": "a4paper",
    "pointsize": "10pt",
    "fontpkg": r"""
\setmainfont{DejaVu Serif}
\setsansfont{DejaVu Sans}
\setmonofont{DejaVu Sans Mono}
""",
    "preamble": r"""
\usepackage{microtype}
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{xcolor}
\usepackage{etoolbox}
\AtBeginEnvironment{tabulary}{\small}
\AtBeginEnvironment{longtable}{\small}
\definecolor{lamagoetblue}{HTML}{174F74}
\definecolor{lamagoetteal}{HTML}{176D78}
\hypersetup{colorlinks=true,linkcolor=lamagoetblue,urlcolor=lamagoetteal,citecolor=lamagoetblue}
% Configuration keys are intentionally written verbatim in the reference
% tables.  Permit a line break after an underscore or hyphen so that long
% identifiers remain inside their cells without altering the visible spelling.
\newcommand{\lamagoetbreakableunderscore}{\char95\allowbreak}
\newcommand{\lamagoetbreakablehyphen}{-\allowbreak}
\AtBeginDocument{%
  \protected\def\sphinxcode#1{{%
    \let\_\lamagoetbreakableunderscore
    \let\sphinxhyphenininlineliteral\lamagoetbreakablehyphen
    \texttt{#1}%
  }}%
}
""" + "\n\\newcommand{\\lamagoetrevision}{" + release + "}\n",
    "sphinxsetup": "verbatimwithframe=false,VerbatimColor={rgb}{0.96,0.97,0.98}",
    "maketitle": r"""
\begin{titlepage}
\centering
\vspace*{2cm}
\sphinxlogo
\vspace{1.2cm}
{\sffamily\bfseries\Huge\color{lamagoetblue} lamaGOET\\[0.35cm]}
{\sffamily\Large Scientific Manual}\\[1.1cm]
{\large Hirshfeld atom refinement, periodic electron densities,\\
X-ray constrained wavefunctions, and Tonto workflows}\\[2cm]
{\large Lorraine A. Malaspina and contributors}\\[0.5cm]
{\small Manual revision \lamagoetrevision}\\[0.25cm]
{\small \today}
\vfill
{\small Generated from the same source as the searchable online manual.}
\end{titlepage}
""",
}

nitpicky = True
suppress_warnings = ["myst.header"]
