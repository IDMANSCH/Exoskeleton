#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${PI_HOST:-robot@192.168.100.210}"
PI_WORKSPACE="${PI_WORKSPACE:-/home/robot/ros2_ws}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_SOURCE="${ROOT_DIR}/fall_detection_6axis_float32_frozen.bin"

command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }
[[ -f "${MODEL_SOURCE}" ]] || { echo "Fall model not found: ${MODEL_SOURCE}" >&2; exit 1; }
echo "Deploying ROS workspace to ${PI_HOST}:${PI_WORKSPACE}"
ssh "${PI_HOST}" "mkdir -p '${PI_WORKSPACE}' '/home/robot/esp32'"
rsync -av --progress --exclude build/ --exclude install/ --exclude log/ \
  --exclude .venv/ --exclude __pycache__/ \
  "${ROOT_DIR}/ros2_ws/" "${PI_HOST}:${PI_WORKSPACE}/"
rsync -av --progress "${ROOT_DIR}/esp32/" "${PI_HOST}:/home/robot/esp32/"
rsync -av --progress "${MODEL_SOURCE}" "${PI_HOST}:/home/robot/fall_detection_6axis_float32_frozen.tflite"
echo "Deployment complete. Build commands are in ros2_ws/README.md."
