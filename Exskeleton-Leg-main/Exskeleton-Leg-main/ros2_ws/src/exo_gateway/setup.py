from setuptools import find_packages, setup

package_name = 'exo_gateway'

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/exo_gateway']),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', ['launch/safety_gateway.launch.py']),
        ('share/' + package_name + '/config', ['config/safety.yaml']),
    ],
    install_requires=['setuptools'],
    test_suite='test',
    zip_safe=True,
    maintainer='Exoskeleton team',
    maintainer_email='maintainers@example.com',
    description='Safety boundary between external commands and hardware.',
    license='Apache-2.0',
    entry_points={'console_scripts': [
        'safety_gateway = exo_gateway.safety_gateway:main',
        'ble_bridge = exo_gateway.ble_bridge:main',
        'uart_bridge = exo_gateway.uart_bridge:main',
        'fall_detector = exo_gateway.fall_detector:main',
        'oled_display = exo_gateway.oled_display:main',
    ]},
)
