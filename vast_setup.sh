#!/usr/bin/env bash
set -Eeuo pipefail

# Vast.ai Linux deployment script for this ComfyUI repository.
# Model source: Google Drive file ID below.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="${COMFY_DIR:-$SCRIPT_DIR}"
WORKFLOW_DIR="$COMFY_DIR/user/default/workflows"
CHECKPOINT_DIR="$COMFY_DIR/models/checkpoints"
MODEL_FILE_ID="${MODEL_FILE_ID:-1pNtKUAMxIBqUBBQIGlZEGCM6VknOMyWe}"
MODEL_NAME="${MODEL_NAME:-vast_model.safetensors}"
PORT="${PORT:-8188}"

log() { echo "[vast-comfy] $*"; }
die() { echo "[vast-comfy] ERROR: $*" >&2; exit 1; }

command -v python3 >/dev/null || die "python3 is required"
command -v git >/dev/null || die "git is required"

if [ "$(id -u)" -eq 0 ]; then
    APT="apt-get"
else
    APT="sudo apt-get"
fi

log "Installing Linux utilities"
$APT update -y
$APT install -y unzip file git curl

log "Installing Python dependencies"
python3 -m pip install --upgrade pip
python3 -m pip install gdown

if [ -f "$COMFY_DIR/requirements.txt" ]; then
    python3 -m pip install -r "$COMFY_DIR/requirements.txt"
fi

mkdir -p "$WORKFLOW_DIR" "$CHECKPOINT_DIR"

log "Installing required custom nodes"
if [ -f "$SCRIPT_DIR/custom_nodes.txt" ]; then
    while IFS= read -r url || [ -n "$url" ]; do
        url="${url%%#*}"
        url="$(echo "$url" | xargs)"
        [ -z "$url" ] && continue

        name="$(basename "${url%.git}")"
        target="$COMFY_DIR/custom_nodes/$name"
        mkdir -p "$COMFY_DIR/custom_nodes"

        if [ -d "$target/.git" ]; then
            git -C "$target" pull --ff-only || true
        elif [ ! -e "$target" ]; then
            git clone --depth 1 "$url" "$target"
        fi

        if [ -f "$target/requirements.txt" ]; then
            python3 -m pip install -r "$target/requirements.txt"
        fi
    done < "$SCRIPT_DIR/custom_nodes.txt"
else
    log "No custom_nodes.txt found; skipping optional custom nodes"
fi

log "Installing ComfyUI Manager"
MANAGER="$COMFY_DIR/custom_nodes/ComfyUI-Manager"
if [ ! -d "$MANAGER" ]; then
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER"
fi

log "Copying workflows"
if [ -d "$SCRIPT_DIR/workflows" ]; then
    find "$SCRIPT_DIR/workflows" -maxdepth 1 -type f -name '*.json' \
        -exec cp -f {} "$WORKFLOW_DIR/" \;
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
DOWNLOAD="$TMP_DIR/download"

if [ -s "$CHECKPOINT_DIR/$MODEL_NAME" ]; then
    log "Target model already exists; skipping Drive download"
else
    log "Downloading model from Google Drive"
    gdown "https://drive.google.com/uc?id=$MODEL_FILE_ID" -O "$DOWNLOAD"
    [ -s "$DOWNLOAD" ] || die "Downloaded model file is empty"

    KIND="$(file -b "$DOWNLOAD")"
    if echo "$KIND" | grep -qi 'Zip archive'; then
        log "ZIP detected; extracting safetensors"
        mkdir -p "$TMP_DIR/extracted"
        unzip -q "$DOWNLOAD" -d "$TMP_DIR/extracted"
        MODEL_SOURCE="$(find "$TMP_DIR/extracted" -type f -iname '*.safetensors' | head -n 1)"
        [ -n "${MODEL_SOURCE:-}" ] || die "ZIP contains no .safetensors file"
    else
        MODEL_SOURCE="$DOWNLOAD"
        echo "$KIND" | grep -Eqi 'data|tensor|safetensors' || \
            die "Downloaded file is not recognized as a model or ZIP: $KIND"
    fi

    cp -f "$MODEL_SOURCE" "$CHECKPOINT_DIR/$MODEL_NAME"
fi

[ -s "$CHECKPOINT_DIR/$MODEL_NAME" ] || die "Model was not installed: $CHECKPOINT_DIR/$MODEL_NAME"

log "Model installed: $CHECKPOINT_DIR/$MODEL_NAME"
log "Starting ComfyUI on 0.0.0.0:$PORT"
cd "$COMFY_DIR"
exec python3 main.py --listen 0.0.0.0 --port "$PORT"
