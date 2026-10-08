#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ros2-jazzy}"
WORKSPACE="${WORKSPACE:-$HOME/ros2_ws}"
IMAGE="${ROS_IMAGE:-ros:jazzy-ros-base}"

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  exec docker start -ai "${CONTAINER_NAME}"
fi

mkdir -p "${WORKSPACE}"
exec docker run -it --name "${CONTAINER_NAME}" --network host --privileged \
  -v /dev:/dev -v /run/dbus:/run/dbus \
  -v "${WORKSPACE}:/root/ros2_ws" "${IMAGE}" bash
