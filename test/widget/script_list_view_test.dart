import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/app/app.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/features/scripts/presentation/script_list_view_model.dart';

void main() {
  testWidgets('빈 대본 목록을 Cupertino 화면으로 표시한다', (tester) async {
    final viewModel = ScriptListViewModel(_FakeScriptRepository());
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(MalttoApp(scriptListViewModel: viewModel));
    await tester.pump();

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('대본'), findsOneWidget);
    expect(find.text('저장된 대본이 없습니다.'), findsOneWidget);
  });
}

final class _FakeScriptRepository implements ScriptRepository {
  @override
  Stream<List<Script>> watchAll() => Stream.value(const []);
}
