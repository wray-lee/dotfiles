% Discussion document in Ogawa Lab (replaces "discussion model.docx"). Build with XeLaTeX.
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{discussion}[2026/11/16 Ogawa Lab discussion document]
\LoadClass[11pt,a4paper]{article}

\RequirePackage{fontspec}
\RequirePackage{xeCJK}
\RequirePackage[top=3.5cm,bottom=3cm,left=2.25cm,right=2.25cm]{geometry} % table was 16.48 cm wide, centered
\RequirePackage[dvipsnames]{xcolor}
\RequirePackage{enumitem,graphicx,array,booktabs,tcolorbox}
\tcbuselibrary{skins,breakable}

% Word template: Times New Roman body, Gungsuh for the fixed headings. Fallbacks keep Linux builds working.
\IfFontExistsTF{Times New Roman}{\setmainfont{Times New Roman}}{\setmainfont{TeX Gyre Termes}}
\IfFontExistsTF{Gungsuh}{\setCJKmainfont{Gungsuh}}{%
  \IfFontExistsTF{MS Mincho}{\setCJKmainfont{MS Mincho}}{\setCJKmainfont{Noto Serif CJK JP}}}

\pagestyle{empty}
\setlength{\parindent}{0pt}
\setlength{\parskip}{3pt}
\setlist{leftmargin=1.27cm,itemsep=0pt,topsep=0pt,parsep=0pt}
\setlength{\tabcolsep}{5.4pt}

% Red guidance text from the Word template. Delete the \hint lines once you have filled a section.
\newcommand{\hint}[1]{{\color{red}#1}}

% Box with the Word table's 0.5 pt grid; height follows content, stacked boxes share one border and may split across pages.
\newtcolorbox{discrow}{enhanced jigsaw,breakable,sharp corners,boxrule=.4pt,
  colframe=black,colback=white,boxsep=0pt,left=5.4pt,right=5.4pt,top=2pt,bottom=2pt,
  before skip=0pt,after skip=-.4pt}

% Title, Date and Name rows (a plain table: fixed two-column grid).
\newcommand{\discheader}[2]{%
  \noindent\begin{tabular}{|p{\dimexpr.25\linewidth-2\tabcolsep-1.5\arrayrulewidth}|%
                            p{\dimexpr.75\linewidth-2\tabcolsep-1.5\arrayrulewidth}|}
    \hline
    \multicolumn{2}{|c|}{\rule[-.7cm]{0pt}{1.43cm}\fontsize{18}{22}\selectfont Discussion document in Ogawa Lab}\\
    \hline
    １．Date & \rule[-.3cm]{0pt}{.67cm}#1\\
    \hline
    ２．Name & \rule[-.3cm]{0pt}{.67cm}#2\\
    \hline
  \end{tabular}\par\nointerlineskip}

\newenvironment{theme}{\begin{discrow}\noindent ３．Research theme（briefly）\par}{\end{discrow}}
\newenvironment{progress}{\begin{discrow}\noindent
  ４．Progress from previous report（Match bullets with \underline{the page \# of Lab Note}）\par}{\end{discrow}}
\newenvironment{problems}{\begin{discrow}\noindent ５．Problems in conducting research\par}{\end{discrow}}
\newenvironment{purchase}{\begin{discrow}\noindent
  ６．Items to purchase（Specifications, number, and estimated expense）\par}{\end{discrow}}
\newenvironment{plan}{\begin{discrow}\noindent
  ７．Research plan for the next week（What to do? By when?）\par}{\end{discrow}}
\newenvironment{materials}{\begin{discrow}\noindent
  ８．Attached materials（Data，Figures，manuscripts etc.）\par}{\end{discrow}}

\newcommand{\discfooter}{\par\nointerlineskip\vskip 3pt
  \hfill{\footnotesize ＊Prepare the number of copies this document for the number of participants in the discussion.}}
