#!/usr/bin/env bash
# build.sh — Empaqueta las Lambdas en dist/
# Uso: ./build.sh   (desde la raíz del proyecto, Git Bash en Windows)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

# ── upload-lambda ─────────────────────────────
echo ">>> Empaquetando upload-lambda..."
cd "$ROOT_DIR/src/upload-lambda"
npm install --production --silent
zip -r "$DIST_DIR/upload-lambda.zip" . --exclude "*.test.js"
echo "    OK → dist/upload-lambda.zip"

# ── crop-lambda ───────────────────────────────
# IMPORTANTE: sharp requiere binarios nativos para Linux x64
echo ">>> Empaquetando crop-lambda (sharp linux/x64)..."
cd "$ROOT_DIR/src/crop-lambda"
npm install \
  --platform=linux \
  --arch=x64 \
  --production \
  --silent
zip -r "$DIST_DIR/crop-lambda.zip" . --exclude "*.test.js"
echo "    OK → dist/crop-lambda.zip"

echo ""
echo "✓ Build completo. Archivos generados:"
ls -lh "$DIST_DIR"
