#!/usr/bin/env python3

import rospy
from geometry_msgs.msg import Twist
from std_msgs.msg import String


class ExoskeletonBaseNode:
    def __init__(self):
        self.status_pub = rospy.Publisher("exoskeleton/status", String, queue_size=10)
        self.cmd_sub = rospy.Subscriber("exoskeleton/cmd_vel", Twist, self._on_cmd_vel)
        self.last_cmd = Twist()
        self.publish_rate_hz = rospy.get_param("~publish_rate_hz", 10.0)

    def _on_cmd_vel(self, msg):
        self.last_cmd = msg

    def spin(self):
        rate = rospy.Rate(self.publish_rate_hz)
        while not rospy.is_shutdown():
            status = (
                "base_ready "
                "linear_x={:.3f} angular_z={:.3f}"
            ).format(self.last_cmd.linear.x, self.last_cmd.angular.z)
            self.status_pub.publish(status)
            rate.sleep()


if __name__ == "__main__":
    rospy.init_node("exoskeleton_base")
    ExoskeletonBaseNode().spin()
