#!/usr/bin/env bash
# Downloads the Whistle engine + model into vendor/ and installs the C header. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -x .venv/bin/needle ] || { python3 -m venv .venv; .venv/bin/pip install -q "cactus-needle[mic]"; }
mkdir -p vendor
cd vendor
[ -f macos-arm64/libneedle.a ] || ../.venv/bin/needle download macos-arm64
[ -f whistle.cact ] || ../.venv/bin/needle download whistle
cd ..
cp vendor/macos-arm64/needle.h Sources/CNeedle/include/needle.h
[ -f vendor/test.wav ] || { say -o /tmp/saylo_t.aiff "Hello from Saylo, this is a quick dictation test."; \
  afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/saylo_t.aiff vendor/test.wav; }
echo "Saylo setup complete."
