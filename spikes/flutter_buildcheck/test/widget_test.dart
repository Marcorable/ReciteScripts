import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recite_buildcheck/main.dart';

void main() {
  testWidgets('Cupertino 환경 확인 화면을 표시한다', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('양 플랫폼 환경 준비 완료'), findsOneWidget);
  });
}
