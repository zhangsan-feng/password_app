class AppLayout {
  static const double desktopBreakpoint = 900;
  static const double desktopMinWidth = 420;
  static const double desktopMinHeight = 640;

  static bool isDesktopWidth(double width) => width >= desktopBreakpoint;
}
