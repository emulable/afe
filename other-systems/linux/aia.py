#!/usr/bin/env python3
"""AI Audio on Linux: install, list, start and stop the tools.

STATUS: WRITTEN BUT NEVER RUN ON LINUX. It was written on Windows as a faithful translation of
setup/install.ps1 and the launchers/*.bat files, and only its --dry-run output was checked.
Expect to fix things on the first real run. Each step below says what its Windows original
does, so a language model can repair a step without re-deriving the design. The Windows
installer's opening notes (setup/install.ps1) are the technical manual: read them first.

Start it through ./aia.sh (which fetches uv into the kit and runs this file), for example:
    ./aia.sh list
    ./aia.sh install recommended            (or: all, or keys such as narrate,transcribe)
    ./aia.sh install acestep --with-xl
    ./aia.sh install all --dry-run          (prints every command, runs nothing)
    ./aia.sh start narrate my-document.pdf
    ./aia.sh start comfy
    ./aia.sh stop

What is shared with Windows (do not fork these, read them):
    setup/components.json    the one list of components, panel tools and presets
    setup/locks/             exact package versions per tool + manifest.json (commits, Pythons)
    scripts/*.py             the kit's own tools (narrate, transcribe, hum_to_track ...)
What is Windows-only and replaced here: the installer window, the control panel, the .bat
launchers, portable git/ffmpeg/FluidSynth downloads (use the system's package manager here).

Differences that matter on Linux:
  - git, ffmpeg and fluidsynth come from the system (e.g. sudo apt install git ffmpeg fluidsynth).
    This script never runs sudo; it tells you what is missing.
  - PyTorch on Linux needs the nvidia-* runtime packages that the Windows package lists do not
    contain. So each environment is built in two passes: PyTorch first WITH its dependencies,
    then the rest of the list exactly as pinned (--no-deps), minus Windows-only packages.
  - Keep the kit in a folder WITHOUT spaces on Linux (Applio refuses paths with spaces, and
    there is no drive-letter trick here).
  - An NVIDIA card with its driver is assumed, as on Windows. Without one, only the light
    tools are worth installing.
"""
import argparse, json, os, re, shutil, signal, subprocess, sys, tarfile, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETUP = ROOT / "setup"
LOCKS = SETUP / "locks"
DRY = False

# ---- environment: the same variables scripts/env.bat sets, so nothing lands outside the kit ----
ENV = {
    "AIA_ROOT": str(ROOT),
    "HF_HOME": str(ROOT / "models" / "huggingface"),
    "TORCH_HOME": str(ROOT / "models" / "torch"),
    "UV_PYTHON_INSTALL_DIR": str(ROOT / "python"),
    "UV_CACHE_DIR": str(ROOT / ".cache" / "uv"),
    "UV_PYTHON_PREFERENCE": "only-managed",
    "PIP_CACHE_DIR": str(ROOT / ".cache" / "pip"),
    "XDG_CACHE_HOME": str(ROOT / ".cache"),
    "PYTHONUTF8": "1",
    "PYTHONIOENCODING": "utf-8",
}
os.environ.update(ENV)
os.environ["PATH"] = str(ROOT / "tools" / "_bin") + os.pathsep + os.environ.get("PATH", "")

MANIFEST = json.loads((LOCKS / "manifest.json").read_text(encoding="utf-8"))
REGISTRY = json.loads((SETUP / "components.json").read_text(encoding="utf-8"))
CATALOG = REGISTRY["components"]
KEYS = [c["key"] for c in CATALOG]

# Pinned downloads, the same ones setup/install.ps1 uses (see $Urls and $ModelPins there).
URLS = {
    "sf2": "https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/684543d5e5efaef08d02be50dcda8d552478fa60/GeneralUser-GS.sf2",
    "sf2readme": "https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/684543d5e5efaef08d02be50dcda8d552478fa60/README.md",
    "diarSeg": "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2",
    "diarEmb": "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/nemo_en_titanet_large.onnx",
    "wav2vec2": "https://download.pytorch.org/torchaudio/models/wav2vec2_fairseq_base_ls960_asr_ls960.pth",
}
PINS = {
    "kokoro": "f3ff3571791e39611d31c381e3a41a3af07b4987",       # hexgrad/Kokoro-82M
    "whisper": "edaa852ec7e145841d8ffdb056a99866b5f0a478",      # Systran/faster-whisper-large-v3
    "chatterbox": "5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18",   # ResembleAI/chatterbox
    "vibevoice": "c00898d257e6b46004e3e2866a47534085fb685a",    # microsoft/VibeVoice-1.5B
    "qwen": "8faed761d45a263340a0528343f099c05c9a4323",         # Qwen/Qwen2.5-1.5B (tokenizer only)
}
# Packages in the Windows lists that do not exist (or are not wanted) on Linux.
WINDOWS_ONLY = {"pywin32", "pypiwin32", "pywin32-ctypes", "pywinpty", "pyreadline3", "windows-curses", "wmi",
                "comtypes", "winshell", "triton-windows", "pefile", "pyaudiowpatch"}
TORCH_FAMILY = ("torch", "torchaudio", "torchvision", "torchcodec", "xformers")


# ---- small helpers ----------------------------------------------------------------------------
def log(text=""):
    print(text, flush=True)

def run(cmd, cwd=None, check=True):
    """Run a program (or, with --dry-run, only print it)."""
    cmd = [str(c) for c in cmd]
    log("  > " + " ".join(cmd) + (f"      (in {cwd})" if cwd else ""))
    if DRY:
        return 0
    r = subprocess.run(cmd, cwd=str(cwd) if cwd else None)
    if check and r.returncode != 0:
        raise RuntimeError(f"{Path(cmd[0]).name} failed with exit code {r.returncode}")
    return r.returncode

def have(name):
    return shutil.which(name) is not None

def venv_py(tool_dir):
    return ROOT / tool_dir / ".venv" / "bin" / "python"

def venv_bin(tool_dir, name):
    return ROOT / tool_dir / ".venv" / "bin" / name

def fetch(url, dest):
    dest = Path(dest)
    log(f"  downloading {url}")
    if DRY:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".partial")
    for attempt in (1, 2, 3):
        try:
            urllib.request.urlretrieve(url, tmp)
            tmp.replace(dest)
            return
        except Exception as e:
            log(f"    attempt {attempt} failed: {e}")
            if attempt == 3:
                raise
            time.sleep(5 * attempt)

def py_code(py, code, cwd=None):
    """Run a short Python snippet in a tool's own environment (Windows: Invoke-PythonCode)."""
    tmp = ROOT / "logs" / f"_installer_{os.getpid()}.py"
    log("  > " + str(py) + " <snippet: " + code.strip().splitlines()[-1][:70] + ">")
    if DRY:
        return
    tmp.parent.mkdir(parents=True, exist_ok=True)
    tmp.write_text(code, encoding="utf-8")
    try:
        r = subprocess.run([str(py), str(tmp)], cwd=str(cwd) if cwd else None)
        if r.returncode != 0:
            raise RuntimeError(f"snippet failed with exit code {r.returncode}")
    finally:
        tmp.unlink(missing_ok=True)

def gpu_memory_gb():
    """Graphics memory of the first NVIDIA card, or None."""
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=20).stdout.strip().splitlines()[0]
        return float(out) / 1024
    except Exception:
        return None

def gpu_tier(gb):
    """Round to the sizes the kit plans around. Unknown -> 16 (the kit's assumption)."""
    if gb is None:
        return 16
    for limit, tier in ((10, 8), (14, 12), (20, 16), (28, 24)):
        if gb < limit:
            return tier
    return 32


# ---- building blocks (Windows: Install-Repo, Install-LockedEnv, Install-Kokoro) -------------------
def install_repo(name, repair=False):
    """Clone a tool's repository at its pinned commit."""
    r = MANIFEST["repos"][name]
    d = ROOT / r["dir"].replace("\\", "/")
    if not (d / ".git").exists():
        if not DRY:
            d.mkdir(parents=True, exist_ok=True)
        run(["git", "-C", d, "init", "--quiet"])
        run(["git", "-C", d, "remote", "add", "origin", r["url"]])
    elif not repair and not DRY:
        head = subprocess.run(["git", "-C", str(d), "rev-parse", "--verify", "--quiet", "HEAD"], capture_output=True, text=True).stdout.strip()
        if head == r["commit"]:
            log(f"  {name} already at the pinned commit")
            return
        if head:
            log(f"  {name} is at {head} (pinned: {r['commit']}); leaving it. Use --repair to go back.")
            return
    run(["git", "-C", d, "fetch", "--filter=blob:none", "--quiet", "origin"])
    if r.get("branch"):
        run(["git", "-C", d, "-c", "advice.detachedHead=false", "checkout", "--force", "-B", r["branch"], r["commit"]])
    else:
        run(["git", "-C", d, "-c", "advice.detachedHead=false", "checkout", "--force", r["commit"]])

def linux_lock(name):
    """The Windows package list, split for Linux: (torch family lines, everything else)."""
    e = MANIFEST["envs"][name]
    torch_lines, rest = [], []
    for line in (LOCKS / e["lock"]).read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or s.startswith("-"):
            continue
        pkg = re.split(r"==| @ ", s)[0].strip().lower().replace("_", "-")
        if pkg in WINDOWS_ONLY or "win_amd64" in s or "windows" in s.lower():
            log(f"    (skipping the Windows-only package {pkg})")
            continue
        (torch_lines if pkg in TORCH_FAMILY else rest).append(s)
    return torch_lines, rest

def install_locked_env(name, repair=False):
    """A tool's private Python environment from setup/locks/<name>.txt.
    Pass 1: PyTorch with its dependencies (on Linux that brings the nvidia-* runtime libraries).
    Pass 2: every other pinned package exactly, without dependency resolution, as on Windows.
    If pass 2 leaves something missing at run time, install it by hand into that environment:
        uv pip install --python <tool>/.venv/bin/python <package>"""
    e = MANIFEST["envs"][name]
    d = e["dir"].replace("\\", "/")
    py = venv_py(d)
    if not py.exists() or DRY:
        cmd = ["uv", "venv", ROOT / d / ".venv", "--python", e["python"], "--clear"]
        if e.get("seed"):
            cmd.append("--seed")
        run(cmd)
    idx = ["--index-strategy", "unsafe-best-match"]
    for ix in e.get("indexes") or []:
        idx += ["--extra-index-url", ix]
    torch_lines, rest = linux_lock(name)
    if torch_lines:
        run(["uv", "pip", "install", "--python", py] + torch_lines + idx)
    req = ROOT / "logs" / f"_linux_lock_{name}.txt"
    if not DRY:
        req.parent.mkdir(parents=True, exist_ok=True)
        req.write_text("\n".join(rest) + "\n", encoding="utf-8")
    run(["uv", "pip", "install", "--python", py, "--no-deps", "-r", req] + idx)

def hf_ready(repo, filename):
    snap = ROOT / "models" / "huggingface" / "hub" / ("models--" + repo.replace("/", "--")) / "snapshots"
    return snap.exists() and any(snap.rglob(filename))

def install_kokoro(py):
    if hf_ready("hexgrad/Kokoro-82M", "kokoro-v1_0.pth"):
        log("  Kokoro voices already downloaded")
        return
    py_code(py, f"""
import os
from huggingface_hub import snapshot_download
rev = '{PINS["kokoro"]}'
path = snapshot_download('hexgrad/Kokoro-82M', revision=rev, allow_patterns=['config.json', 'kokoro-v1_0.pth', 'voices/*.pt'])
refs = os.path.join(os.environ['HF_HOME'], 'hub', 'models--hexgrad--Kokoro-82M', 'refs')
os.makedirs(refs, exist_ok=True)
open(os.path.join(refs, 'main'), 'w').write(rev)
print('Kokoro model and voices in', path)
""")


# ---- components (Windows: the Install-<Name> functions) ---------------------------------------------
def install_core(a):
    for d in ("launchers", "logs", "models", "music/in", "music/out", "music/stems", "narrate/in", "narrate/out",
              "transcribe/in", "transcribe/out", "voices/reference", "voices/out", "tools/_bin", "python", ".cache"):
        if not DRY:
            (ROOT / d).mkdir(parents=True, exist_ok=True)
    missing = [c for c in ("git", "ffmpeg") if not have(c)]
    if missing:
        raise RuntimeError("Please install these with your system's package manager first: " + ", ".join(missing) +
                           "   (Debian/Ubuntu: sudo apt install git ffmpeg fluidsynth)")
    if not have("nvidia-smi"):
        log("  WARNING: nvidia-smi was not found. These tools need an NVIDIA card and driver to run at a usable speed.")
    for v in MANIFEST["pythons"]:
        run(["uv", "python", "install", v])

def install_transcribe(a):
    install_locked_env("whisperx", a.repair)
    if a.skip_models:
        return
    seg = ROOT / "models/diarization/segmentation/model.onnx"
    if not seg.exists():
        dl = ROOT / "models/diarization/_download"
        fetch(URLS["diarSeg"], dl / "seg.tar.bz2")
        if not DRY:
            with tarfile.open(dl / "seg.tar.bz2") as t:
                t.extractall(dl)
            seg.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(dl / "sherpa-onnx-pyannote-segmentation-3-0" / "model.onnx"), str(seg))
            shutil.rmtree(dl)
    emb = ROOT / "models/diarization/embedding/nemo_en_titanet_large.onnx"
    if not emb.exists():
        fetch(URLS["diarEmb"], emb)
    w2v = ROOT / "models/torch/hub/checkpoints/wav2vec2_fairseq_base_ls960_asr_ls960.pth"
    if not w2v.exists():
        fetch(URLS["wav2vec2"], w2v)
    if not hf_ready("Systran/faster-whisper-large-v3", "model.bin"):
        py_code(venv_py("tools/whisperx"), f"""
import os
from huggingface_hub import snapshot_download
rev = '{PINS["whisper"]}'
path = snapshot_download('Systran/faster-whisper-large-v3', revision=rev)
refs = os.path.join(os.environ['HF_HOME'], 'hub', 'models--Systran--faster-whisper-large-v3', 'refs')
os.makedirs(refs, exist_ok=True)
open(os.path.join(refs, 'main'), 'w').write(rev)
print('Whisper large-v3 in', path)
""")

def install_narrate(a):
    install_locked_env("narrate", a.repair)
    if not a.skip_models:
        install_kokoro(venv_py("tools/narrate"))

def install_abogen(a):
    # Abogen is a desktop (Qt) app. On Linux it may also want system libraries for Qt and audio.
    install_locked_env("abogen", a.repair)
    if not a.skip_models:
        install_kokoro(venv_py("tools/abogen"))

def install_acestep(a):
    install_repo("ACE-Step-1.5", a.repair)
    d = ROOT / "tools/ACE-Step-1.5"
    e = MANIFEST["envs"]["ACE-Step-1.5"]
    # ACE-Step pins its own environment in its uv.lock, which covers Linux too.
    if not venv_bin("tools/ACE-Step-1.5", "acestep").exists() or a.repair or DRY:
        run(["uv", "sync", "--frozen", "--python", e["python"]], cwd=d)
    overlay = SETUP / "overlays" / "ACE-Step-1.5" / ".env"
    if overlay.exists() and not (d / ".env").exists() and not DRY:
        shutil.copyfile(overlay, d / ".env")
        log("  wrote .env")
    if a.skip_models:
        return
    dl, ck = venv_bin("tools/ACE-Step-1.5", "acestep-download"), d / "checkpoints"
    if not any((ck / "acestep-v15-turbo").glob("*.safetensors")):
        run([dl, "--dir", ck], cwd=d)                       # 2B turbo, VAE, text encoder, 1.7B planner
    if not any((ck / "acestep-v15-base").glob("*.safetensors")):
        run([dl, "--model", "acestep-v15-base", "--skip-main", "--dir", ck], cwd=d)
    if a.with_xl and not any((ck / "acestep-v15-xl-turbo").glob("*.safetensors")):
        run([dl, "--model", "acestep-v15-xl-turbo", "--skip-main", "--dir", ck], cwd=d)

def install_hum(a):
    install_locked_env("humtools", a.repair)
    if not have("fluidsynth"):
        log("  NOTE: FluidSynth is missing. Install it with your package manager (Debian/Ubuntu: sudo apt install fluidsynth).")
    if a.skip_models:
        return
    sf = ROOT / "models/soundfonts/GeneralUser-GS.sf2"
    if not sf.exists():
        fetch(URLS["sf2"], sf)
        fetch(URLS["sf2readme"], ROOT / "models/soundfonts/GeneralUser-GS README.md")

def install_separate(a):
    install_locked_env("separator", a.repair)
    if a.skip_models:
        return
    exe, d = venv_bin("tools/separator", "audio-separator"), ROOT / "models/separator"
    if not (d / "htdemucs_ft.yaml").exists():
        run([exe, "--download_model_only", "-m", "htdemucs_ft.yaml", "--model_file_dir", d])
    if not (d / "model_bs_roformer_ep_317_sdr_12.9755.ckpt").exists():
        run([exe, "--download_model_only", "-m", "model_bs_roformer_ep_317_sdr_12.9755.ckpt", "--model_file_dir", d])

def install_applio(a):
    install_repo("Applio", a.repair)
    install_locked_env("Applio", a.repair)
    if a.skip_models:
        return
    if not (ROOT / "tools/Applio/rvc/models/predictors/rmvpe.pt").exists():
        run([venv_py("tools/Applio"), "core.py", "prerequisites"], cwd=ROOT / "tools/Applio")

def install_comfyui(a):
    install_repo("ComfyUI", a.repair)
    fresh = not venv_py("tools/ComfyUI").exists()
    install_locked_env("ComfyUI", a.repair)
    install_repo("TTS-Audio-Suite", a.repair)
    py, suite = venv_py("tools/ComfyUI"), ROOT / "tools/ComfyUI/custom_nodes/TTS-Audio-Suite"
    if fresh or a.repair or DRY:
        run([py, "install.py"], cwd=suite)     # the suite's own installer adds fish-speech and friends
    # (Windows also fetches ffmpeg as shared libraries for Fish Audio S2; on Linux the system ffmpeg has them.)
    wf = ROOT / "tools/ComfyUI/user/default/workflows"
    names = {"Chatterbox integration.json": "1 - Clone a voice (ChatterBox).json",
             "*Voice Changer - RVC X ChatterBox.json": "2 - Voice changer (RVC or ChatterBox).json",
             "VibeVoice integration.json": "3 - Expressive long-form and multi-speaker (VibeVoice).json",
             "*IndexTTS-2 integration.json": "4 - Emotion-controlled cloning (IndexTTS-2).json",
             "Unified*TTS SRT.json": "5 - Narrate a subtitle file (SRT).json",
             "Voice Cleaning*Noise or Vocal Removal*Voice Fixer.json": "6 - Clean up a voice recording.json",
             "Unified*Voice Designer.json": "7 - Design a new voice from a description.json",
             "RVC*Model Training.json": "8 - Train an RVC voice model.json"}
    if not DRY:
        wf.mkdir(parents=True, exist_ok=True)
        for pattern, target in names.items():
            src = next(iter((suite / "example_workflows").glob(pattern)), None)
            if src and not (wf / target).exists():
                shutil.copyfile(src, wf / target)
        voices = ROOT / "tools/ComfyUI/models/voices"
        voices.mkdir(parents=True, exist_ok=True)
        for f in (ROOT / "voices/reference").glob("*"):
            if f.suffix.lower() in (".wav", ".mp3", ".flac", ".txt") and not (voices / f.name).exists():
                shutil.copyfile(f, voices / f.name)
    if a.skip_models:
        return
    py_code(py, f"""
import os
from huggingface_hub import hf_hub_download
tts = os.path.join(os.environ['AIA_ROOT'], 'tools', 'ComfyUI', 'models', 'TTS')
def get(repo, rev, files, dest):
    os.makedirs(dest, exist_ok=True)
    for f in files:
        if not os.path.exists(os.path.join(dest, f)):
            hf_hub_download(repo, f, revision=rev, local_dir=dest)
            print('downloaded', repo, f)
get('ResembleAI/chatterbox', '{PINS["chatterbox"]}', ['conds.pt', 's3gen.pt', 's3gen.safetensors', 't3_cfg.pt', 'tokenizer.json', 've.pt'],
    os.path.join(tts, 'chatterbox', 'English'))
vv = os.path.join(tts, 'vibevoice', 'vibevoice-1.5B')
get('microsoft/VibeVoice-1.5B', '{PINS["vibevoice"]}', ['config.json', 'preprocessor_config.json', 'model.safetensors.index.json',
    'model-00001-of-00003.safetensors', 'model-00002-of-00003.safetensors', 'model-00003-of-00003.safetensors'], vv)
get('Qwen/Qwen2.5-1.5B', '{PINS["qwen"]}', ['tokenizer.json'], vv)
get('Qwen/Qwen2.5-1.5B', '{PINS["qwen"]}', ['tokenizer.json', 'tokenizer_config.json'], os.path.join(tts, 'vibevoice', 'Qwen_Qwen2.5-1.5B', 'tokenizer'))
print('ChatterBox and VibeVoice models ready')
""")

INSTALLERS = {"core": install_core, "transcribe": install_transcribe, "narrate": install_narrate, "abogen": install_abogen,
              "acestep": install_acestep, "hum": install_hum, "separate": install_separate, "applio": install_applio,
              "comfyui": install_comfyui}

# Is a component there? (a light version of Get-ComponentState in setup/install.ps1)
PRESENT = {"core": "python", "transcribe": "tools/whisperx/.venv/bin/python", "narrate": "tools/narrate/.venv/bin/python",
           "abogen": "tools/abogen/.venv/bin/abogen", "acestep": "tools/ACE-Step-1.5/.venv/bin/acestep",
           "hum": "tools/humtools/.venv/bin/python", "separate": "tools/separator/.venv/bin/audio-separator",
           "applio": "tools/Applio/.venv/bin/python", "comfyui": "tools/ComfyUI/.venv/bin/python"}


# ---- starting the tools (Windows: launchers/*.bat; the key is the panel tool key in components.json) ----
def tool_command(key, files):
    r = ROOT
    sep = [venv_bin("tools/separator", "audio-separator"), *files, "--model_file_dir", r / "models/separator",
           "--output_dir", r / "music/stems", "--output_format", "WAV"]
    table = {
        "ace_xl": ([venv_bin("tools/ACE-Step-1.5", "acestep"), "--port", "7860", "--server-name", "127.0.0.1", "--language", "en",
                    "--config_path", "acestep-v15-xl-turbo", "--lm_model_path", "acestep-5Hz-lm-1.7B",
                    "--offload_dit_to_cpu", "true", "--init_service", "true"], r / "tools/ACE-Step-1.5"),
        "ace_fast": ([venv_bin("tools/ACE-Step-1.5", "acestep"), "--port", "7860", "--server-name", "127.0.0.1", "--language", "en",
                      "--config_path", "acestep-v15-turbo", "--lm_model_path", "acestep-5Hz-lm-1.7B", "--init_service", "true"],
                     r / "tools/ACE-Step-1.5"),
        "comfy": ([venv_py("tools/ComfyUI"), "main.py", "--listen", "127.0.0.1", "--port", "8189", "--enable-manager", "--auto-launch"],
                  r / "tools/ComfyUI"),
        "applio": ([venv_py("tools/Applio"), "app.py", "--open"], r / "tools/Applio"),
        "abogen": ([venv_bin("tools/abogen", "abogen")], r),
        "transcribe": ([venv_py("tools/whisperx"), r / "scripts/transcribe.py", *(files or ["--watch"])], r),
        "narrate": ([venv_py("tools/narrate"), r / "scripts/narrate.py", *(files or ["--watch"])], r),
        "narrate_video": ([venv_py("tools/narrate"), r / "scripts/narrate.py", "--video", *(files or ["--watch"])], r),
        "hum": ([venv_py("tools/humtools"), r / "scripts/hum_to_track.py", *(files or ["--help"])], r),
        "sep_vocals": (sep + ["-m", "model_bs_roformer_ep_317_sdr_12.9755.ckpt"], r),
        "sep_stems": (sep + ["-m", "htdemucs_ft.yaml"], r),
    }
    return table[key]

def cmd_start(a):
    if " " in str(ROOT) and a.tool == "applio":
        log("Applio refuses to start from a folder path that contains a space. Move the kit to a path without spaces.")
        return 1
    cmd, cwd = tool_command(a.tool, [str(Path(f).resolve()) for f in a.files])
    env = dict(os.environ)
    if a.tool == "comfy":
        env["TORCHDYNAMO_DISABLE"] = "1"      # as on Windows: no PyTorch self-compiling
    log("  > " + " ".join(str(c) for c in cmd))
    if DRY:
        return 0
    return subprocess.call([str(c) for c in cmd], cwd=str(cwd), env=env)

def cmd_stop(a):
    """Stop every program that was started from this folder (Windows: Stop everything.bat). Never a browser."""
    me, n = os.getpid(), 0
    for p in Path("/proc").glob("[0-9]*"):
        try:
            pid = int(p.name)
            exe = os.readlink(p / "exe")
            cl = (p / "cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace")
        except OSError:
            continue
        if pid == me or pid == os.getppid():
            continue
        if exe.startswith(str(ROOT) + "/") or (str(ROOT) + "/tools/" in cl) or (str(ROOT) + "/scripts/" in cl):
            log(f"  stopping {pid}: {cl[:90]}")
            if not DRY:
                try:
                    os.kill(pid, signal.SIGTERM)
                    n += 1
                except OSError:
                    pass
    log(f"Stopped {n} program(s)." if n else "Nothing was running.")
    return 0


# ---- commands ------------------------------------------------------------------------------------
def cmd_list(a):
    gb = gpu_memory_gb()
    log(f"Kit folder: {ROOT}")
    log("Graphics memory: " + (f"{gb:.0f} GB detected, planning for {gpu_tier(gb)} GB" if gb else "not detected, assuming 16 GB"))
    for c in CATALOG:
        state = "installed" if (ROOT / PRESENT[c["key"]]).exists() else "not installed"
        note = f"   (needs a {c['min_gb']} GB card)" if c.get("min_gb", 0) > gpu_tier(gb) else ""
        log(f"  {c['key']:<11} {c['name']:<22} {state:<14} {c['size']}{note}")
    log("Presets: " + ", ".join(f"{k} = {', '.join(v['keys'])}" for k, v in REGISTRY.get("presets", {}).items()))
    return 0

def resolve(words):
    keys = []
    for w in ",".join(words).split(","):
        w = w.strip().lower()
        if not w:
            continue
        if w == "all":
            keys += KEYS
        elif w in REGISTRY.get("presets", {}):
            keys += REGISTRY["presets"][w]["keys"]
        elif w in KEYS:
            keys.append(w)
        else:
            raise SystemExit(f"Unknown component or preset '{w}'. Choose from: {', '.join(KEYS)}, all, " + ", ".join(REGISTRY.get('presets', {})))
    keys = ["core"] + keys
    return [k for k in KEYS if k in keys]

def cmd_install(a):
    keys = resolve(a.what)
    gb = gpu_memory_gb()
    tier = a.gpu_gb or gpu_tier(gb)
    log(f"AI Audio install in {ROOT}")
    log("Graphics memory: " + (f"{gb:.0f} GB detected" if gb else "not detected") + f"; planning for {tier} GB")
    if a.with_xl and tier < 12:
        log("  NOTE: the ACE-Step XL model needs a 12 GB card or more; leaving it out.")
        a.with_xl = False
    log("Components: " + ", ".join(keys))
    if " " in str(ROOT):
        log("  NOTE: this folder's path contains a space. Applio will not start from it; other tools are fine.")
    failed = []
    for i, k in enumerate(keys, 1):
        name = next(c["name"] for c in CATALOG if c["key"] == k)
        log(f"\n=== {i}/{len(keys)} {name} ===")
        if (ROOT / PRESENT[k]).exists() and not a.repair and k != "core" and not DRY:
            log("  already installed - skipped (use --repair to redo it)")
            continue
        try:
            INSTALLERS[k](a)
        except Exception as e:
            failed.append(k)
            log(f"  FAILED: {e}")
            if k == "core":
                log("Core failed, so nothing else can be installed.")
                break
    log("")
    log("Finished with problems in: " + ", ".join(failed) if failed else "All done.")
    return 1 if failed else 0

def main():
    global DRY
    p = argparse.ArgumentParser(description="AI Audio on Linux (untested translation of the Windows installer and launchers)")
    p.add_argument("--dry-run", action="store_true", help="print what would be run, run nothing")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="what is installed, graphics memory, presets")
    i = sub.add_parser("install", help="install components: keys, 'all', or a preset name")
    i.add_argument("what", nargs="+")
    i.add_argument("--skip-models", action="store_true", help="environments only; the tools fetch models on first use")
    i.add_argument("--with-xl", action="store_true", help="also download the ACE-Step XL model (about 19 GB)")
    i.add_argument("--repair", action="store_true", help="go back to the pinned commits and redo the environments")
    i.add_argument("--gpu-gb", type=int, choices=(8, 12, 16, 24, 32), help="plan for this much graphics memory instead of what is detected")
    i.add_argument("--dry-run", action="store_true")
    s = sub.add_parser("start", help="start a tool: " + ", ".join(t["key"] for t in REGISTRY["tools"]))
    s.add_argument("tool", choices=[t["key"] for t in REGISTRY["tools"]])
    s.add_argument("files", nargs="*")
    s.add_argument("--dry-run", action="store_true")
    sub.add_parser("stop", help="stop every AI Audio program")
    a = p.parse_args()
    DRY = bool(a.dry_run)
    return {"list": cmd_list, "install": cmd_install, "start": cmd_start, "stop": cmd_stop}[a.cmd](a)

if __name__ == "__main__":
    sys.exit(main())
