#!/usr/bin/env python3
"""Run a saved ComfyUI API-format workflow on the local "voices" ComfyUI.

Standard library only. Posts the workflow to the server, waits for it to
finish, and prints the path of every file it wrote (one per line on stdout;
progress and errors go to stderr).

    python comfy_run_workflow.py WORKFLOW.json [key=value ...] [options]

Overrides (key=value):
    text=...      text to speak            (TTS Text node "text")
    srt=...       subtitle text            (TTS SRT node "srt_content")
    ref=PATH      reference / target voice (Load Audio node titled "reference voice")
    source=PATH   audio to convert         (Load Audio node titled "source audio")
    prefix=...    output name prefix       (Save Audio node "filename_prefix")
    seed=N        seed on the TTS / SRT node
    NODE.INPUT=V  any other input, e.g. 2.exaggeration=0.7

    A value starting with @ is read from a text file:  text=@chapter1.txt
    ref= / source= take any audio file on disk; it is uploaded to the server's
    input folder first. A bare name that is not a file is passed through as-is
    (i.e. a file already in ComfyUI's input folder).

Options:
    --server URL       default http://127.0.0.1:8189
    --timeout SECONDS  default 3600
    --output-dir DIR   ComfyUI output folder (default: ..\\tools\\ComfyUI\\output
                       next to this script, or $COMFY_OUTPUT_DIR)
    --dry-run          print the patched workflow JSON and exit
"""
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

DEFAULT_SERVER = "http://127.0.0.1:8189"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUTPUT_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "tools", "ComfyUI", "output"))

# alias -> list of (class_type, input_name, node title or None, is_audio_file)
ALIASES = {
    "text":   [("UnifiedTTSTextNode", "text", None, False)],
    "srt":    [("UnifiedTTSSRTNode", "srt_content", None, False)],
    "ref":    [("LoadAudio", "audio", "reference voice", True)],
    "source": [("LoadAudio", "audio", "source audio", True)],
    "prefix": [("SaveAudio", "filename_prefix", None, False),
               ("SaveAudioMP3", "filename_prefix", None, False),
               ("SaveAudioOpus", "filename_prefix", None, False)],
    "seed":   [("UnifiedTTSTextNode", "seed", None, False),
               ("UnifiedTTSSRTNode", "seed", None, False)],
}


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def http_json(url, payload=None, timeout=60):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def upload_input_file(server, path):
    """Upload a local file to ComfyUI's input folder; return the name to use in Load Audio."""
    boundary = "----comfyrun" + uuid.uuid4().hex
    name = os.path.basename(path)
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
    with open(path, "rb") as fh:
        blob = fh.read()
    parts = [
        ("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n"
         "Content-Type: %s\r\n\r\n" % (boundary, name.replace('"', "_"), ctype)).encode("utf-8"),
        blob,
        ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue"
         "\r\n--%s\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\ninput"
         "\r\n--%s--\r\n" % (boundary, boundary, boundary)).encode("utf-8"),
    ]
    req = urllib.request.Request(
        server + "/upload/image", data=b"".join(parts),
        headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=300) as resp:
        info = json.loads(resp.read().decode("utf-8"))
    sub = info.get("subfolder") or ""
    return (sub + "/" if sub else "") + info["name"]


def coerce(value, current):
    """Keep strings as strings where the workflow has a string; otherwise parse JSON scalars."""
    if isinstance(current, str):
        return value
    try:
        return json.loads(value)
    except ValueError:
        return value


def find_targets(workflow, key):
    """Return [(node_id, input_name, is_audio_file)] for an override key."""
    if key in ALIASES:
        hits = []
        for class_type, input_name, title, is_audio in ALIASES[key]:
            for node_id, node in workflow.items():
                if node.get("class_type") != class_type or input_name not in node.get("inputs", {}):
                    continue
                if title and node.get("_meta", {}).get("title", "").strip().lower() != title:
                    continue
                hits.append((node_id, input_name, is_audio))
        return hits
    if "." in key:
        node_id, input_name = key.split(".", 1)
        if node_id in workflow:
            is_audio = workflow[node_id].get("class_type") == "LoadAudio" and input_name == "audio"
            return [(node_id, input_name, is_audio)]
    return []


def apply_overrides(workflow, overrides, server, dry_run=False):
    for key, value in overrides:
        targets = find_targets(workflow, key)
        if not targets:
            raise SystemExit("override '%s': no matching node/input in this workflow" % key)
        if value.startswith("@") and os.path.isfile(value[1:]):
            with open(value[1:], "r", encoding="utf-8-sig") as fh:
                value = fh.read()
        for node_id, input_name, is_audio in targets:
            inputs = workflow[node_id]["inputs"]
            new = value
            if is_audio and os.path.isfile(value):
                new = value if dry_run else upload_input_file(server, value)
            else:
                new = coerce(value, inputs.get(input_name))
            inputs[input_name] = new
            shown = new if not isinstance(new, str) or len(new) < 70 else new[:67] + "..."
            log("  set %s.%s (%s) = %r" % (node_id, input_name, workflow[node_id].get("class_type"), shown))


def wait_for(server, prompt_id, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            hist = http_json("%s/history/%s" % (server, prompt_id))
        except urllib.error.URLError as exc:
            raise SystemExit("lost contact with %s: %s" % (server, exc))
        entry = hist.get(prompt_id)
        if entry and entry.get("status", {}).get("completed") is not None:
            status = entry["status"]
            if status.get("status_str") == "success" or status.get("completed"):
                return entry
            for kind, detail in status.get("messages", []):
                if kind == "execution_error":
                    raise SystemExit("workflow failed in node %s (%s): %s" % (
                        detail.get("node_id"), detail.get("node_type"), detail.get("exception_message", "").strip()))
            raise SystemExit("workflow failed: %s" % json.dumps(status)[:2000])
        time.sleep(1.0)
    raise SystemExit("timed out after %ss waiting for prompt %s" % (timeout, prompt_id))


def main(argv):
    server = DEFAULT_SERVER
    timeout = 3600.0
    output_dir = os.environ.get("COMFY_OUTPUT_DIR", DEFAULT_OUTPUT_DIR)
    dry_run = False
    workflow_path = None
    overrides = []
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg in ("-h", "--help"):
            print(__doc__)
            return 0
        if arg == "--server":
            server = args.pop(0).rstrip("/")
        elif arg == "--timeout":
            timeout = float(args.pop(0))
        elif arg == "--output-dir":
            output_dir = args.pop(0)
        elif arg == "--dry-run":
            dry_run = True
        elif workflow_path is None:
            workflow_path = arg
        elif "=" in arg:
            overrides.append(tuple(arg.split("=", 1)))
        else:
            raise SystemExit("unexpected argument: %s (overrides are key=value)" % arg)
    if not workflow_path:
        print(__doc__)
        return 2

    with open(workflow_path, "r", encoding="utf-8") as fh:
        workflow = json.load(fh)
    apply_overrides(workflow, overrides, server, dry_run=dry_run)
    if dry_run:
        print(json.dumps(workflow, indent=2, ensure_ascii=False))
        return 0

    try:
        queued = http_json(server + "/prompt", {"prompt": workflow, "client_id": "comfy_run_workflow"})
    except urllib.error.HTTPError as exc:
        raise SystemExit("server rejected the workflow (HTTP %s): %s" % (
            exc.code, exc.read().decode("utf-8", "replace")[:4000]))
    except urllib.error.URLError as exc:
        raise SystemExit("cannot reach ComfyUI at %s (%s). Start it with the launcher first." % (server, exc.reason))
    prompt_id = queued["prompt_id"]
    log("queued prompt_id=%s" % prompt_id)

    started = time.time()
    entry = wait_for(server, prompt_id, timeout)
    log("finished in %.1fs" % (time.time() - started))

    paths = []
    for node_id, out in entry.get("outputs", {}).items():
        for items in out.values():
            if not isinstance(items, list):
                continue
            for item in items:
                if isinstance(item, dict) and item.get("filename") and item.get("type") == "output":
                    paths.append(os.path.normpath(os.path.join(output_dir, item.get("subfolder", ""), item["filename"])))
    if not paths:
        raise SystemExit("workflow finished but reported no saved files")
    for path in paths:
        if not os.path.isfile(path):
            log("warning: server reported %s but it is not on disk here (wrong --output-dir?)" % path)
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
