enum SttPermission { notDetermined, granted, denied, restricted }

enum SttModelStatus { installed, supported, downloading, missing, unsupported }

enum SttPreparationStatus {
  ready,
  permissionRequired,
  permissionDenied,
  modelDownloadRequired,
  modelDownloading,
  unsupported,
}

enum SttEventKind { ready, partial, finalResult, ended, failure, cancelled }

enum SttFailureCode {
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

final class SttAvailability {
  const SttAvailability({
    required this.microphonePermission,
    required this.speechPermission,
    required this.onDeviceAvailable,
    required this.localeSupported,
    required this.modelStatus,
  });

  final SttPermission microphonePermission;
  final SttPermission speechPermission;
  final bool onDeviceAvailable;
  final bool localeSupported;
  final SttModelStatus modelStatus;
}

final class SttPreparation {
  const SttPreparation({required this.status, this.failureCode});

  final SttPreparationStatus status;
  final SttFailureCode? failureCode;
}

final class SttStartRequest {
  const SttStartRequest({
    required this.sessionId,
    required this.generation,
    required this.locale,
  });

  final String sessionId;
  final int generation;
  final String locale;
}

final class SttEvent {
  const SttEvent({
    required this.sessionId,
    required this.generation,
    required this.sequence,
    required this.kind,
    this.text,
    this.failureCode,
    this.retryable,
  });

  final String sessionId;
  final int generation;
  final int sequence;
  final SttEventKind kind;
  final String? text;
  final SttFailureCode? failureCode;
  final bool? retryable;
}
