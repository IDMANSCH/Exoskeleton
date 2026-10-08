#!/usr/bin/env python3
"""Inspect live ESP32 IMU samples and run the deployed fall model read-only."""

import argparse
from collections import deque
import math
import time
from pathlib import Path

import numpy as np
import rclpy
from rclpy.node import Node

from exo_gateway.fall_detector import FallDetector
from exo_interfaces.msg import ImuSample


LABELS = ('Walk', 'Run', 'Static/ADL', 'Fall')
WINDOW_SIZE = 200
INFERENCE_STRIDE = 50
FALL_THRESHOLD = 0.80
CONFIRM_WINDOWS = 2


class LiveFallTest(Node):
    def __init__(self, model_path):
        super().__init__('exo_fall_live_test')
        self._interpreter = FallDetector._load_interpreter(model_path)
        self._input = self._interpreter.get_input_details()[0]
        self._output = self._interpreter.get_output_details()[0]
        if tuple(int(size) for size in self._input['shape']) != (1, WINDOW_SIZE, 6):
            raise RuntimeError(f'Unexpected model input shape: {self._input["shape"]}')
        if self._input['dtype'] != np.float32:
            raise RuntimeError(f'Unexpected model input dtype: {self._input["dtype"]}')
        self._interpreter.allocate_tensors()
        self._window = deque(maxlen=WINDOW_SIZE)
        self._since_inference = 0
        self._consecutive_fall = 0
        self._last_alert_at = 0.0
        self._last_sample_at = time.monotonic()
        self._last_warning_at = 0.0
        self._last_sequence = None
        self.samples = 0
        self.predictions = 0
        self.alerts = 0
        self.create_subscription(ImuSample, '/exo/imu', self._on_sample, 100)
        print(f'Model loaded: {model_path}', flush=True)
        print('Reading /exo/imu (ESP32 via uart_bridge). Waiting for 200 samples...', flush=True)

    def _on_sample(self, sample):
        if sample.channel != 4:
            return
        self._last_sample_at = time.monotonic()
        if self._last_sequence is not None and sample.sequence != self._last_sequence + 1:
            print(f'IMU sequence gap: {self._last_sequence} -> {sample.sequence}; resetting window', flush=True)
            self._window.clear()
            self._since_inference = 0
            self._consecutive_fall = 0
        self._last_sequence = sample.sequence
        values = (sample.ax, sample.ay, sample.az, sample.gx, sample.gy, sample.gz)
        if not all(math.isfinite(value) for value in values):
            print('Invalid IMU value; resetting window', flush=True)
            self._window.clear()
            self._since_inference = 0
            return
        self._window.append(values)
        self._since_inference += 1
        self.samples += 1
        if len(self._window) < WINDOW_SIZE or self._since_inference < INFERENCE_STRIDE:
            return
        self._since_inference = 0
        data = np.asarray(self._window, dtype=np.float32)[None, :, :]
        self._interpreter.set_tensor(self._input['index'], data)
        self._interpreter.invoke()
        probabilities = self._interpreter.get_tensor(self._output['index'])[0]
        if len(probabilities) != len(LABELS):
            raise RuntimeError(f'Unexpected model output shape: {probabilities.shape}')
        predicted = int(np.argmax(probabilities))
        fall_probability = float(probabilities[3])
        self.predictions += 1
        if predicted == 3 and fall_probability >= FALL_THRESHOLD:
            self._consecutive_fall += 1
        else:
            self._consecutive_fall = 0
        accel_g = math.sqrt(sum(value * value for value in values[:3]))
        print(
            f'seq={sample.sequence} class={LABELS[predicted]} '
            f'p_fall={fall_probability:.3f} '
            f'consecutive={self._consecutive_fall}/{CONFIRM_WINDOWS} '
            f'|a|={accel_g:.2f}g',
            flush=True,
        )
        if self._consecutive_fall >= CONFIRM_WINDOWS:
            now = time.monotonic()
            if now - self._last_alert_at >= 10.0:
                self._last_alert_at = now
                self.alerts += 1
                print(
                    f'>>> FALL DETECTED: p={fall_probability:.3f}, '
                    f'consecutive_windows={self._consecutive_fall}, seq={sample.sequence} <<<',
                    flush=True,
                )

    def warn_if_no_samples(self):
        now = time.monotonic()
        if now - self._last_sample_at >= 3 and now - self._last_warning_at >= 5:
            self._last_warning_at = now
            print('No channel-4 IMU samples for 3 seconds; check ESP32 UART and imu_ready.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, default=Path('/home/robot/fall_detection_6axis_float32_frozen.tflite'))
    parser.add_argument('--duration', type=float, default=0,
                        help='Seconds to monitor; 0 means until Ctrl+C')
    args = parser.parse_args()
    if args.duration < 0:
        parser.error('--duration must be non-negative')
    rclpy.init()
    node = None
    try:
        node = LiveFallTest(args.model)
        started = time.monotonic()
        while rclpy.ok() and (args.duration == 0 or time.monotonic() - started < args.duration):
            rclpy.spin_once(node, timeout_sec=0.2)
            node.warn_if_no_samples()
    except KeyboardInterrupt:
        pass
    finally:
        if node is not None:
            print(f'Summary: samples={node.samples}, predictions={node.predictions}, '
                  f'fall_alerts={node.alerts}', flush=True)
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
