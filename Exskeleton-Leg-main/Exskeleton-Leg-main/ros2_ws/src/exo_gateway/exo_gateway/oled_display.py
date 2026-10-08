"""Small SSD1306 OLED status display for the Raspberry Pi.

The display is deliberately a read-only ROS consumer.  It never participates
in the safety or actuator path.  The implementation uses the common
SSD1306 128x64 command set and a tiny built-in 5x7 font so it does not need a
desktop stack or image/font packages on the Pi.
"""

import re
import threading
import time

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import DeviceState, ExerciseStatus


FONT = {
    ' ': (0x00, 0x00, 0x00, 0x00, 0x00),
    '-': (0x08, 0x08, 0x08, 0x08, 0x08),
    '%': (0x62, 0x64, 0x08, 0x13, 0x23),
    ':': (0x00, 0x36, 0x36, 0x00, 0x00),
    '/': (0x20, 0x10, 0x08, 0x04, 0x02),
    '.': (0x00, 0x60, 0x60, 0x00, 0x00),
}

# Add the characters used by exercise names and status strings.
_ROWS = [
    '01110 10001 10011 10101 11001 10001',
    '10001 11001 10101 10001 10001 10001',
    '10001 10101 10001 10001 10001 10001',
    '10001 10011 10001 10001 10001 10001',
    '01110 10001 10001 10001 10001 01110',
]
for _char in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789':
    if _char in FONT:
        continue
    # The table above is only a compact fallback for uncommon letters; the
    # explicit glyphs below cover the normal OLED text vocabulary.
    FONT[_char] = (0x7E, 0x09, 0x09, 0x09, 0x7E)

FONT.update({
    'A': (0x7E, 0x11, 0x11, 0x11, 0x7E), 'B': (0x7F, 0x49, 0x49, 0x49, 0x36),
    'C': (0x3E, 0x41, 0x41, 0x41, 0x22), 'D': (0x7F, 0x41, 0x41, 0x22, 0x1C),
    'E': (0x7F, 0x49, 0x49, 0x49, 0x41), 'F': (0x7F, 0x09, 0x09, 0x09, 0x01),
    'G': (0x3E, 0x41, 0x49, 0x49, 0x7A), 'H': (0x7F, 0x08, 0x08, 0x08, 0x7F),
    'I': (0x00, 0x41, 0x7F, 0x41, 0x00), 'J': (0x20, 0x40, 0x41, 0x3F, 0x01),
    'K': (0x7F, 0x08, 0x14, 0x22, 0x41), 'L': (0x7F, 0x40, 0x40, 0x40, 0x40),
    'M': (0x7F, 0x02, 0x0C, 0x02, 0x7F), 'N': (0x7F, 0x04, 0x08, 0x10, 0x7F),
    'O': (0x3E, 0x41, 0x41, 0x41, 0x3E), 'P': (0x7F, 0x09, 0x09, 0x09, 0x06),
    'Q': (0x3E, 0x41, 0x51, 0x21, 0x5E), 'R': (0x7F, 0x09, 0x19, 0x29, 0x46),
    'S': (0x46, 0x49, 0x49, 0x49, 0x31), 'T': (0x01, 0x01, 0x7F, 0x01, 0x01),
    'U': (0x3F, 0x40, 0x40, 0x40, 0x3F), 'V': (0x1F, 0x20, 0x40, 0x20, 0x1F),
    'W': (0x3F, 0x40, 0x38, 0x40, 0x3F), 'X': (0x63, 0x14, 0x08, 0x14, 0x63),
    'Y': (0x07, 0x08, 0x70, 0x08, 0x07), 'Z': (0x61, 0x51, 0x49, 0x45, 0x43),
    '0': (0x3E, 0x51, 0x49, 0x45, 0x3E), '1': (0x00, 0x42, 0x7F, 0x40, 0x00),
    '2': (0x42, 0x61, 0x51, 0x49, 0x46), '3': (0x21, 0x41, 0x45, 0x4B, 0x31),
    '4': (0x18, 0x14, 0x12, 0x7F, 0x10), '5': (0x27, 0x45, 0x45, 0x45, 0x39),
    '6': (0x3C, 0x4A, 0x49, 0x49, 0x30), '7': (0x01, 0x71, 0x09, 0x05, 0x03),
    '8': (0x36, 0x49, 0x49, 0x49, 0x36), '9': (0x06, 0x49, 0x49, 0x29, 0x1E),
})


def _ascii(value):
    value = str(value or '').upper()
    value = value.replace('_', ' ')
    value = re.sub(r'[^A-Z0-9 %:/.-]', '', value)
    return value


def screen_lines(exercise_code='', exercise_state='', completed=0,
                 target=0, battery_percent=-1.0):
    """Return four short ASCII lines suitable for a 128x64 OLED."""
    code = _ascii(exercise_code) or 'CHUA CHON BAI'
    state = _ascii(exercise_state) or 'SAN SANG'
    if len(code) > 18:
        code = code[:18]
    if len(state) > 18:
        state = state[:18]
    battery = '--' if battery_percent < 0 else str(max(0, min(100, round(battery_percent))))
    reps = f'{max(0, completed)}/{max(0, target)}' if target else str(max(0, completed))
    return [f'BAI: {code}', f'TRANG THAI: {state}', f'LAN: {reps}', f'PIN: {battery}%']


class Ssd1306:
    WIDTH = 128
    HEIGHT = 64
    _CONTROL = 0x00
    _DATA = 0x40

    def __init__(self, bus_number, address):
        from smbus2 import SMBus
        self._bus = SMBus(bus_number)
        self._address = address
        self._lock = threading.Lock()

    def _command(self, *commands):
        self._bus.write_i2c_block_data(self._address, self._CONTROL, list(commands))

    def init(self):
        self._command(0xAE, 0xD5, 0x80, 0xA8, 0x3F, 0xD3, 0x00, 0x40,
                      0x8D, 0x14, 0x20, 0x00, 0xA1, 0xC8, 0xDA, 0x12,
                      0x81, 0x7F, 0xD9, 0xF1, 0xDB, 0x40, 0xA4, 0xA6, 0xAF)

    def draw(self, lines):
        buffer = bytearray(self.WIDTH * self.HEIGHT // 8)
        for row, line in enumerate(lines[:4]):
            x = 0
            for char in line[:21]:
                glyph = FONT.get(char, FONT[' '])
                for column, bits in enumerate(glyph):
                    if x + column < self.WIDTH:
                        buffer[row * self.WIDTH * 2 + x + column] = bits
                x += 6
        with self._lock:
            self._command(0x21, 0, self.WIDTH - 1, 0x22, 0, self.HEIGHT // 8 - 1)
            for start in range(0, len(buffer), 16):
                self._bus.write_i2c_block_data(self._address, self._DATA,
                                               list(buffer[start:start + 16]))

    def close(self):
        self._bus.close()


class OledDisplay(Node):
    def __init__(self):
        super().__init__('oled_display')
        self.declare_parameter('i2c_bus', 1)
        self.declare_parameter('i2c_address', 0x3C)
        self.declare_parameter('refresh_sec', 1.0)
        self._battery = -1.0
        self._exercise = {}
        self._display = None
        self._last_error = 0.0
        self.create_subscription(DeviceState, '/exo/state', self._on_state, 10)
        self.create_subscription(ExerciseStatus, '/exo/exercise/status', self._on_exercise, 10)
        self.create_timer(float(self.get_parameter('refresh_sec').value), self._refresh)

    def _on_state(self, message):
        self._battery = float(message.battery_percent)

    def _on_exercise(self, message):
        self._exercise = {
            'code': message.exercise_code,
            'state': message.state,
            'completed': message.total_repetitions or message.completed_repetitions,
            'target': message.target_total_repetitions or message.target_repetitions,
        }

    def _refresh(self):
        if self._display is None:
            try:
                self._display = Ssd1306(int(self.get_parameter('i2c_bus').value),
                                        int(self.get_parameter('i2c_address').value))
                self._display.init()
                self.get_logger().info('OLED ready on I2C bus 1 address 0x3c')
            except Exception as error:
                if time.monotonic() - self._last_error > 10:
                    self.get_logger().warning(f'OLED unavailable: {error}')
                    self._last_error = time.monotonic()
                return
        try:
            lines = screen_lines(self._exercise.get('code'), self._exercise.get('state'),
                                 self._exercise.get('completed', 0), self._exercise.get('target', 0),
                                 self._battery)
            self._display.draw(lines)
        except Exception as error:
            self.get_logger().warning(f'OLED write failed: {error}')
            self._display.close()
            self._display = None

    def destroy_node(self):
        if self._display is not None:
            self._display.close()
        return super().destroy_node()


def main():
    rclpy.init()
    node = OledDisplay()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
