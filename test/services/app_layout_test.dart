import 'package:flutter_test/flutter_test.dart';

import 'package:password_app/services/app_layout.dart';

void main() {
  test('uses a compact fixed navigation rail on every platform', () {
    expect(AppLayout.navigationWidth, 50);
    expect(AppLayout.desktopWindowWidth, 460);
    expect(AppLayout.desktopWindowHeight, 720);
  });
}
