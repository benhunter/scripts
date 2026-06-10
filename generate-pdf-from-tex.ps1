[CmdletBinding()]
param(
    [Parameter()]
    [string]$InputFile = "week_8.tex",

    [Parameter()]
    [string]$OutputDirectory = "latex-output",

    [Parameter()]
    [switch]$AllowShellEscape,

    [Parameter()]
    [string]$Image = $env:TEXLIVE_IMAGE
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Image) -or $Image -notmatch '@sha256:[0-9a-fA-F]{64}$') {
    throw "Set -Image or TEXLIVE_IMAGE to a TeX Live image pinned by sha256 digest."
}

$inputPath = (Resolve-Path -LiteralPath $InputFile).Path
if ([System.IO.Path]::GetExtension($inputPath) -ne ".tex") {
    throw "InputFile must be a .tex file."
}

$sourceDirectory = Split-Path -Parent $inputPath
$inputName = Split-Path -Leaf $inputPath
$outputPath = [System.IO.Path]::GetFullPath((Join-Path $PWD $OutputDirectory))
[System.IO.Directory]::CreateDirectory($outputPath) | Out-Null

$pdflatexArgs = @("-interaction=nonstopmode", "-halt-on-error", "-output-directory=/output")
if ($AllowShellEscape) {
    Write-Warning "Shell escape allows the TeX document to execute commands inside the container."
    $pdflatexArgs += "-shell-escape"
}
else {
    $pdflatexArgs += "-no-shell-escape"
}
$pdflatexArgs += $inputName

docker run --rm `
    --network none `
    --read-only `
    --tmpfs /tmp:rw,noexec,nosuid,size=256m `
    --mount "type=bind,source=$sourceDirectory,target=/input,readonly" `
    --mount "type=bind,source=$outputPath,target=/output" `
    --workdir /input `
    $Image pdflatex @pdflatexArgs
