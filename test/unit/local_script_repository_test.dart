import 'package:maltto/src/features/scripts/data/local_script_repository.dart';
import 'package:maltto/src/infrastructure/database/script_service.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 31, 10);
  final updatedAt = DateTime.utc(2026, 10, 31, 11);

  test('Service 저장 타입을 모든 필드가 있는 앱 Script 모델로 변환한다', () async {
    final service = _FakeScriptService(
      StoredScript(
        id: 1,
        title: '발표 연습',
        body: '직접 작성한 문장을 또박또박 읽습니다.',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
    final repository = LocalScriptRepository(service);

    final scripts = await repository.watchAll().first;

    expect(scripts, hasLength(1));
    expect(scripts.single.title, '발표 연습');
    expect(scripts.single.body, '직접 작성한 문장을 또박또박 읽습니다.');
    expect(scripts.single.createdAt, createdAt);
    expect(scripts.single.updatedAt, updatedAt);
    expect(() => scripts.clear(), throwsUnsupportedError);
  });

  test('조회·추가·삭제 명령을 Service에 전달한다', () async {
    final service = _FakeScriptService(
      StoredScript(
        id: 1,
        title: '연습 기록',
        body: '차분한 속도로 읽습니다.',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
    final repository = LocalScriptRepository(service);

    expect(await repository.getAll(), hasLength(1));
    final created = await repository.create(
      title: '새 대본',
      body: '새로 쓴 내용을 읽습니다.',
    );
    await repository.delete(created.id);

    expect(service.createdTitle, '새 대본');
    expect(service.createdBody, '새로 쓴 내용을 읽습니다.');
    expect(service.deletedId, 1);
  });
}

final class _FakeScriptService implements ScriptService {
  _FakeScriptService(this.row);

  final StoredScript row;
  String? createdTitle;
  String? createdBody;
  int? deletedId;

  @override
  Stream<List<StoredScript>> watchAll() => Stream.value([row]);

  @override
  Future<List<StoredScript>> getAll() async => [row];

  @override
  Future<StoredScript> create({
    required String title,
    required String body,
  }) async {
    createdTitle = title;
    createdBody = body;
    return row;
  }

  @override
  Future<void> delete(int id) async {
    deletedId = id;
  }
}
