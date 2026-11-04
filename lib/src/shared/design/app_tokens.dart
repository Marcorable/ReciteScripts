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

abstract final class AppRadii {
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
}

abstract final class AppMotion {
  static const Duration none = Duration.zero;
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration scroll = Duration(milliseconds: 250);
}
