import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maltto/src/infrastructure/stt/generated/stt_api.g.dart'
    as pigeon;
import 'package:maltto/src/infrastructure/stt/pigeon_stt_service.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.NativeSttHostApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  BasicMessageChannel<Object?> hostChannel(String method) =>
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.maltto.NativeSttHostApi.$method',
        codec,
      );

  void setHostHandler(
    String method,
    Future<Object?> Function(Object?)? handler,
  ) {
    messenger.setMockDecodedMessageHandler<Object?>(
      hostChannel(method),
      handler,
    );
  }

  Future<Object?> ok(Object? value) async => <Object?>[value];

  setUp(() {
    setHostHandler('dispose', (_) => ok(null));
    setHostHandler('cancel', (_) => ok(null));
  });

  tearDown(() {
    for (final method in <String>[
      'checkAvailability',
      'prepare',
      'start',
      'cancel',
      'dispose',
    ]) {
      setHostHandler(method, null);
    }
    pigeon.NativeSttFlutterApi.setUp(null);
  });

  test('권한 거부와 모델 미설치 준비 상태를 구조화해 전달한다', () async {
    setHostHandler(
      'checkAvailability',
      (_) => ok(
        pigeon.NativeSttAvailability(
          microphonePermission: pigeon.NativeSttPermission.denied,
          speechPermission: pigeon.NativeSttPermission.granted,
          onDeviceAvailable: true,
          localeSupported: true,
          modelStatus: pigeon.NativeSttModelStatus.supported,
        ),
      ),
    );
    setHostHandler(
      'prepare',
      (_) => ok(
        pigeon.NativeSttPreparation(
          status: pigeon.NativeSttPreparationStatus.modelDownloadRequired,
          failureCode: pigeon.NativeSttFailureCode.modelMissing,
        ),
      ),
    );
    final service = PigeonSttService();

    final availability = await service.checkAvailability(locale: 'ko-KR');
    final preparation = await service.prepare(locale: 'ko-KR');

    expect(availability.microphonePermission, SttPermission.denied);
    expect(availability.modelStatus, SttModelStatus.supported);
    expect(preparation.status, SttPreparationStatus.modelDownloadRequired);
    expect(preparation.failureCode, SttFailureCode.modelMissing);
    await service.dispose();
  });

  test('오디오 포맷 불일치를 구조화 failure 이벤트로 전달한다', () async {
    setHostHandler('start', (_) => ok(null));
    final service = PigeonSttService();
    final events = <SttEvent>[];
    final subscription = service.events('session').listen(events.add);
    await service.start(
      const SttStartRequest(
        sessionId: 'session',
        generation: 1,
        locale: 'ko-KR',
      ),
    );

    await messenger.handlePlatformMessage(
      'dev.flutter.pigeon.maltto.NativeSttFlutterApi.onEvent',
      codec.encodeMessage(<Object?>[
        pigeon.NativeSttEvent(
          sessionId: 'session',
          generation: 1,
          sequence: 1,
          kind: pigeon.NativeSttEventKind.failure,
          failureCode: pigeon.NativeSttFailureCode.audioFormatMismatch,
          retryable: false,
        ),
      ]),
      (_) {},
    );
    await pumpEventQueue();

    expect(events.single.failureCode, SttFailureCode.audioFormatMismatch);
    await subscription.cancel();
    await service.dispose();
  });

  test('종료된 generation의 늦은 결과와 빈 전사를 버린다', () async {
    setHostHandler('start', (_) => ok(null));
    final service = PigeonSttService();
    final events = <SttEvent>[];
    final subscription = service.events('session').listen(events.add);
    await service.start(
      const SttStartRequest(
        sessionId: 'session',
        generation: 1,
        locale: 'ko-KR',
      ),
    );
    await service.cancel('session');

    for (final event in <pigeon.NativeSttEvent>[
      pigeon.NativeSttEvent(
        sessionId: 'session',
        generation: 1,
        sequence: 2,
        kind: pigeon.NativeSttEventKind.finalResult,
        text: '늦게 도착한 직접 쓴 문장',
      ),
      pigeon.NativeSttEvent(
        sessionId: 'session',
        generation: 2,
        sequence: 1,
        kind: pigeon.NativeSttEventKind.partial,
        text: '   ',
      ),
    ]) {
      await messenger.handlePlatformMessage(
        'dev.flutter.pigeon.maltto.NativeSttFlutterApi.onEvent',
        codec.encodeMessage(<Object?>[event]),
        (_) {},
      );
    }
    await pumpEventQueue();

    expect(events, isEmpty);
    await subscription.cancel();
    await service.dispose();
  });
}
