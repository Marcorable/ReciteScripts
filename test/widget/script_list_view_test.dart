import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/app/app.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';

void main() {
  testWidgets('빈 상태에서 대본을 추가하고 목록에서 삭제한다', (tester) async {
    final repository = _WidgetScriptRepository();
    await tester.pumpWidget(_buildApp(repository));
    await tester.pump();

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('저장된 대본이 없습니다.'), findsOneWidget);
    expect(find.text('대본 추가'), findsOneWidget);
    final emptyAddButton = find.ancestor(
      of: find.text('대본 추가'),
      matching: find.byType(CupertinoButton),
    );
    expect(
      tester.getSize(emptyAddButton.first).width,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(emptyAddButton.first).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('대본 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('script-title-field')),
      '발표 준비',
    );
    await tester.enterText(
      find.byKey(const Key('script-body-field')),
      '직접 작성한 문장을 천천히 읽습니다.',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('발표 준비'), findsOneWidget);
    expect(repository.scripts.single.body, '직접 작성한 문장을 천천히 읽습니다.');

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('대본을 삭제할까요?'), findsOneWidget);
    expect(find.text('“발표 준비” 대본을 기기에서 삭제합니다.'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('저장된 대본이 없습니다.'), findsOneWidget);
    expect(repository.scripts, isEmpty);
  });

  testWidgets('빈 제목과 공백뿐인 본문을 같은 화면에서 안내한다', (tester) async {
    final repository = _WidgetScriptRepository();
    await tester.pumpWidget(_buildApp(repository));
    await tester.pump();
    await tester.tap(find.text('대본 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('script-title-field')), '   ');
    await tester.enterText(find.byKey(const Key('script-body-field')), '\n\t ');
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('제목을 입력하세요.'), findsOneWidget);
    expect(find.text('본문을 입력하세요.'), findsOneWidget);
    expect(find.byKey(const Key('script-title-field')), findsOneWidget);
    expect(repository.scripts, isEmpty);
  });

  testWidgets('저장 실패 시 추가 화면을 유지하고 다시 시도 안내를 표시한다', (tester) async {
    final repository = _WidgetScriptRepository(failCreate: true);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pump();
    await tester.tap(find.text('대본 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('script-title-field')),
      '연습 제목',
    );
    await tester.enterText(
      find.byKey(const Key('script-body-field')),
      '직접 작성한 문장을 읽습니다.',
    );
    await tester.tap(find.byKey(const Key('script-create-save-button')));
    await tester.pump();

    expect(find.text('저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('script-title-field')), findsOneWidget);
    expect(repository.scripts, isEmpty);
  });

  testWidgets('Android 내비게이션 조작의 실제 터치 영역이 48 이상이다', (tester) async {
    final repository = _WidgetScriptRepository();
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    final listAddButton = find.byKey(const Key('script-list-add-button'));
    expect(tester.getSize(listAddButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(listAddButton).height, greaterThanOrEqualTo(48));

    await tester.tap(listAddButton);
    await tester.pumpAndSettle();
    for (final key in [
      const Key('script-create-cancel-button'),
      const Key('script-create-save-button'),
    ]) {
      final button = find.byKey(key);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('큰 글씨에서 긴 제목이 줄바꿈되고 주요 터치 영역이 48 이상이다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _WidgetScriptRepository(
      initialScripts: [
        _script(
          id: 1,
          title: '여러 줄로 표시되는 직접 작성한 매우 긴 대본 제목',
          body: '직접 작성한 긴 본문을 화면에서 확인합니다.',
        ),
      ],
    );
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('대본 여러 줄로 표시되는 직접 작성한 매우 긴 대본 제목 삭제'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byIcon(CupertinoIcons.delete)).width,
      lessThan(48),
    );
    final deleteButton = find.ancestor(
      of: find.byIcon(CupertinoIcons.delete),
      matching: find.byType(CupertinoButton),
    );
    expect(tester.getSize(deleteButton.first).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(deleteButton.first).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });
}

Widget _buildApp(_WidgetScriptRepository repository) {
  return MalttoApp(
    scriptListViewModel: ScriptListViewModel(repository),
    createScriptViewModel: () => ScriptCreateViewModel(repository),
    readingSetupBuilder: (_) => const SizedBox.shrink(),
  );
}

Script _script({required int id, required String title, required String body}) {
  final now = DateTime.utc(2026, 10, 31);
  return Script(
    id: id,
    title: title,
    body: body,
    createdAt: now,
    updatedAt: now,
  );
}

final class _WidgetScriptRepository implements ScriptRepository {
  _WidgetScriptRepository({
    List<Script> initialScripts = const [],
    this.failCreate = false,
  }) : scripts = [...initialScripts];

  final _controller = StreamController<List<Script>>.broadcast();
  final List<Script> scripts;
  final bool failCreate;
  int _nextId = 1;

  @override
  Stream<List<Script>> watchAll() async* {
    yield List.unmodifiable(scripts);
    yield* _controller.stream;
  }

  @override
  Future<List<Script>> getAll() async => List.unmodifiable(scripts);

  @override
  Future<Script> create({required String title, required String body}) async {
    if (failCreate) throw StateError('저장 실패');
    final script = _script(id: _nextId++, title: title, body: body);
    scripts.insert(0, script);
    _controller.add(List.unmodifiable(scripts));
    return script;
  }

  @override
  Future<void> delete(int id) async {
    scripts.removeWhere((script) => script.id == id);
    _controller.add(List.unmodifiable(scripts));
  }
}
