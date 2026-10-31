import 'dart:async';

import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_create_view_model.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';
import 'package:test/test.dart';

void main() {
  test('추가 ViewModel은 빈 값과 모든 공백을 거부한다', () async {
    final repository = _FakeScriptRepository();
    final viewModel = ScriptCreateViewModel(repository);
    addTearDown(viewModel.dispose);

    expect(await viewModel.save(title: '', body: '내용'), isFalse);
    expect(viewModel.titleError, '제목을 입력하세요.');
    expect(await viewModel.save(title: '제목', body: ' \n\t'), isFalse);
    expect(viewModel.bodyError, '본문을 입력하세요.');
    expect(repository.createCalls, 0);
  });

  test('추가 ViewModel은 긴 원문을 자르거나 로그용 값으로 변환하지 않는다', () async {
    final repository = _FakeScriptRepository();
    final viewModel = ScriptCreateViewModel(repository);
    addTearDown(viewModel.dispose);
    final longBody = List.filled(5000, '직접 쓴 문장 ').join();

    expect(await viewModel.save(title: '긴 대본', body: longBody), isTrue);

    expect(repository.lastCreatedBody, longBody);
  });

  test('목록 ViewModel은 스트림과 삭제 명령을 반영한다', () async {
    final repository = _FakeScriptRepository();
    final viewModel = ScriptListViewModel(repository);
    addTearDown(viewModel.dispose);
    viewModel.load();
    await pumpEventQueue();

    await repository.create(title: '목록 대본', body: '목록에 표시합니다.');
    await pumpEventQueue();
    expect(viewModel.scripts.single.title, '목록 대본');

    expect(await viewModel.deleteScript(viewModel.scripts.single.id), isTrue);
    await pumpEventQueue();
    expect(viewModel.scripts, isEmpty);
  });
}

final class _FakeScriptRepository implements ScriptRepository {
  final _controller = StreamController<List<Script>>.broadcast();
  final _scripts = <Script>[];
  int createCalls = 0;
  String? lastCreatedBody;

  @override
  Stream<List<Script>> watchAll() async* {
    yield List.unmodifiable(_scripts);
    yield* _controller.stream;
  }

  @override
  Future<List<Script>> getAll() async => List.unmodifiable(_scripts);

  @override
  Future<Script> create({required String title, required String body}) async {
    createCalls += 1;
    lastCreatedBody = body;
    final now = DateTime.utc(2026, 10, 31);
    final script = Script(
      id: createCalls,
      title: title,
      body: body,
      createdAt: now,
      updatedAt: now,
    );
    _scripts.insert(0, script);
    _controller.add(List.unmodifiable(_scripts));
    return script;
  }

  @override
  Future<void> delete(int id) async {
    _scripts.removeWhere((script) => script.id == id);
    _controller.add(List.unmodifiable(_scripts));
  }
}
