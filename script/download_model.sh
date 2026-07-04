#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-ggml-base.bin}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="$ROOT_DIR/models"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL"

mkdir -p "$MODEL_DIR"
echo "Downloading $MODEL"
curl -L --retry 3 --continue-at - -o "$MODEL_DIR/$MODEL" "$URL"
echo "Saved to $MODEL_DIR/$MODEL"
