import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/app/app.dart';
import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/reading/presentation/reading_setup_view.dart';
import 'package:maltto/src/features/reading/presentation/reading_setup_view_model.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';

void main() {
  testWidgets('목록에서 선택한 대본과 기본 반복 1회를 시작 설정에 전달한다', (tester) async {
    final scriptRepository = _ScriptRepository();
    final readingRepository = _ReadingRepository();
    final semantics = tester.ensureSemantics();
    addTearDown(() async {
      await scriptRepository.close();
      await readingRepository.dispose();
    });

    await tester.pumpWidget(_buildApp(scriptRepository, readingRepository));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('대본 ${_script.title} 선택'), findsOneWidget);
    await tester.tap(find.text(_script.title));
    await tester.pumpAndSettle();

    expect(find.text('낭독 시작'), findsOneWidget);
    expect(find.byKey(const Key('reading-setup-script-title')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '반복 횟수, 1회 선택됨',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reading-setup-start-button')));
    await tester.pumpAndSettle();

    expect(readingRepository.startedScript, same(_script));
    expect(readingRepository.startedRepetitions, 1);
    expect(find.byKey(const Key('reading-current-word')), findsOneWidget);
    expect(find.byKey(const Key('reading-repetition-status')), findsNothing);
    semantics.dispose();
  });

  testWidgets('반복 횟수를 선택하면 여러 회에서만 현재/전체 회차를 표시한다', (tester) async {
    final scriptRepository = _ScriptRepository();
    final readingRepository = _ReadingRepository();
    addTearDown(() async {
      await scriptRepository.close();
      await readingRepository.dispose();
    });

    await tester.pumpWidget(_buildApp(scriptRepository, readingRepository));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_script.title));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(
      find.byKey(const Key('reading-repetition-picker')),
    );
    picker.onSelectedItemChanged!(2);
    await tester.pump();
    await tester.tap(find.byKey(const Key('reading-setup-start-button')));
    await tester.pumpAndSettle();

    expect(readingRepository.startedRepetitions, 3);
    expect(find.text('1/3회 · 2회 남음'), findsOneWidget);
    expect(find.byKey(const Key('reading-repetition-status')), findsOneWidget);
  });

  testWidgets('Accessibility XL에서 시작 설정과 주요 조작이 잘리지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final readingRepository = _ReadingRepository();
    addTearDown(readingRepository.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: ReadingSetupView(
          viewModel: ReadingSetupViewModel(
            script: _script,
            repository: readingRepository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final picker = tester.widget<CupertinoPicker>(
      find.byKey(const Key('reading-repetition-picker')),
    );
    expect(picker.itemExtent, greaterThan(48));
    for (final key in [
      const Key('reading-setup-cancel-button'),
      const Key('reading-setup-start-button'),
    ]) {
      final button = find.byKey(key);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('모델 준비 중이면 상태를 안내하고 낭독 화면을 열지 않는다', (tester) async {
    final readingRepository = _ReadingRepository(
      startException: const ReadingSessionStartException(
        SttPreparation(status: SttPreparationStatus.modelDownloading),
      ),
    );
    addTearDown(readingRepository.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: ReadingSetupView(
          viewModel: ReadingSetupViewModel(
            script: _script,
            repository: readingRepository,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reading-setup-start-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reading-setup-start-status')), findsOneWidget);
    expect(find.textContaining('한국어 음성 모델을 준비 중'), findsOneWidget);
    expect(find.byKey(const Key('reading-current-word')), findsNothing);
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const Key('reading-setup-start-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('시작 준비 중 백그라운드 전환은 시작 요청을 취소한다', (tester) async {
    final startBarrier = Completer<void>();
    final readingRepository = _ReadingRepository(startBarrier: startBarrier);
    addTearDown(() async {
      if (!startBarrier.isCompleted) startBarrier.complete();
      await readingRepository.dispose();
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: ReadingSetupView(
          viewModel: ReadingSetupViewModel(
            script: _script,
            repository: readingRepository,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('reading-setup-start-button')));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(readingRepository.leaveCallCount, 1);

    startBarrier.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading-current-word')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}

Widget _buildApp(
  _ScriptRepository scriptRepository,
  _ReadingRepository readingRepository,
) {
  return MalttoApp(
    scriptListViewModel: ScriptListViewModel(scriptRepository),
    createScriptViewModel: () => ScriptCreateViewModel(scriptRepository),
    readingSetupBuilder: (script) => ReadingSetupView(
      viewModel: ReadingSetupViewModel(
        script: script,
        repository: readingRepository,
      ),
    ),
  );
}

final _script = Script(
  id: 1,
  title: '아침 낭독',
  body: '아침에는 창문을 열고 문장을 읽는다',
  createdAt: DateTime.utc(2026, 11, 2),
  updatedAt: DateTime.utc(2026, 11, 2),
);

final class _ScriptRepository implements ScriptRepository {
  final StreamController<List<Script>> _controller =
      StreamController<List<Script>>.broadcast();

  Future<void> close() => _controller.close();

  @override
  Stream<List<Script>> watchAll() async* {
    yield [_script];
    yield* _controller.stream;
  }

  @override
  Future<List<Script>> getAll() async => [_script];

  @override
  Future<Script> create({required String title, required String body}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

final class _ReadingRepository implements ReadingSessionRepository {
  _ReadingRepository({this.startException, this.startBarrier});

  final ReadingSessionStartException? startException;
  final Completer<void>? startBarrier;
  final StreamController<ReadingSessionState> _controller =
      StreamController<ReadingSessionState>.broadcast(sync: true);

  Script? startedScript;
  int? startedRepetitions;
  int leaveCallCount = 0;
  ReadingSessionState? _state;
  bool _disposed = false;

  @override
  ReadingSessionState? get state => _state;

  @override
  Stream<ReadingSessionState> get states => _controller.stream;

  @override
  Future<ReadingSessionState> start({
    required Script script,
    required int repetitions,
  }) async {
    await startBarrier?.future;
    if (leaveCallCount > 0) throw StateError('시작 취소');
    final startException = this.startException;
    if (startException != null) throw startException;
    startedScript = script;
    startedRepetitions = repetitions;
    _state = ReadingSessionState(
      sessionId: 'widget-session',
      scriptTitle: script.title,
      status: ReadingSessionStatus.running,
      currentRepetition: 1,
      totalRepetitions: repetitions,
      currentWordIndex: 0,
      currentWord: '아침에는',
      words: const ['아침에는', '창문을', '열고', '문장을', '읽는다'],
      totalWords: 5,
      elapsed: Duration.zero,
      generation: 1,
    );
    return _state!;
  }

  @override
  Future<void> leave() async {
    if (_disposed) return;
    leaveCallCount++;
    final current = _state;
    if (current == null || current.status != ReadingSessionStatus.running) {
      return;
    }
    _state = ReadingSessionState(
      sessionId: current.sessionId,
      scriptTitle: current.scriptTitle,
      status: ReadingSessionStatus.exited,
      currentRepetition: current.currentRepetition,
      totalRepetitions: current.totalRepetitions,
      currentWordIndex: current.currentWordIndex,
      currentWord: current.currentWord,
      words: current.words,
      totalWords: current.totalWords,
      elapsed: current.elapsed,
      generation: current.generation + 1,
    );
    _controller.add(_state!);
  }

  @override
  Future<void> moveBackOneWord() async {}

  @override
  Future<void> continueNextRepetition() async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }
}
