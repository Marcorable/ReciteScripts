import 'package:maltto/src/features/scripts/data/local_script_repository.dart';
import 'package:maltto/src/infrastructure/database/script_service.dart';
import 'package:test/test.dart';

void main() {
  test('Service 저장 타입을 앱 Script 모델로 변환한다', () async {
    final repository = LocalScriptRepository(_FakeScriptService());

    final scripts = await repository.watchAll().first;

    expect(scripts, hasLength(1));
    expect(scripts.single.title, '발표 연습');
    expect(scripts.single.body, '오늘은 맑은 목소리로 읽는다.');
    expect(() => scripts.clear(), throwsUnsupportedError);
  });
}

final class _FakeScriptService implements ScriptService {
  @override
  Stream<List<StoredScript>> watchAll() {
    return Stream.value(const [
      StoredScript(id: 1, title: '발표 연습', body: '오늘은 맑은 목소리로 읽는다.'),
    ]);
  }
}
