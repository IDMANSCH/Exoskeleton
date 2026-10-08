from exo_gateway.oled_display import screen_lines


def test_screen_lines_show_exercise_repetitions_and_battery():
    assert screen_lines('raise_left_leg', 'running', 3, 10, 78.4) == [
        'BAI: RAISE LEFT LEG', 'TRANG THAI: RUNNING', 'LAN: 3/10', 'PIN: 78%']


def test_screen_lines_use_safe_defaults_without_telemetry():
    assert screen_lines('', '', 0, 0, -1) == [
        'BAI: CHUA CHON BAI', 'TRANG THAI: SAN SANG', 'LAN: 0', 'PIN: --%']
