import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/infrastructure/stt/generated/stt_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/app/src/main/kotlin/com/marcorable/maltto/Generated/SttApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.marcorable.maltto'),
    swiftOut: 'ios/Runner/Generated/SttApi.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
enum NativeSttPermission { notDetermined, granted, denied, restricted }

enum NativeSttModelStatus {
  installed,
  supported,
  downloading,
  missing,
  unsupported,
}

enum NativeSttPreparationStatus {
  ready,
  permissionRequired,
  permissionDenied,
  modelDownloadRequired,
  modelDownloading,
  unsupported,
}

enum NativeSttEventKind {
  ready,
  partial,
  finalResult,
  ended,
  failure,
  cancelled,
}

enum NativeSttFailureCode {
  permissionDenied,
  onDeviceUnavailable,
  localeUnsupported,
  modelMissing,
  busy,
  noMatch,
  audio,
  audioFormatMismatch,
  interrupted,
  cancelled,
  unknown,
}

class NativeSttAvailability {
  NativeSttAvailability({
    required this.microphonePermission,
    required this.speechPermission,
    required this.onDeviceAvailable,
    required this.localeSupported,
    required this.modelStatus,
  });

  NativeSttPermission microphonePermission;
  NativeSttPermission speechPermission;
  bool onDeviceAvailable;
  bool localeSupported;
  NativeSttModelStatus modelStatus;
}

class NativeSttPreparation {
  NativeSttPreparation({required this.status, this.failureCode});

  NativeSttPreparationStatus status;
  NativeSttFailureCode? failureCode;
}

class NativeSttStartRequest {
  NativeSttStartRequest({
    required this.sessionId,
    required this.generation,
    required this.locale,
  });

  String sessionId;
  int generation;
  String locale;
}

class NativeSttEvent {
  NativeSttEvent({
    required this.sessionId,
    required this.generation,
    required this.sequence,
    required this.kind,
    this.text,
    this.failureCode,
    this.retryable,
  });

  String sessionId;
  int generation;
  int sequence;
  NativeSttEventKind kind;
  String? text;
  NativeSttFailureCode? failureCode;
  bool? retryable;
}

@HostApi()
abstract class NativeSttHostApi {
  @async
  NativeSttAvailability checkAvailability(String locale);

  @async
  NativeSttPreparation prepare(String locale);

  @async
  NativeSttPreparation requestModelDownload(String locale);

  @async
  void start(NativeSttStartRequest request);

  @async
  void cancel(String sessionId);

  @async
  void dispose();
}

@FlutterApi()
abstract class NativeSttFlutterApi {
  void onEvent(NativeSttEvent event);
}
