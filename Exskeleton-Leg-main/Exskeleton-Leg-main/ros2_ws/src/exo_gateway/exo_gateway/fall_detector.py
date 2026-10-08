"""Run the SisFall TFLite model on 100 Hz IMU samples from the ESP32."""

from collections import deque
import time
from pathlib import Path

import numpy as np
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import FallAlert, ImuSample


class FallDetector(Node):
    def __init__(self):
        super().__init__('fall_detector')
        self.declare_parameter('model_path', '/home/robot/fall_detection_6axis_float32_frozen.tflite')
        self.declare_parameter('device_id', 'exo-leg-1')
        self.declare_parameter('window_size', 200)
        self.declare_parameter('inference_stride', 50)
        self.declare_parameter('fall_threshold', 0.80)
        self.declare_parameter('confirm_windows', 2)
        self.declare_parameter('alert_cooldown_sec', 10.0)

        model_path = Path(str(self.get_parameter('model_path').value))
        self._interpreter = self._load_interpreter(model_path)
        self._input = self._interpreter.get_input_details()[0]
        self._output = self._interpreter.get_output_details()[0]
        expected = tuple(int(x) for x in self._input['shape'])
        if expected != (1, 200, 6):
            raise RuntimeError(f'Expected TFLite input [1,200,6], got {expected}')
        self._interpreter.allocate_tensors()

        self._window = deque(maxlen=200)
        self._samples_since_inference = 0
        self._consecutive_fall_windows = 0
        self._last_alert_at = 0.0
        self._prediction_count = 0
        self._alert_pub = self.create_publisher(FallAlert, '/exo/fall/alert', 10)
        self.create_subscription(ImuSample, '/exo/imu', self._on_sample, 100)
        self.get_logger().info(f'Loaded TFLite model: {model_path}')

    @staticmethod
    def _load_interpreter(model_path):
        if not model_path.is_file():
            raise FileNotFoundError(f'Model not found: {model_path}')
        try:
            from tflite_runtime.interpreter import Interpreter
        except ImportError:
            try:
                # ai-edge-litert provides ARM64 wheels for newer Python
                # versions where the older tflite-runtime package is absent.
                from ai_edge_litert.interpreter import Interpreter
            except ImportError as error:
                try:
                    from tensorflow.lite import Interpreter
                except ImportError:
                    raise RuntimeError(
                        'Install ai-edge-litert, tflite-runtime, or tensorflow on the Pi'
                    ) from error
        return Interpreter(model_path=str(model_path), num_threads=4)

    def _on_sample(self, sample):
        if sample.channel != 4:
            return
        self._window.append([
            sample.ax, sample.ay, sample.az,
            sample.gx, sample.gy, sample.gz,
        ])
        self._samples_since_inference += 1
        if len(self._window) < 200 or self._samples_since_inference < 50:
            return
        self._samples_since_inference = 0
        values = np.asarray(self._window, dtype=np.float32)[None, :, :]
        self._interpreter.set_tensor(self._input['index'], values)
        self._interpreter.invoke()
        probabilities = self._interpreter.get_tensor(self._output['index'])[0]
        predicted = int(np.argmax(probabilities))
        fall_probability = float(probabilities[3])
        if predicted == 3 and fall_probability >= float(self.get_parameter('fall_threshold').value):
            self._consecutive_fall_windows += 1
        else:
            self._consecutive_fall_windows = 0

        confirmed = self._consecutive_fall_windows >= int(self.get_parameter('confirm_windows').value)
        if confirmed:
            now = time.monotonic()
            cooldown = float(self.get_parameter('alert_cooldown_sec').value)
            if now - self._last_alert_at >= cooldown:
                self._last_alert_at = now
                alert = FallAlert()
                alert.header.stamp = self.get_clock().now().to_msg()
                alert.alert_id = f"{self.get_parameter('device_id').value}-{time.time_ns()}"
                alert.device_id = str(self.get_parameter('device_id').value)
                alert.predicted_class = predicted
                alert.predicted_label = 'Fall'
                alert.fall_probability = fall_probability
                alert.consecutive_fall_windows = self._consecutive_fall_windows
                alert.confirmed = True
                self._alert_pub.publish(alert)
                self.get_logger().warning(
                    f'FALL ALERT probability={fall_probability:.3f} '
                    f'windows={self._consecutive_fall_windows}'
                )
        self._prediction_count += 1
        if self._prediction_count % 20 == 0:
            self.get_logger().info(
                f'prediction={predicted} fall_probability={fall_probability:.3f}'
            )


def main(args=None):
    rclpy.init(args=args)
    node = FallDetector()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
