#!/usr/bin/env bash
set -euo pipefail

if [[ -t 0 ]]; then
  docker_flags=(-it)
else
  docker_flags=(-i)
fi

exec docker exec "${docker_flags[@]}" exo-gateway-ros2 bash -lc '
  source /opt/ros/jazzy/setup.bash
  source /root/ros2_ws/install/setup.bash
  venv_site=$(find /root/ros2_ws/.venv/lib -maxdepth 3 -type d -name site-packages -print -quit)
  export PYTHONPATH="${venv_site}:${PYTHONPATH:-}"
  exec python3 -u /root/ros2_ws/scripts/test_fall_live.py "$@"
' fall-live "$@"
