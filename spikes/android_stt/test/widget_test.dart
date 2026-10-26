import 'package:android_stt_spike/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.marcorable.recitescripts/stt_methods'),
          (call) async => call.method == 'capabilities'
              ? <String, Object?>{'sdk': 36, 'onDeviceAvailable': true}
              : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.marcorable.recitescripts/stt_methods'),
          null,
        );
  });

  testWidgets('온디바이스 지원 상태와 조작 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(const SttSpikeApp());
    await tester.pump();

    expect(find.textContaining('API 36'), findsOneWidget);
    expect(find.textContaining('온디바이스 사용 가능'), findsOneWidget);
    expect(find.text('인식 시작'), findsOneWidget);
    expect(find.text('ko-KR 지원 확인'), findsOneWidget);
  });
}
