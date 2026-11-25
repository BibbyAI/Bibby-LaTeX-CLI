<#
.SYNOPSIS
  bibby-latex for Windows. One command, working LaTeX + VS Code.

.EXAMPLE
  irm https://raw.githubusercontent.com/trybibby/bibby-latex/main/windows/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -Yes -Profile standard
#>
[CmdletBinding()]
param(
  [ValidateSet('minimal', 'standard', 'full')][string]$Profile = '',
  [ValidateSet('tinytex', 'miktex', 'texlive')][string]$Backend = '',
  [switch]$Yes,
  [switch]$NoVSCode,
  [switch]$Extras,
  [switch]$Doctor,
  [switch]$Scaffold
)

$ErrorActionPreference = 'Stop'
$BibbyVersion = '1.0.0'

# ------------------------------------------------------------------- output --
function Write-Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor White }
function Write-Ok($m)   { Write-Host "    ok   $m" -ForegroundColor Green }
function Write-Skip($m) { Write-Host "    --   $m" -ForegroundColor DarkGray }
function Write-Warn($m) { Write-Host "    warn $m" -ForegroundColor Yellow }
function Write-Fail($m) { Write-Host "    fail $m" -ForegroundColor Red }
function Write-Say($m)  { Write-Host "    $m" }

function Ask-YesNo($q, $def = 'y') {
  if ($Yes) { return $def -eq 'y' }
  $hint = if ($def -eq 'y') { '[Y/n]' } else { '[y/N]' }
  while ($true) {
    $a = Read-Host "    $q $hint"
    if ([string]::IsNullOrWhiteSpace($a)) { $a = $def }
    switch -Regex ($a) { '^[yY]' { return $true }; '^[nN]' { return $false } }
  }
}

function Ask-Choice($q, $def, [string[]]$opts) {
  if ($Yes) { return $def }
  Write-Host ""; Write-Host "    $q" -ForegroundColor White
  for ($i = 0; $i -lt $opts.Count; $i++) { Write-Host "      $($i+1)) $($opts[$i])" }
  while ($true) {
    $a = Read-Host "    choice [$def]"
    if ([string]::IsNullOrWhiteSpace($a)) { return $def }
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $opts.Count) { return [int]$a }
  }
}

function Has($cmd) { $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host ""
Write-Host "  bibby-latex" -ForegroundColor White -NoNewline
Write-Host "  v$BibbyVersion" -ForegroundColor DarkGray
Write-Host "  LaTeX that just works. Local, VS Code, Colab, Kaggle." -ForegroundColor DarkGray
Write-Host ""

# ------------------------------------------------------------------ detect ---
function Get-TexKind {
  if (Has 'pdflatex') {
    $v = (& pdflatex --version 2>$null | Select-Object -First 1)
    if ($v -match 'MiKTeX') { return 'miktex' }
    if ((Get-Command pdflatex).Source -match 'TinyTeX') { return 'tinytex' }
    return 'texlive'
  }
  foreach ($p in @("$env:APPDATA\TinyTeX\bin\windows\pdflatex.exe",
                   "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64\pdflatex.exe")) {
    if (Test-Path $p) {
      $env:PATH = (Split-Path $p) + ';' + $env:PATH
      if ($p -match 'TinyTeX') { return 'tinytex' }
      return 'miktex'
    }
  }
  return 'none'
}

function Get-CodeCli {
  foreach ($c in @('code', 'code-insiders', 'cursor', 'codium')) { if (Has $c) { return $c } }
  return $null
}

$texKind = Get-TexKind
$codeCli = Get-CodeCli
$hasWinget = Has 'winget'
$hasChoco = Has 'choco'

Write-Step "Looking around"
Write-Say "system   $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Say "tex      $texKind"
Write-Say "editor   $(if ($codeCli) { $codeCli } else { 'no code command on PATH' })"
Write-Say "pkgmgr   $(if ($hasWinget) { 'winget' } elseif ($hasChoco) { 'choco' } else { 'none' })"

# ------------------------------------------------------------------ doctor ---
function Invoke-Doctor {
  Write-Step "Doctor"
  $fail = 0
  foreach ($c in @('pdflatex', 'xelatex', 'lualatex', 'latexmk', 'biber', 'bibtex')) {
    if (Has $c) { Write-Ok $c } else { Write-Fail "$c not found"; $fail++ }
  }
  if ($codeCli) {
    $exts = & $codeCli --list-extensions 2>$null
    if ($exts -contains 'james-yu.latex-workshop') { Write-Ok 'VS Code extension: LaTeX Workshop' }
    else { Write-Warn 'LaTeX Workshop not installed' }
  }

  $dir = Join-Path $env:TEMP ("bibby-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  @'
\documentclass{article}
\usepackage{amsmath,hyperref,booktabs,xcolor}
\begin{document}
bibby-latex smoke test \( E = mc^2 \)
\end{document}
'@ | Set-Content -Path (Join-Path $dir 'bibby-test.tex') -Encoding UTF8

  Push-Location $dir
  if (Has 'latexmk') { & latexmk -pdf -interaction=nonstopmode bibby-test.tex *> $null }
  else { & pdflatex -interaction=nonstopmode bibby-test.tex *> $null }
  Pop-Location

  if (Test-Path (Join-Path $dir 'bibby-test.pdf')) { Write-Ok 'compiled a test document to PDF' }
  else { Write-Fail 'test compile failed'; $fail++ }
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue

  Write-Host ""
  if ($fail -eq 0) { Write-Host "    everything checks out." -ForegroundColor Green }
  else { Write-Host "    $fail check(s) failed." -ForegroundColor Yellow }
  return $fail
}

if ($Doctor) { exit (Invoke-Doctor) }

# --------------------------------------------------------------- questions ---
if (-not $Profile) {
  $i = Ask-Choice "How much TeX do you want?" 2 @(
    "minimal    ~250 MB   basics only, pulls packages on demand",
    "standard   ~1.2 GB   everything a thesis or paper normally needs (recommended)",
    "full       ~5 GB     every class and font MiKTeX ships")
  $Profile = @('minimal', 'standard', 'full')[$i - 1]
}

if (-not $Backend) {
  if ($texKind -ne 'none') { $Backend = 'existing' }
  else {
    $i = Ask-Choice "Which TeX distribution?" 1 @(
      "MiKTeX     installs missing packages automatically while you write (recommended)",
      "TinyTeX    smaller, user-level, no admin rights needed")
    $Backend = @('miktex', 'tinytex')[$i - 1]
  }
}

$doVSCode = if ($NoVSCode) { $false } else { Ask-YesNo "Set up VS Code (LaTeX Workshop + build-on-save + PDF preview)?" 'y' }
$doScaffold = if ($Scaffold) { $true } else { Ask-YesNo "Create a starter LaTeX project here?" 'n' }

Write-Step "Plan"
Write-Say "profile    $Profile"
Write-Say "backend    $Backend"
Write-Say "vscode     $(if ($doVSCode) { 'yes' } else { 'no' })"
if (-not (Ask-YesNo "Go?" 'y')) { Write-Say "nothing done."; exit 0 }

# ----------------------------------------------------------------- install ---
function Install-MiKTeX {
  Write-Step "Installing MiKTeX"
  if ($hasWinget) {
    & winget install --id MiKTeX.MiKTeX --accept-source-agreements --accept-package-agreements --silent
  } elseif ($hasChoco) {
    & choco install miktex -y
  } else {
    Write-Warn "no winget or choco, download MiKTeX from https://miktex.org/download"
    return $false
  }
  $env:PATH = "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64;$env:PATH"
  # never prompt mid-compile for a missing package
  & initexmf --set-config-value "[MPM]AutoInstall=1" 2>$null
  Write-Ok "MiKTeX installed, auto-install of packages enabled"
  return $true
}

function Install-TinyTeX {
  Write-Step "Installing TinyTeX"
  $tmp = Join-Path $env:TEMP 'install-tinytex.ps1'
  Invoke-WebRequest -Uri 'https://yihui.org/tinytex/install-bin-windows.bat' -OutFile ($tmp + '.bat')
  & cmd /c ($tmp + '.bat')
  $bin = "$env:APPDATA\TinyTeX\bin\windows"
  if (Test-Path $bin) {
    $env:PATH = "$bin;$env:PATH"
    [Environment]::SetEnvironmentVariable('PATH', "$bin;" + [Environment]::GetEnvironmentVariable('PATH', 'User'), 'User')
    Write-Ok "TinyTeX at $bin, added to your user PATH"
    return $true
  }
  Write-Fail "TinyTeX install did not produce $bin"
  return $false
}

switch ($Backend) {
  'miktex'   { if (-not (Install-MiKTeX))  { exit 1 } }
  'tinytex'  { if (-not (Install-TinyTeX)) { exit 1 } }
  'existing' { Write-Skip "using the TeX already installed" }
}

if ($Backend -eq 'tinytex') {
  Write-Step "Installing the $Profile package set"
  $pkgs = switch ($Profile) {
    'minimal'  { @('latexmk', 'xcolor', 'geometry', 'hyperref', 'booktabs') }
    'standard' { @('latexmk', 'collection-fontsrecommended', 'collection-latexrecommended',
                   'amsmath', 'booktabs', 'caption', 'microtype', 'titlesec', 'fancyhdr',
                   'biblatex', 'biber', 'csquotes', 'cleveref', 'siunitx', 'pgfplots',
                   'listings', 'mathtools', 'enumitem', 'subcaption', 'float', 'tabularx') }
    'full'     { @('scheme-full') }
  }
  $n = 0
  foreach ($p in $pkgs) {
    $n++
    Write-Host "`r    .. installing packages $n/$($pkgs.Count)  $p".PadRight(70) -NoNewline
    & tlmgr install $p *> $null
  }
  Write-Host "`r".PadRight(72)
  Write-Ok "$($pkgs.Count) packages processed"
}

# ------------------------------------------------------------------ vscode ---
if ($doVSCode) {
  Write-Step "Setting up VS Code"
  if (-not $codeCli) {
    Write-Warn "no 'code' command. In VS Code: Command Palette > 'Shell Command: Install code command in PATH'"
  } else {
    $exts = @('james-yu.latex-workshop', 'trybibby.bibby-latex')
    if ($Extras) { $exts += @('streetsidesoftware.code-spell-checker', 'valentjn.vscode-ltex') }
    foreach ($e in $exts) {
      & $codeCli --install-extension $e --force *> $null
      Write-Ok "extension $e"
    }
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    $tmplPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\settings.json'
    if ((Test-Path $tmplPath) -and (Has 'python')) {
      $merge = Join-Path (Split-Path $PSScriptRoot -Parent) 'src\lib\merge_settings.py'
      if (-not (Test-Path $settingsPath)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null
        '{}' | Set-Content $settingsPath
      }
      Copy-Item $settingsPath "$settingsPath.bibby-backup" -Force
      & python $merge $settingsPath $tmplPath 0
      Write-Ok "merged LaTeX settings into $settingsPath"
    } else {
      Write-Warn "copy the recommended settings manually from templates\settings.json"
    }
  }
}

# ---------------------------------------------------------------- scaffold ---
if ($doScaffold) {
  Write-Step "Scaffolding a LaTeX project"
  $tmpl = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates'
  foreach ($pair in @(@('main.tex', 'main.tex'), @('latexmkrc', '.latexmkrc'), @('gitignore', '.gitignore'))) {
    $src = Join-Path $tmpl $pair[0]
    if ((Test-Path $src) -and -not (Test-Path $pair[1])) { Copy-Item $src $pair[1] }
  }
  Write-Ok "main.tex, .latexmkrc, .gitignore"
}

$rc = Invoke-Doctor

Write-Step "Done"
Write-Say "open a new terminal so PATH picks up TeX"
Write-Say "compile anything:  latexmk -pdf main.tex"
Write-Say "in VS Code:        open a .tex file and hit Ctrl+S"
Write-Host ""
exit $rc
