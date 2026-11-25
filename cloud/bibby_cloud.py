#!/usr/bin/env python3
"""bibby_cloud - LaTeX in Colab, Kaggle, SageMaker or any notebook VM.

One cell, in any notebook:

    !curl -fsSL https://raw.githubusercontent.com/trybibby/bibby-latex/main/cloud/bibby_cloud.py | python3 - --profile standard

Then, in Python:

    import bibby_cloud
    bibby_cloud.compile_and_show("main.tex")

Profiles
  minimal   ~250 MB  latex-base + recommended, enough for a clean article
  standard  ~900 MB  + latex-extra, fonts, science, biber  (recommended)
  full      ~4 GB    texlive-full, every class and font
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap

APT_PACKAGES = {
    "minimal": [
        "texlive-latex-base",
        "texlive-latex-recommended",
        "latexmk",
    ],
    "standard": [
        "texlive-latex-base",
        "texlive-latex-recommended",
        "texlive-latex-extra",
        "texlive-fonts-recommended",
        "texlive-science",
        "texlive-bibtex-extra",
        "latexmk",
        "biber",
        "dvipng",
        "cm-super",
    ],
    "full": ["texlive-full", "latexmk", "biber"],
}

MARKER = "/tmp/.bibby_latex_installed"
SELF_URL = (
    "https://raw.githubusercontent.com/trybibby/bibby-latex/main/cloud/bibby_cloud.py"
)


# ------------------------------------------------------------------ helpers --
def environment() -> str:
    if "google.colab" in sys.modules or os.path.isdir("/content"):
        return "colab"
    if os.path.isdir("/kaggle") or os.environ.get("KAGGLE_KERNEL_RUN_TYPE"):
        return "kaggle"
    if os.environ.get("SM_CURRENT_HOST"):
        return "sagemaker"
    return "notebook"


def _run(cmd: list[str], quiet: bool = True) -> int:
    kwargs = {}
    if quiet:
        kwargs["stdout"] = subprocess.DEVNULL
        kwargs["stderr"] = subprocess.STDOUT
    return subprocess.call(cmd, **kwargs)


def _sudo(cmd: list[str]) -> list[str]:
    if os.geteuid() == 0:
        return cmd
    if shutil.which("sudo"):
        return ["sudo", "-n", *cmd]
    return cmd


def has_tex() -> bool:
    return shutil.which("pdflatex") is not None


def _has_internet() -> bool:
    import socket

    try:
        socket.create_connection(("deb.debian.org", 80), timeout=4).close()
        return True
    except OSError:
        try:
            socket.create_connection(("archive.ubuntu.com", 80), timeout=4).close()
            return True
        except OSError:
            return False


# -------------------------------------------------------------------- setup --
def install(profile: str = "standard", force: bool = False) -> bool:
    """Install TeX in the notebook VM. Returns True when pdflatex works."""
    env = environment()
    print(f"bibby-latex  env={env}  profile={profile}")

    if has_tex() and not force:
        print("  pdflatex already available, nothing to do")
        _write_helpers()
        return True

    if env == "kaggle" and not _has_internet():
        print(
            "  this Kaggle notebook has internet turned off.\n"
            "  Notebook sidebar > Settings > Internet > On, then re-run this cell."
        )
        return False

    packages = APT_PACKAGES.get(profile, APT_PACKAGES["standard"])

    if not shutil.which("apt-get"):
        print("  no apt-get here, falling back to TinyTeX")
        return _install_tinytex()

    print(f"  apt-get install {len(packages)} packages, this takes 1-3 minutes")
    env_vars = dict(os.environ, DEBIAN_FRONTEND="noninteractive")
    subprocess.call(
        _sudo(["apt-get", "-qq", "update"]),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
        env=env_vars,
    )
    rc = subprocess.call(
        _sudo(["apt-get", "-qq", "-y", "--no-install-recommends", "install", *packages]),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
        env=env_vars,
    )

    if rc != 0 or not has_tex():
        print("  apt failed, falling back to TinyTeX")
        if not _install_tinytex():
            return False

    open(MARKER, "w").close()
    _write_helpers()
    print(f"  done. pdflatex -> {shutil.which('pdflatex')}")
    print('  compile with:  !latexmk -pdf -interaction=nonstopmode main.tex')
    return True


def _install_tinytex() -> bool:
    script = "https://yihui.org/tinytex/install-bin-unix.sh"
    rc = _run(["bash", "-c", f"curl -fsSL {script} | sh"])
    home = os.path.expanduser("~")
    for root in (f"{home}/.TinyTeX/bin", f"{home}/bin"):
        if os.path.isdir(root):
            for sub in os.listdir(root):
                path = os.path.join(root, sub)
                if os.path.isdir(path):
                    os.environ["PATH"] = path + os.pathsep + os.environ["PATH"]
    return rc == 0 and has_tex()


def _write_helpers() -> None:
    """Make `import bibby_cloud` work after a `curl ... | python3 -` run."""
    target = os.path.join(os.getcwd(), "bibby_cloud.py")
    if os.path.exists(target):
        return
    source = globals().get("_SELF_SOURCE") or ""
    if not source:
        try:
            import urllib.request

            with urllib.request.urlopen(SELF_URL, timeout=15) as resp:
                source = resp.read().decode("utf-8")
        except Exception:
            return
    try:
        with open(target, "w", encoding="utf-8") as fh:
            fh.write(source)
        print("  wrote ./bibby_cloud.py  (import bibby_cloud to compile + preview)")
    except OSError:
        pass


# ------------------------------------------------------------------ compile --
def compile_tex(
    path: str = "main.tex",
    engine: str = "pdflatex",
    outdir: str = "build",
    quiet: bool = True,
) -> str | None:
    """Compile a .tex file and return the path to the PDF, or None."""
    if not os.path.exists(path):
        print(f"bibby-latex: {path} not found")
        return None
    os.makedirs(outdir, exist_ok=True)

    flag = {"pdflatex": "-pdf", "xelatex": "-xelatex", "lualatex": "-lualatex"}.get(engine, "-pdf")
    cmd = [
        "latexmk", flag, "-interaction=nonstopmode", "-file-line-error",
        "-synctex=1", f"-outdir={outdir}", path,
    ]
    if not shutil.which("latexmk"):
        cmd = [engine, "-interaction=nonstopmode", "-file-line-error",
               f"-output-directory={outdir}", path]

    proc = subprocess.run(cmd, capture_output=True, text=True)
    pdf = os.path.join(outdir, os.path.splitext(os.path.basename(path))[0] + ".pdf")

    if os.path.exists(pdf):
        return pdf

    print("bibby-latex: compile failed\n")
    log = os.path.join(outdir, os.path.splitext(os.path.basename(path))[0] + ".log")
    text = ""
    if os.path.exists(log):
        text = open(log, encoding="utf-8", errors="replace").read()
    text = text or proc.stdout + proc.stderr
    for line in text.splitlines():
        if line.startswith("!") or ":" in line[:40] and "Error" in line:
            print(" ", line)
    if quiet:
        print("\n  full log:", log)
    return None


def show_pdf(pdf: str, width: int = 820, height: int = 1000):
    """Render a PDF inline in the notebook."""
    import base64
    from IPython.display import HTML, display

    data = base64.b64encode(open(pdf, "rb").read()).decode()
    display(
        HTML(
            f'<iframe src="data:application/pdf;base64,{data}" '
            f'width="{width}" height="{height}" style="border:1px solid #d8d4cc"></iframe>'
        )
    )


def show_page(pdf: str, page: int = 0, dpi: int = 150):
    """Render one page as an image. Needs pdf2image + poppler, falls back to pdftoppm."""
    from IPython.display import Image, display

    out = "/tmp/bibby_page"
    subprocess.run(
        ["pdftoppm", "-png", "-r", str(dpi), "-f", str(page + 1), "-l", str(page + 1), pdf, out],
        capture_output=True,
    )
    for suffix in (f"-{page + 1}.png", f"-0{page + 1}.png", ".png"):
        if os.path.exists(out + suffix):
            display(Image(out + suffix))
            return
    print("bibby-latex: could not rasterise, use show_pdf() instead")


def compile_and_show(path: str = "main.tex", engine: str = "pdflatex", **kw):
    pdf = compile_tex(path, engine=engine)
    if pdf:
        show_pdf(pdf, **kw)
    return pdf


def write_tex(path: str, body: str) -> str:
    """Write a .tex file from a Python string, dedented."""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(textwrap.dedent(body).lstrip())
    return path


# --------------------------------------------------------------------- main --
_SELF_SOURCE = ""
try:
    with open(__file__, encoding="utf-8") as _fh:
        _SELF_SOURCE = _fh.read()
except (NameError, OSError):
    pass


def _cli(argv: list[str]) -> int:
    profile = "standard"
    force = False
    for i, arg in enumerate(argv):
        if arg in ("--profile", "-p") and i + 1 < len(argv):
            profile = argv[i + 1]
        elif arg.startswith("--profile="):
            profile = arg.split("=", 1)[1]
        elif arg == "--force":
            force = True
        elif arg in ("-h", "--help"):
            print(__doc__)
            return 0
    return 0 if install(profile, force) else 1


if __name__ == "__main__":
    raise SystemExit(_cli(sys.argv[1:]))
