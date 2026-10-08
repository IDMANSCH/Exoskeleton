#!/usr/bin/env bash
# ROS setup scripts reference optional variables, so load them before enabling
# nounset/strict mode.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${ROS2_WS_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# The Pi may run Humble, Iron, Jazzy, or another installed ROS 2 distro.
# Prefer an explicit ROS_DISTRO, otherwise use the first installed setup file.
if [[ -n "${ROS_DISTRO:-}" ]]; then
  ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"
else
  ROS_SETUP="$(find /opt/ros -mindepth 2 -maxdepth 2 -type f -name setup.bash -print -quit 2>/dev/null || true)"
fi
if [[ -z "${ROS_SETUP}" || ! -f "${ROS_SETUP}" ]]; then
  echo "No ROS 2 setup.bash found under /opt/ros" >&2
  exit 127
fi
source "${ROS_SETUP}"
cd "${WORKSPACE_DIR}"
source install/setup.bash
set -euo pipefail

# ROS 2 executables use the system interpreter from the base image. Expose the
# workspace virtualenv packages to that interpreter without replacing ROS 2.
if [[ -d "${WORKSPACE_DIR}/.venv/lib" ]]; then
  VENV_SITE_PACKAGES="$(find "${WORKSPACE_DIR}/.venv/lib" -maxdepth 3 -type d -name site-packages -print -quit)"
  if [[ -n "${VENV_SITE_PACKAGES}" ]]; then
    export PYTHONPATH="${VENV_SITE_PACKAGES}:${PYTHONPATH:-}"
  fi
fi

exec ros2 launch exo_gateway safety_gateway.launch.py
