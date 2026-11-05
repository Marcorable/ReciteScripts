import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/presentation/reading_view.dart';
import 'package:maltto/src/features/reading/presentation/reading_view_model.dart';
import 'package:maltto/src/features/scripts/model/script.dart';

void main() {
  testWidgets('완료 현재 대기 어절을 구분하고 Repository 상태로만 전진한다', (tester) async {
    final repository = _ReadingRepository(_state(currentWordIndex: 1));
    final semantics = tester.ensureSemantics();
    await _pumpView(tester, repository);

    expect(find.bySemanticsLabel('완료한 어절, 오늘'), findsOneWidget);
    expect(find.bySemanticsLabel('현재 어절, 읽을'), findsOneWidget);
    expect(find.bySemanticsLabel('대기 중인 어절, 문장을'), findsOneWidget);

    await tester.tap(find.text('문장을'));
    await tester.pump();
    expect(repository.state?.currentWordIndex, 1);
    expect(repository.moveBackCallCount, 0);

    repository.emit(_state(currentWordIndex: 3, generation: 1));
    await tester.pump();
    expect(find.bySemanticsLabel('현재 어절, 천천히'), findsOneWidget);
    expect(find.bySemanticsLabel('완료한 어절, 문장을'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('1회는 회차를 숨기고 여러 회는 회차와 안정된 경과 시간을 알린다', (tester) async {
    final repository = _ReadingRepository(
      _state(
        currentWordIndex: 2,
        currentRepetition: 2,
        totalRepetitions: 3,
        elapsed: const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
    );
    final semantics = tester.ensureSemantics();
    await _pumpView(tester, repository);

    expect(find.text('2/3회 · 1회 남음'), findsOneWidget);
    expect(find.bySemanticsLabel('현재 2회차, 전체 3회, 1회 남음'), findsOneWidget);
    expect(find.text('01:02:03'), findsOneWidget);
    expect(find.bySemanticsLabel('경과 시간, 1시간 2분 3초'), findsOneWidget);

    repository.emit(
      _state(
        currentWordIndex: 2,
        totalRepetitions: 1,
        elapsed: const Duration(seconds: 4),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('reading-repetition-status')), findsNothing);
    expect(find.text('00:04'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('한 어절 뒤로는 정확히 하나만 이동하고 첫 어절에서 비활성화된다', (tester) async {
    final repository = _ReadingRepository(_state(currentWordIndex: 2));
    final semantics = tester.ensureSemantics();
    await _pumpView(tester, repository);

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('한 어절 뒤로'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('낭독 나가기'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('reading-move-back-button')));
    await tester.pump();
    expect(repository.state?.currentWordIndex, 1);
    expect(repository.moveBackCallCount, 1);
    expect(find.bySemanticsLabel('현재 어절, 읽을'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reading-move-back-button')));
    await tester.pump();
    expect(repository.state?.currentWordIndex, 0);
    expect(repository.moveBackCallCount, 2);

    final button = tester.widget<CupertinoButton>(
      find.byKey(const Key('reading-move-back-button')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.bySemanticsLabel('한 어절 뒤로, 첫 어절에서는 더 이상 이동할 수 없음'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('진행된 낭독의 나가기는 확인 후 종료하고 취소하면 계속한다', (tester) async {
    final repository = _ReadingRepository(_state(currentWordIndex: 2));
    await _pumpView(tester, repository);

    await tester.tap(find.byKey(const Key('reading-leave-button')));
    await tester.pumpAndSettle();
    expect(find.text('낭독을 종료할까요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reading-leave-cancel-button')));
    await tester.pumpAndSettle();
    expect(repository.leaveCallCount, 0);
    expect(find.byKey(const Key('reading-current-word')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reading-leave-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reading-leave-confirm-button')));
    await tester.pumpAndSettle();
    expect(repository.leaveCallCount, 1);
    expect(repository.state?.status, ReadingSessionStatus.exited);
    expect(find.text('낭독 종료'), findsOneWidget);
  });

  testWidgets('첫 어절의 나가기는 확인 없이 즉시 종료한다', (tester) async {
    final repository = _ReadingRepository(_state());
    await _pumpView(tester, repository);

    await tester.tap(find.byKey(const Key('reading-leave-button')));
    await tester.pumpAndSettle();

    expect(find.text('낭독을 종료할까요?'), findsNothing);
    expect(repository.leaveCallCount, 1);
    expect(repository.state?.status, ReadingSessionStatus.exited);
  });

  testWidgets('복구 불가 STT 오류는 원인과 안전한 목록 복귀를 알린다', (tester) async {
    final repository = _ReadingRepository(
      _state(
        status: ReadingSessionStatus.exited,
        failure: ReadingSessionFailure.audioUnavailable,
        generation: 2,
      ),
    );
    final semantics = tester.ensureSemantics();
    await _pumpView(tester, repository);

    expect(find.text('음성 인식을 계속할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('오디오 충돌'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('음성 인식 오류.*오디오 충돌')), findsOneWidget);
    expect(
      find.byKey(const Key('reading-exited-return-button')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('회차 완료는 중앙 확인창에서 이어하기 전까지 다음 STT를 대기한다', (tester) async {
    final repository = _ReadingRepository(
      _state(currentWordIndex: 3, totalRepetitions: 2),
    );
    await _pumpView(tester, repository);

    repository.emit(
      _state(
        status: ReadingSessionStatus.awaitingNextRepetition,
        currentRepetition: 2,
        totalRepetitions: 2,
        generation: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1회 낭독 완료'), findsOneWidget);
    expect(find.text('2/2회를 이어서 낭독할까요?'), findsOneWidget);
    expect(repository.continueCallCount, 0);

    await tester.tap(
      find.byKey(const Key('reading-repetition-continue-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.continueCallCount, 1);
    expect(repository.state?.status, ReadingSessionStatus.running);
    expect(find.text('1회 낭독 완료'), findsNothing);
    expect(find.bySemanticsLabel('현재 어절, 오늘'), findsOneWidget);
  });

  testWidgets('회차 완료에서 그만하기는 세션을 종료하고 목록으로 돌아간다', (tester) async {
    final repository = _ReadingRepository(
      _state(currentWordIndex: 3, totalRepetitions: 3),
    );
    await _pumpView(tester, repository);

    repository.emit(
      _state(
        status: ReadingSessionStatus.awaitingNextRepetition,
        currentRepetition: 2,
        totalRepetitions: 3,
        generation: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reading-repetition-stop-button')));
    await tester.pumpAndSettle();

    expect(repository.continueCallCount, 0);
    expect(repository.leaveCallCount, 1);
    expect(repository.state?.status, ReadingSessionStatus.exited);
  });

  testWidgets('최종 STT 완료 상태는 늦은 실행 상태를 무시하고 목록 복귀를 제공한다', (tester) async {
    final repository = _ReadingRepository(_state(currentWordIndex: 3));
    await _pumpView(tester, repository);

    repository.emit(
      _state(
        status: ReadingSessionStatus.completed,
        currentWordIndex: null,
        elapsed: const Duration(seconds: 12),
        generation: 2,
      ),
    );
    await tester.pump();
    repository.emit(_state(currentWordIndex: 1, generation: 1));
    await tester.pump();

    expect(find.text('완료'), findsOneWidget);
    expect(find.text('1회 낭독했습니다.'), findsOneWidget);
    expect(find.text('00:12'), findsOneWidget);
    expect(
      find.byKey(const Key('reading-completed-return-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reading-current-word')), findsNothing);
  });

  testWidgets('긴 대본은 현재 어절이 바뀔 때 읽을 수 있는 위치로 자동 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final words = List<String>.generate(45, (index) => '연습어절$index');
    final repository = _ReadingRepository(_state(words: words));
    await _pumpView(tester, repository);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reading-script-scroll')),
    );
    expect(scroll.controller?.offset, 0);

    repository.emit(_state(words: words, currentWordIndex: 40));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scroll.controller?.offset, greaterThan(0));
    expect(find.text('연습어절40'), findsOneWidget);
  });

  testWidgets('Reduce Motion에서는 어절 상태와 자동 스크롤 애니메이션을 제거한다', (tester) async {
    final words = List<String>.generate(45, (index) => '차분한문장$index');
    final repository = _ReadingRepository(_state(words: words));
    await _pumpView(tester, repository, disableAnimations: true);

    repository.emit(_state(words: words, currentWordIndex: 40));
    await tester.pump();

    final currentContainer = tester.widget<AnimatedContainer>(
      find.byKey(const Key('reading-current-word')),
    );
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('reading-script-scroll')),
    );
    expect(currentContainer.duration, Duration.zero);
    expect(scroll.controller?.offset, greaterThan(0));
  });

  testWidgets('Accessibility XL에서도 현재 어절과 하단 조작의 최소 크기를 유지한다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _ReadingRepository(_state(currentWordIndex: 2));
    await _pumpView(tester, repository);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('reading-current-word')), findsOneWidget);
    for (final key in [
      const Key('reading-move-back-button'),
      const Key('reading-leave-button'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _ReadingRepository repository, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: ReadingView(
            viewModel: ReadingViewModel(
              repository: repository,
              initialState: repository.state!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  addTearDown(repository.dispose);
}

ReadingSessionState _state({
  ReadingSessionStatus status = ReadingSessionStatus.running,
  int currentRepetition = 1,
  int totalRepetitions = 1,
  Object? currentWordIndex = 0,
  List<String> words = const ['오늘', '읽을', '문장을', '천천히', '말합니다'],
  Duration elapsed = Duration.zero,
  int generation = 1,
  ReadingSessionFailure? failure,
}) {
  final index = currentWordIndex as int?;
  return ReadingSessionState(
    sessionId: 'widget-reading-session',
    scriptTitle: '차분한 낭독',
    status: status,
    currentRepetition: currentRepetition,
    totalRepetitions: totalRepetitions,
    currentWordIndex: index,
    currentWord: index == null ? null : words[index],
    words: words,
    totalWords: words.length,
    elapsed: elapsed,
    generation: generation,
    failure: failure,
  );
}

final class _ReadingRepository implements ReadingSessionRepository {
  _ReadingRepository(this._state);

  final StreamController<ReadingSessionState> _controller =
      StreamController<ReadingSessionState>.broadcast(sync: true);
  ReadingSessionState _state;
  int moveBackCallCount = 0;
  int continueCallCount = 0;
  int leaveCallCount = 0;
  bool _disposed = false;

  @override
  ReadingSessionState? get state => _state;

  @override
  Stream<ReadingSessionState> get states => _controller.stream;

  void emit(ReadingSessionState state) {
    if (state.sessionId != _state.sessionId ||
        state.generation < _state.generation ||
        _state.status != ReadingSessionStatus.running) {
      return;
    }
    _state = state;
    _controller.add(state);
  }

  @override
  Future<void> moveBackOneWord() async {
    if (_disposed) return;
    moveBackCallCount++;
    final index = _state.currentWordIndex ?? 0;
    if (_state.status != ReadingSessionStatus.running || index == 0) return;
    _state = _copyState(
      _state,
      currentWordIndex: index - 1,
      generation: _state.generation + 1,
    );
    _controller.add(_state);
  }

  @override
  Future<void> continueNextRepetition() async {
    if (_disposed ||
        _state.status != ReadingSessionStatus.awaitingNextRepetition) {
      return;
    }
    continueCallCount++;
    _state = _copyState(_state, status: ReadingSessionStatus.running);
    _controller.add(_state);
  }

  @override
  Future<bool> openAppSettings() => throw UnimplementedError();

  @override
  Future<void> leave() async {
    if (_disposed) return;
    if (_state.status == ReadingSessionStatus.completed ||
        _state.status == ReadingSessionStatus.exited) {
      return;
    }
    leaveCallCount++;
    _state = _copyState(
      _state,
      status: ReadingSessionStatus.exited,
      generation: _state.generation + 1,
    );
    _controller.add(_state);
  }

  @override
  Future<ReadingSessionState> start({
    required Script script,
    required int repetitions,
  }) async => _state;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }
}

ReadingSessionState _copyState(
  ReadingSessionState state, {
  ReadingSessionStatus? status,
  int? currentWordIndex,
  int? generation,
  ReadingSessionFailure? failure,
}) => ReadingSessionState(
  sessionId: state.sessionId,
  scriptTitle: state.scriptTitle,
  status: status ?? state.status,
  currentRepetition: state.currentRepetition,
  totalRepetitions: state.totalRepetitions,
  currentWordIndex: currentWordIndex ?? state.currentWordIndex,
  currentWord: state.words[currentWordIndex ?? state.currentWordIndex!],
  words: state.words,
  totalWords: state.totalWords,
  elapsed: state.elapsed,
  generation: generation ?? state.generation,
  failure: failure ?? state.failure,
);
