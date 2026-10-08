# Exoskeleton Pi ROS Workspace

Base catkin workspace for Raspberry Pi ROS development.

## Build

```bash
cd Pi/ros_ws
source /opt/ros/one/setup.bash
catkin_make
source devel/setup.bash
```

## Run

```bash
roslaunch exoskeleton_base base.launch
```

Useful topics:

- `exoskeleton/status`: heartbeat/status from the base node.
- `exoskeleton/cmd_vel`: placeholder command input using `geometry_msgs/Twist`.
