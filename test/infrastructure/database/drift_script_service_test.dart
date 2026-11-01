import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/infrastructure/database/app_database.dart';
import 'package:maltto/src/infrastructure/database/drift_script_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DriftScriptService service;
  final timestamp = DateTime.utc(2026, 10, 31, 9, 30);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = DriftScriptService(database, now: () => timestamp);
  });

  tearDown(() async {
    await database.close();
  });

  test('schema version 1에서 추가·조회·삭제와 시각을 보존한다', () async {
    expect(database.schemaVersion, 1);

    final created = await service.create(
      title: '오전 연습',
      body: '맑은 목소리로 문장을 읽습니다.',
    );
    final rows = await service.getAll();

    expect(created.id, isPositive);
    expect(rows.single.title, '오전 연습');
    expect(rows.single.body, '맑은 목소리로 문장을 읽습니다.');
    expect(rows.single.createdAt, timestamp);
    expect(rows.single.updatedAt, timestamp);

    await service.delete(created.id);
    expect(await service.getAll(), isEmpty);
  });

  test('watchAll은 추가와 삭제 뒤 최신 목록을 방출한다', () async {
    final emissions = <List<String>>[];
    final subscription = service.watchAll().listen(
      (rows) => emissions.add(rows.map((row) => row.title).toList()),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    final created = await service.create(
      title: '관찰할 대본',
      body: '목록이 바로 바뀌는지 확인합니다.',
    );
    await pumpEventQueue();
    await service.delete(created.id);
    await pumpEventQueue();

    expect(emissions, [
      isEmpty,
      ['관찰할 대본'],
      isEmpty,
    ]);
  });

  test('Service가 공백뿐인 제목과 본문을 거부한다', () async {
    await expectLater(
      service.create(title: '   ', body: '유효한 본문'),
      throwsArgumentError,
    );
    await expectLater(
      service.create(title: '유효한 제목', body: '\n\t\u3000'),
      throwsArgumentError,
    );
  });

  test('SQLite CHECK가 Service를 우회한 공백 제목과 본문을 거부한다', () async {
    Future<void> insert({required String title, required String body}) async {
      await database
          .into(database.scriptRows)
          .insert(
            ScriptRowsCompanion.insert(
              title: title,
              body: body,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
    }

    await expectLater(
      insert(title: ' \t\n', body: '유효한 본문'),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insert(title: '유효한 제목', body: '\r\n\t'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('파일 DB를 닫고 다시 열어도 긴 본문이 그대로 유지된다', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'maltto-persistence-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/scripts.sqlite');
    final longBody = List.filled(5000, '직접 작성한 긴 문장을 차분하게 읽습니다. ').join();

    var fileDatabase = AppDatabase.openAt(file);
    var fileService = DriftScriptService(fileDatabase, now: () => timestamp);
    await fileService.create(title: '긴 대본', body: longBody);
    await fileDatabase.close();

    fileDatabase = AppDatabase.openAt(file);
    fileService = DriftScriptService(fileDatabase);
    final reopenedRows = await fileService.getAll();

    expect(reopenedRows.single.title, '긴 대본');
    expect(reopenedRows.single.body, longBody);
    expect(reopenedRows.single.createdAt, timestamp);
    await fileDatabase.close();

    database = AppDatabase(NativeDatabase.memory());
    service = DriftScriptService(database, now: () => timestamp);
  });
}
