class AppLayout {
  static const double desktopBreakpoint = 900;
  static const double desktopWindowWidth = 460;
  static const double desktopWindowHeight = 720;
  static const double desktopMinWidth = desktopWindowWidth;
  static const double desktopMinHeight = desktopWindowHeight;
  static const double navigationWidth = 50;

  static bool isDesktopWidth(double width) => width >= desktopBreakpoint;
}
