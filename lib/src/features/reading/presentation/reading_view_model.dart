import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';

final class ReadingViewModel extends ChangeNotifier {
  ReadingViewModel({
    required ReadingSessionRepository repository,
    required ReadingSessionState initialState,
  }) : _repository = repository,
       _state = initialState {
    _subscription = repository.states.listen((state) {
      if (_disposed || state.sessionId != _state.sessionId) return;
      _state = state;
      notifyListeners();
    });
  }

  final ReadingSessionRepository _repository;
  late final StreamSubscription<ReadingSessionState> _subscription;
  ReadingSessionState _state;
  bool _disposed = false;

  ReadingSessionState get state => _state;

  Future<void> moveBackOneWord() => _repository.moveBackOneWord();

  Future<void> continueNextRepetition() => _repository.continueNextRepetition();

  Future<void> leave() => _repository.leave();

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_repository.leave());
    super.dispose();
  }
}
