#!/usr/bin/env bash
set -euo pipefail
echo "--- exoskeleton nodes ---"
ros2 node list || true
echo "--- exoskeleton topics ---"
ros2 topic list | grep '^/exo' || true
echo "Use: ros2 topic echo /exo/state"
echo "Use: ros2 topic echo /exo/exercise/status"
echo "The launch terminal prints UART TX/RX and connection errors."
