from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory
import os


def generate_launch_description():
    config = os.path.join(get_package_share_directory('exo_gateway'), 'config', 'safety.yaml')
    return LaunchDescription([
        DeclareLaunchArgument('enable_ble', default_value='true',
                              description='Start the BLE GATT peripheral'),
        Node(package='exo_gateway', executable='safety_gateway', name='safety_gateway',
             output='screen', parameters=[config]),
        Node(package='exo_gateway', executable='ble_bridge', name='ble_bridge', output='screen',
             condition=IfCondition(LaunchConfiguration('enable_ble'))),
        Node(package='exo_gateway', executable='uart_bridge', name='uart_bridge', output='screen',
             parameters=[config]),
        Node(package='exo_gateway', executable='fall_detector', name='fall_detector', output='screen',
             parameters=[config]),
        Node(package='exo_gateway', executable='oled_display', name='oled_display', output='screen',
             parameters=[config]),
    ])
