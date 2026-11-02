import 'dart:async';

abstract interface class ReadingSessionTimer {
  bool get isActive;

  void cancel();
}

typedef ReadingSessionTimerFactory = ReadingSessionTimer Function(
  void Function() onTick,
);

ReadingSessionTimer createReadingSessionTimer(void Function() onTick) =>
    _DartReadingSessionTimer(onTick);

final class _DartReadingSessionTimer implements ReadingSessionTimer {
  _DartReadingSessionTimer(void Function() onTick)
    : _timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();
}
