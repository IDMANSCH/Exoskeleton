import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/presenter/themes/themes/light.dart';

void main() {
  test('light theme can be built', () {
    final themeData = const LightAppTheme().themeData;

    expect(themeData.brightness, const LightAppTheme().brightness);
  });
}
