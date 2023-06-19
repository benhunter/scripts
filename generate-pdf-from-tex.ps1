docker run -i --rm --name latex -v ${PWD}:/usr/src/app -w /usr/src/app texlive/texlive:latest pdflatex -shell-escape week_8.tex
# Example .tex in mcso-ala-matlab/week_8/week_8.tex
# ${PWD} for powershell, $PWD for bash 
