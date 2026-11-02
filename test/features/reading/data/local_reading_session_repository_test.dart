import 'dart:async';

import 'package:maltto/src/features/reading/data/local_reading_session_repository.dart';
import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/data/reading_session_timer.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';
import 'package:maltto/src/infrastructure/stt/stt_service.dart';
import 'package:test/test.dart';

void main() {
  late _FakeSttService sttService;
  late _FakeTimerFactory timerFactory;
  late DateTime now;
  late LocalReadingSessionRepository repository;

  setUp(() {
    sttService = _FakeSttService();
    timerFactory = _FakeTimerFactory();
    now = DateTime.utc(2026, 11, 2, 9);
    repository = LocalReadingSessionRepository(
      sttService,
      timerFactory: timerFactory.create,
      clock: () => now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await sttService.close();
  });

  test('최종 완료는 STT 작업, 구독, timer를 정확히 한 번 정리한다', () async {
    await repository.start(script: _script, repetitions: 1);
    now = now.add(const Duration(seconds: 3));
    timerFactory.timer.fire();
    expect(repository.state?.elapsed, const Duration(seconds: 3));

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 1,
        kind: SttEventKind.partial,
        text: _body,
      ),
    );
    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 2,
        kind: SttEventKind.finalResult,
        text: _body,
      ),
    );
    await pumpEventQueue(times: 10);

    expect(repository.state?.status, ReadingSessionStatus.completed);
    expect(sttService.cancelledSessionIds, ['reading-1']);
    expect(sttService.subscriptionCancelCount, 1);
    expect(timerFactory.timer.isActive, isFalse);

    now = now.add(const Duration(seconds: 4));
    timerFactory.timer.fire();
    expect(repository.state?.elapsed, const Duration(seconds: 3));
  });

  test('회차 경계에서 이전 작업을 취소한 뒤 새 generation을 시작한다', () async {
    await repository.start(script: _script, repetitions: 2);

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 1,
        kind: SttEventKind.finalResult,
        text: _body,
      ),
    );
    await pumpEventQueue(times: 10);

    expect(repository.state?.currentRepetition, 2);
    expect(repository.state?.currentWord, '아침에는');
    expect(repository.state?.generation, 2);
    expect(sttService.startedGenerations, [1, 2]);
    expect(sttService.cancelledSessionIds, ['reading-1']);

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 2,
        kind: SttEventKind.finalResult,
        text: _body,
      ),
    );
    expect(repository.state?.currentWordIndex, 0);

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 2,
        sequence: 1,
        kind: SttEventKind.partial,
        text: _body,
      ),
    );
    await pumpEventQueue(times: 10);

    expect(repository.state?.status, ReadingSessionStatus.completed);
    expect(sttService.startedGenerations, [1, 2]);
    expect(sttService.cancelledSessionIds, ['reading-1', 'reading-1']);
    expect(sttService.subscriptionCancelCount, 1);
  });

  test('회차 도중 ended 이벤트는 진행 상태를 유지하고 인식을 재시작한다', () async {
    await repository.start(script: _script, repetitions: 2);
    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 1,
        kind: SttEventKind.finalResult,
        text: '아침에는 창문을',
      ),
    );
    final wordIndex = repository.state?.currentWordIndex;

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 2,
        kind: SttEventKind.ended,
      ),
    );
    await pumpEventQueue(times: 10);

    expect(repository.state?.status, ReadingSessionStatus.running);
    expect(repository.state?.currentRepetition, 1);
    expect(repository.state?.currentWordIndex, wordIndex);
    expect(repository.state?.generation, 2);
    expect(sttService.startedGenerations, [1, 2]);
    expect(sttService.cancelledSessionIds, isEmpty);

    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 3,
        kind: SttEventKind.ended,
      ),
    );
    await pumpEventQueue(times: 10);
    expect(sttService.startedGenerations, [1, 2]);
  });

  test('나가기는 취소 완료 전 상태와 generation부터 무효화한다', () async {
    await repository.start(script: _script, repetitions: 3);
    final cancelBarrier = Completer<void>();
    sttService.cancelBarrier = cancelBarrier;

    final leaveFuture = repository.leave();

    expect(repository.state?.status, ReadingSessionStatus.exited);
    expect(repository.state?.generation, 2);
    expect(timerFactory.timer.isActive, isFalse);
    sttService.emit(
      const SttEvent(
        sessionId: 'reading-1',
        generation: 1,
        sequence: 1,
        kind: SttEventKind.finalResult,
        text: _body,
      ),
    );
    expect(repository.state?.currentRepetition, 1);

    cancelBarrier.complete();
    await leaveFuture;

    expect(sttService.cancelledSessionIds, ['reading-1']);
    expect(sttService.subscriptionCancelCount, 1);
  });

  test('모델 설치가 필요하면 다운로드를 요청한 뒤 ready 상태에서 시작한다', () async {
    sttService.preparation = const SttPreparation(
      status: SttPreparationStatus.modelDownloadRequired,
      failureCode: SttFailureCode.modelMissing,
    );
    sttService.modelDownloadPreparation = const SttPreparation(
      status: SttPreparationStatus.ready,
    );

    final state = await repository.start(script: _script, repetitions: 1);

    expect(sttService.modelDownloadRequestCount, 1);
    expect(state.status, ReadingSessionStatus.running);
    expect(sttService.startedGenerations, [1]);
  });

  test('모델 준비 중에는 세션과 STT 작업을 시작하지 않는다', () async {
    sttService.preparation = const SttPreparation(
      status: SttPreparationStatus.modelDownloadRequired,
      failureCode: SttFailureCode.modelMissing,
    );
    sttService.modelDownloadPreparation = const SttPreparation(
      status: SttPreparationStatus.modelDownloading,
    );

    await expectLater(
      repository.start(script: _script, repetitions: 1),
      throwsA(
        isA<ReadingSessionStartException>().having(
          (error) => error.preparation.status,
          'status',
          SttPreparationStatus.modelDownloading,
        ),
      ),
    );

    expect(repository.state, isNull);
    expect(sttService.modelDownloadRequestCount, 1);
    expect(sttService.startedGenerations, isEmpty);
  });
}

const _body = '아침에는 창문을 열고 문장을 읽는다';
final _script = Script(
  id: 1,
  title: '아침 낭독',
  body: _body,
  createdAt: DateTime.utc(2026, 11, 2),
  updatedAt: DateTime.utc(2026, 11, 2),
);

final class _FakeTimerFactory {
  late _FakeTimer timer;

  ReadingSessionTimer create(void Function() onTick) {
    timer = _FakeTimer(onTick);
    return timer;
  }
}

final class _FakeTimer implements ReadingSessionTimer {
  _FakeTimer(this._onTick);

  final void Function() _onTick;

  @override
  bool isActive = true;

  void fire() {
    if (isActive) _onTick();
  }

  @override
  void cancel() => isActive = false;
}

final class _FakeSttService implements SttService {
  _FakeSttService() {
    _events = StreamController<SttEvent>.broadcast(
      sync: true,
      onCancel: () => subscriptionCancelCount++,
    );
  }

  late final StreamController<SttEvent> _events;
  final List<int> startedGenerations = [];
  final List<String> cancelledSessionIds = [];
  int subscriptionCancelCount = 0;
  Completer<void>? cancelBarrier;
  SttPreparation preparation = const SttPreparation(
    status: SttPreparationStatus.ready,
  );
  SttPreparation modelDownloadPreparation = const SttPreparation(
    status: SttPreparationStatus.modelDownloading,
  );
  int modelDownloadRequestCount = 0;

  void emit(SttEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  Future<SttAvailability> checkAvailability({required String locale}) =>
      throw UnimplementedError();

  @override
  Future<SttPreparation> prepare({required String locale}) async => preparation;

  @override
  Future<SttPreparation> requestModelDownload({required String locale}) async {
    modelDownloadRequestCount++;
    return modelDownloadPreparation;
  }

  @override
  Stream<SttEvent> events(String sessionId) => _events.stream;

  @override
  Future<void> start(SttStartRequest request) async {
    startedGenerations.add(request.generation);
  }

  @override
  Future<void> cancel(String sessionId) async {
    cancelledSessionIds.add(sessionId);
    await cancelBarrier?.future;
  }

  @override
  Future<void> dispose() async {}
}
