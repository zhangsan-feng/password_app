import 'package:flutter_test/flutter_test.dart';

import 'package:password_app/services/app_layout.dart';

void main() {
  test('uses a compact bottom navigation bar on every platform', () {
    expect(AppLayout.navigationHeight, 50);
    expect(AppLayout.desktopWindowWidth, 460);
    expect(AppLayout.desktopWindowHeight, 720);
  });
}
