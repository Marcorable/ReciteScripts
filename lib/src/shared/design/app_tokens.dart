import 'package:flutter/cupertino.dart';

abstract final class AppSpacing {
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double section = 32;
}

abstract final class AppTargets {
  static const double preferred = 48;

  static const BoxConstraints preferredConstraints = BoxConstraints(
    minWidth: preferred,
    minHeight: preferred,
  );
}
