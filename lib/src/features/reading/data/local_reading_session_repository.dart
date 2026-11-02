import 'dart:async';

import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/data/reading_session_timer.dart';
import 'package:maltto/src/features/reading/domain/reading_progress.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/domain/reading_session_reducer.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';
import 'package:maltto/src/infrastructure/stt/stt_service.dart';

typedef ReadingSessionClock = DateTime Function();

final class LocalReadingSessionRepository implements ReadingSessionRepository {
  LocalReadingSessionRepository(
    this._sttService, {
    ReadingSessionTimerFactory? timerFactory,
    ReadingSessionClock? clock,
  }) : _timerFactory = timerFactory ?? createReadingSessionTimer,
       _clock = clock ?? DateTime.now;

  static const _locale = 'ko-KR';

  final SttService _sttService;
  final ReadingSessionTimerFactory _timerFactory;
  final ReadingSessionClock _clock;
  final StreamController<ReadingSessionState> _states =
      StreamController<ReadingSessionState>.broadcast(sync: true);

  ReadingSessionReducer? _reducer;
  StreamSubscription<SttEvent>? _sttSubscription;
  ReadingSessionTimer? _timer;
  DateTime? _startedAt;
  Future<void> _resourceOperation = Future.value();
  int _nextSessionId = 1;
  bool _isStarting = false;
  bool _disposed = false;

  @override
  ReadingSessionState? get state => _reducer?.state;

  @override
  Stream<ReadingSessionState> get states => _states.stream;

  @override
  Future<ReadingSessionState> start({
    required Script script,
    required int repetitions,
  }) async {
    _ensureActive();
    if (_isStarting) throw StateError('낭독 세션을 시작하고 있습니다.');
    if (_reducer?.state.status == ReadingSessionStatus.running) {
      throw StateError('이미 실행 중인 낭독 세션이 있습니다.');
    }
    _isStarting = true;
    try {
      await _resourceOperation;

      final preparation = await _prepareStt();
      _ensureActive();
      if (preparation.status != SttPreparationStatus.ready) {
        throw ReadingSessionStartException(preparation);
      }

      final reducer = ReadingSessionReducer(
        sessionId: 'reading-${_nextSessionId++}',
        scriptTitle: script.title,
        script: script.body,
        totalRepetitions: repetitions,
      );
      _reducer = reducer;
      final initialState = reducer.state;
      _sttSubscription = _sttService
          .events(initialState.sessionId)
          .listen(_handleSttEvent);

      try {
        await _sttService.start(_requestFor(initialState));
        _ensureActive();
      } on Object {
        reducer.exit();
        await _cleanUpActiveResources(initialState.sessionId);
        rethrow;
      }

      _startedAt = _clock();
      _timer = _timerFactory(_updateElapsed);
      _emit();
      return reducer.state;
    } finally {
      _isStarting = false;
    }
  }

  void _handleSttEvent(SttEvent event) {
    final reducer = _reducer;
    if (reducer == null) return;

    if (event.kind == SttEventKind.ended ||
        (event.kind == SttEventKind.failure && event.retryable == true)) {
      _restartRecognition(reducer, event);
      return;
    }

    if (event.kind == SttEventKind.failure) {
      final transition = reducer.exitAfterRecognitionFailure(
        sessionId: event.sessionId,
        generation: event.generation,
        sequence: event.sequence,
      );
      if (transition == ReadingSessionTransition.ignored) return;

      _stopTimer();
      _emit();
      final exitedState = reducer.state;
      _enqueueResourceOperation(
        () => _cleanUpActiveResources(exitedState.sessionId),
      );
      return;
    }

    if (event.kind != SttEventKind.partial &&
        event.kind != SttEventKind.finalResult) {
      return;
    }
    final text = event.text;
    if (text == null || text.isEmpty) return;

    final transition = reducer.acceptTranscript(
      sessionId: event.sessionId,
      generation: event.generation,
      sequence: event.sequence,
      text: text,
      kind: event.kind == SttEventKind.partial
          ? TranscriptKind.partial
          : TranscriptKind.finalResult,
    );
    if (transition == ReadingSessionTransition.ignored) return;

    _emit();
    if (transition == ReadingSessionTransition.repetitionCompleted) {
      final nextState = reducer.state;
      _enqueueResourceOperation(() async {
        await _sttService.cancel(nextState.sessionId);
        final current = _reducer?.state;
        if (current?.status != ReadingSessionStatus.running ||
            current?.generation != nextState.generation) {
          return;
        }
        await _sttService.start(_requestFor(nextState));
      });
    } else if (transition == ReadingSessionTransition.sessionCompleted) {
      _stopTimer();
      final completedState = reducer.state;
      _enqueueResourceOperation(
        () => _cleanUpActiveResources(completedState.sessionId),
      );
    }
  }

  void _restartRecognition(ReadingSessionReducer reducer, SttEvent event) {
    final transition = reducer.restartRecognition(
      sessionId: event.sessionId,
      generation: event.generation,
      sequence: event.sequence,
    );
    if (transition == ReadingSessionTransition.ignored) return;

    final nextState = reducer.state;
    _emit();
    _enqueueResourceOperation(() async {
      final current = _reducer?.state;
      if (current?.status != ReadingSessionStatus.running ||
          current?.generation != nextState.generation) {
        return;
      }
      await _sttService.start(_requestFor(nextState));
    });
  }

  void _updateElapsed() {
    final reducer = _reducer;
    final startedAt = _startedAt;
    if (reducer == null || startedAt == null) return;
    final elapsed = _clock().difference(startedAt);
    if (reducer.updateElapsed(elapsed) != ReadingSessionTransition.ignored) {
      _emit();
    }
  }

  @override
  Future<void> leave() async {
    final reducer = _reducer;
    if (reducer == null) return;

    final transition = reducer.exit();
    if (transition == ReadingSessionTransition.exited) {
      _emit();
    }
    _stopTimer();
    final sessionId = reducer.state.sessionId;
    await _resourceOperation;
    try {
      await _cleanUpActiveResources(sessionId);
    } on Object {
      // 상태는 이미 종료됐다. 정리 오류가 화면 이동과 dispose를 막지 않게 한다.
    }
  }

  void _enqueueResourceOperation(Future<void> Function() operation) {
    _resourceOperation = _resourceOperation.then((_) async {
      try {
        await operation();
      } on Object {
        final reducer = _reducer;
        if (reducer?.exit() == ReadingSessionTransition.exited) {
          _stopTimer();
          _emit();
        }
        final sessionId = reducer?.state.sessionId;
        if (sessionId != null) {
          try {
            await _cleanUpActiveResources(sessionId);
          } on Object {
            // 상태는 이미 종료됐고 모든 정리 경로를 시도했다.
          }
        }
      }
    });
  }

  Future<void> _cleanUpActiveResources(String sessionId) async {
    final subscription = _sttSubscription;
    _sttSubscription = null;
    try {
      await _sttService.cancel(sessionId);
    } finally {
      await subscription?.cancel();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit() {
    if (_disposed || _states.isClosed) return;
    final current = _reducer?.state;
    if (current != null) _states.add(current);
  }

  SttStartRequest _requestFor(ReadingSessionState state) => SttStartRequest(
    sessionId: state.sessionId,
    generation: state.generation,
    locale: _locale,
  );

  Future<SttPreparation> _prepareStt() async {
    final preparation = await _sttService.prepare(locale: _locale);
    if (preparation.status != SttPreparationStatus.modelDownloadRequired) {
      return preparation;
    }
    return _sttService.requestModelDownload(locale: _locale);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await leave();
    await _resourceOperation;
    await _sttService.dispose();
    await _states.close();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('ReadingSessionRepository가 종료되었습니다.');
  }
}
