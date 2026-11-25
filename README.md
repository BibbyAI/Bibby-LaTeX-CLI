# bibby-latex

One command. Working LaTeX, on your machine, in VS Code, and in a Colab or Kaggle notebook.

Read the documentation at [trybibby.com/documentation/bibby-latex](https://trybibby.com/documentation/bibby-latex).

```bash
curl -fsSL https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/install.sh | bash
```

It asks a few questions. Every one has a default, so you can hold Enter. Or skip them:

```bash
curl -fsSL https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/install.sh | bash -s -- --yes --profile=standard
```

| | |
| --- | --- |
| Windows | `irm https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/windows/install.ps1 \| iex` |
| Node already installed | `npx bibby-latex` |

When it finishes, `pdflatex` and `latexmk` are on your PATH, a real document has been compiled as a check, and saving a `.tex` file in VS Code builds the PDF into a tab. Open a new terminal first (or `source` the rc file it names) so the shell sees TeX.

```bash
latexmk -pdf main.tex
```

## Pick a profile

The default is **standard**.

| profile | disk | use it when |
| --- | --- | --- |
| `minimal` | ~200 MB | a short article, and you are fine with packages downloading the first time you use them |
| `standard` | ~1.2 GB | a thesis or a paper |
| `full` | ~2.5 GB | a paper that has to use someone else's class file |

Those sizes are the TinyTeX install, which is the default. A distro `texlive-full`, Colab's `texlive-full`, or Windows MiKTeX `scheme-full` lands around 4–5 GB.

**minimal** is TinyTeX plus `latexmk`, `xcolor`, `geometry`, `hyperref`, `booktabs`, and `enumitem`.

**standard** adds the set people discover they need halfway through a draft: AMS, the recommended font and LaTeX collections, `biblatex` and `biber`, `natbib`, `siunitx`, `cleveref`, `microtype`, `tikz` and `pgfplots`, `listings` and `minted`, `caption`, algorithms, and the usual table packages.

**full** adds the class files that fail at the deadline: `acmart`, `IEEEtran`, `llncs`, `revtex`, `elsarticle`, `achemso`, and `apa7`.

On Colab and Kaggle the same three names install apt packages instead. Sizes there are about 250 MB, 900 MB, and 4 GB.

## What a run does

1. Detects your OS, distro, any TeX already installed, and whether `code` is on PATH.
2. Asks how much TeX you want, which distribution, whether to set up VS Code, whether to set up notebooks, and whether to drop a starter project here.
3. Installs the distribution. TinyTeX goes in your home directory and does not need sudo. The other choices are MacTeX (Homebrew, no GUI apps), your distro's TeX Live, or MiKTeX on Windows.
4. Installs that profile's packages with `tlmgr`. A distro-managed TeX Live is left to the distro packages.
5. Adds the TeX bin directory to your shell rc, in a block marked `# bibby-latex: TeX PATH`. That is `~/.zshrc`, `~/.bashrc`, `~/.bash_profile` on macOS bash, or fish.
6. Installs [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop) and `trybibby.bibby-latex`, then merges settings into VS Code's `settings.json`. Keys you already set stay put. A copy is saved beside it as `settings.json.bibby-backup`.
7. Writes the Colab and Kaggle helper into the current directory and copies the notebook one-liner to the clipboard.
8. Compiles a throwaway document with math, a table, and `hyperref`. If that PDF appears, the install is good.

`--yes` takes the defaults: **standard**, TinyTeX (or the TeX already on the machine), VS Code on, notebooks on, no starter project, no spell-check extras.

If `pdflatex` is already installed, bibby keeps it. It will still offer to refresh packages and still do the editor and notebook setup. It does not swap a working TeX Live or MacTeX for TinyTeX.

## Starter project

Off by default. Turn it on when you want a directory you can compile immediately:

```bash
bibby-latex --scaffold
bibby-latex --scaffold=~/thesis
```

Files are created only when they are missing.

| file | what it is |
| --- | --- |
| `main.tex` | a one-page article that already compiles: math, a booktabs table, `cleveref` |
| `.latexmkrc` | PDF mode, output in `build/`, biber when a `.bcf` shows up, SyncTeX on |
| `.gitignore` | `build/` and the usual aux files |
| `.vscode/settings.json` | the same LaTeX Workshop settings, scoped to this project |

## VS Code

Save a `.tex` file. `latexmk` runs, the PDF lands in `build/`, and it opens in a tab. SyncTeX is on, so you can jump between the source and the page. Recipes for pdflatex, xelatex, and lualatex are installed; the last one you used stays selected.

```bash
bibby-latex --vscode-only       # extensions and settings, nothing else
bibby-latex --extras            # also LTeX, Code Spell Checker, and LaTeX Utilities
bibby-latex --force-settings    # bibby's keys win where they overlap yours
bibby-latex --no-vscode         # skip the editor
```

If `code` is not on PATH, open the Command Palette, run **Shell Command: Install 'code' command in PATH**, then:

```bash
bibby-latex --vscode-only
```

The companion extension, `trybibby.bibby-latex`, adds a status-bar TeX indicator, install from inside the editor, auto-install of a missing package when a build fails on a `.sty`, and build errors as diagnostics instead of a wall of log.

## Colab and Kaggle

Paste this into the first cell:

```python
!curl -fsSL https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/cloud/bibby_cloud.py | python3 - --profile standard
```

Then:

```python
import bibby_cloud

bibby_cloud.write_tex("main.tex", r"""
\documentclass{article}
\begin{document}
Hello from the notebook.
\end{document}
""")

bibby_cloud.compile_and_show("main.tex")
bibby_cloud.compile_and_show("main.tex", engine="lualatex")
```

`compile_and_show` runs `latexmk`, writes `build/main.pdf`, and renders it inline. `compile_tex` returns that path, or prints the error lines from the log. `show_page` rasterises a single page with `pdftoppm`.

On Kaggle, turn internet on before the first cell: notebook sidebar, Settings, Internet, On. If it is off, the cell says so and stops.

Ready-made notebooks live at [`cloud/colab_bibby.ipynb`](cloud/colab_bibby.ipynb) and [`cloud/kaggle_bibby.ipynb`](cloud/kaggle_bibby.ipynb). A normal install copies those, plus `bibby_cloud.py`, into the current directory. `--cloud-only` does just that part.

The same helper works in any notebook VM with `apt-get`. With no apt, it falls back to TinyTeX. Pass `--force` to reinstall even when `pdflatex` is already there.

## Options

macOS, Linux, and WSL. Flags go after `--` when you pipe the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/BibbyAI/Bibby-LaTeX-CLI/main/install.sh | bash -s -- --yes --profile=full --scaffold
```

```
-y, --yes               accept every default, no questions
    --profile=NAME      minimal | standard | full
    --backend=NAME      tinytex | system | mactex
    --no-vscode         skip the VS Code setup
    --extras            also install spell check and grammar extensions
    --cloud             write the Colab and Kaggle files here
    --scaffold[=DIR]    create main.tex, .latexmkrc, .vscode in DIR (default: .)
    --force-settings    overwrite conflicting VS Code settings
    --vscode-only       only the VS Code part
    --cloud-only        only the cloud files and the one-liner
    --doctor            diagnose an existing install and test-compile
    --uninstall         remove TinyTeX and the PATH line bibby added
-v, --verbose           print every command
-V, --version
-h, --help
```

`tinytex` is the default. `system` uses apt, dnf, pacman, zypper, or apk, and needs sudo. On openSUSE and Alpine that backend installs one fixed TeX Live set. `mactex` is `brew install --cask mactex-no-gui`, and falls back to TinyTeX when Homebrew is missing.

Windows uses PowerShell parameters:

```powershell
.\install.ps1 -Yes -Profile standard -Backend miktex
```

```
-Yes                         accept every default
-Profile  minimal|standard|full
-Backend  tinytex|miktex|texlive
-NoVSCode
-Extras
-Doctor
-Scaffold
```

MiKTeX is the Windows default, installed with winget or Chocolatey, with on-the-fly package install turned on. TinyTeX is the option that does not need an admin account. `full` there is MiKTeX `scheme-full`.

## Something broke

```bash
bibby-latex --doctor
```

Doctor prints which TeX it found and where, checks `pdflatex` and `latexmk`, notes whether `xelatex`, `lualatex`, `biber`, `bibtex`, and `tlmgr` are present, checks that LaTeX Workshop is installed, then compiles a small document. A clean doctor means the toolchain is fine and the error is in the document.

- **`pdflatex: command not found` right after a successful install.** This terminal was already open. Open a new one, or `source` the rc file the installer printed.
- **`! LaTeX Error: File 'something.sty' not found`.** On TinyTeX or MiKTeX, `tlmgr install something`. MiKTeX also fetches it on the next compile. On a distro TeX Live, install the distro package. `tlmgr` will refuse to touch a tree that apt or dnf owns.
- **VS Code saves and nothing builds.** `code` was not on PATH during install. Add the shell command, then run `bibby-latex --vscode-only`.
- **A setting you liked got overwritten.** You passed `--force-settings`. Restore `settings.json.bibby-backup`, which sits next to `settings.json`.
- **Kaggle cell fails immediately.** Internet is off. Turn it on and run the cell again.

## What it changes

| it writes | it leaves alone |
| --- | --- |
| `~/.TinyTeX` or `~/Library/TinyTeX` | a TeX install it found already |
| one marked block in your shell rc | every other line in that file |
| VS Code `settings.json`, after saving `settings.json.bibby-backup` | keys you already had, unless `--force-settings` |
| `main.tex` and the scaffold, only if those files are absent | an existing project |
| `~/.bibby-latex/` with a copy of the scripts, on a remote install | your editor extensions, on uninstall |

TinyTeX never asks for sudo. MacTeX and distro TeX Live go through Homebrew or the system package manager, which do.

## Uninstall

```bash
bibby-latex --uninstall
```

Removes `~/.TinyTeX`, `~/Library/TinyTeX`, and the `# bibby-latex: TeX PATH` block. Extensions and `settings.json` stay. MacTeX and distro TeX Live stay too. Uninstall those with Homebrew or the distro.

## Supported

macOS on Intel and Apple silicon. Debian, Ubuntu, Mint, Pop. Fedora, RHEL, Rocky, Alma. Arch, Manjaro, EndeavourOS. openSUSE. Alpine. WSL. Windows 10 and 11.

A remote install needs `curl` (or `wget`) and `tar`. TeX itself needs `perl`. The installer fetches missing prerequisites with your package manager when it can.

## From a checkout

```bash
make install     # run the installer from this tree
make doctor
make test        # syntax check plus the smoke test
make lint        # shellcheck
make uninstall
```

`npx bibby-latex` needs Node 16 or newer. It does not reimplement the installer. On macOS and Linux it execs the shell script, and on Windows it execs `windows/install.ps1`, with the prompts still attached to your terminal.

Documentation: [trybibby.com/documentation/bibby-latex](https://trybibby.com/documentation/bibby-latex).
Issues: [github.com/BibbyAI/Bibby-LaTeX-CLI](https://github.com/BibbyAI/Bibby-LaTeX-CLI).

## License

[MIT](LICENSE)
