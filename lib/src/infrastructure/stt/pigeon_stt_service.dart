import 'dart:async';

import 'generated/stt_api.g.dart' as pigeon;
import 'stt_models.dart';
import 'stt_service.dart';

final class PigeonSttService implements SttService, pigeon.NativeSttFlutterApi {
  PigeonSttService({pigeon.NativeSttHostApi? host})
    : _host = host ?? pigeon.NativeSttHostApi() {
    pigeon.NativeSttFlutterApi.setUp(this);
  }

  final pigeon.NativeSttHostApi _host;
  final Map<String, StreamController<SttEvent>> _controllers = {};
  final Map<String, int> _activeGenerations = {};
  final Map<String, int> _lastSequences = {};
  bool _disposed = false;

  @override
  Future<SttAvailability> checkAvailability({required String locale}) async {
    _ensureActive();
    return _availabilityFromNative(await _host.checkAvailability(locale));
  }

  @override
  Future<SttPreparation> prepare({required String locale}) async {
    _ensureActive();
    final native = await _host.prepare(locale);
    return SttPreparation(
      status: SttPreparationStatus.values[native.status.index],
      failureCode: native.failureCode == null
          ? null
          : SttFailureCode.values[native.failureCode!.index],
    );
  }

  @override
  Stream<SttEvent> events(String sessionId) {
    _ensureActive();
    return _controllers
        .putIfAbsent(sessionId, StreamController<SttEvent>.broadcast)
        .stream;
  }

  @override
  Future<void> start(SttStartRequest request) async {
    _ensureActive();
    if (request.sessionId.isEmpty || request.locale.isEmpty) {
      throw ArgumentError('sessionId와 locale은 비어 있을 수 없습니다.');
    }
    final previous = _activeGenerations[request.sessionId];
    if (previous != null && request.generation <= previous) {
      throw StateError('generation은 이전 값보다 커야 합니다.');
    }

    _activeGenerations[request.sessionId] = request.generation;
    _lastSequences[request.sessionId] = -1;
    try {
      await _host.start(
        pigeon.NativeSttStartRequest(
          sessionId: request.sessionId,
          generation: request.generation,
          locale: request.locale,
        ),
      );
    } catch (_) {
      if (_activeGenerations[request.sessionId] == request.generation) {
        _activeGenerations.remove(request.sessionId);
        _lastSequences.remove(request.sessionId);
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel(String sessionId) async {
    if (_disposed) return;
    final generation = _activeGenerations[sessionId];
    await _host.cancel(sessionId);
    if (_activeGenerations[sessionId] == generation) {
      _activeGenerations.remove(sessionId);
      _lastSequences.remove(sessionId);
    }
  }

  @override
  void onEvent(pigeon.NativeSttEvent event) {
    if (_disposed || _activeGenerations[event.sessionId] != event.generation) {
      return;
    }
    final lastSequence = _lastSequences[event.sessionId] ?? -1;
    if (event.sequence <= lastSequence) return;
    final text = event.text?.trim();
    if ((event.kind == pigeon.NativeSttEventKind.partial ||
            event.kind == pigeon.NativeSttEventKind.finalResult) &&
        (text == null || text.isEmpty)) {
      return;
    }
    _lastSequences[event.sessionId] = event.sequence;
    _controllers[event.sessionId]?.add(
      SttEvent(
        sessionId: event.sessionId,
        generation: event.generation,
        sequence: event.sequence,
        kind: SttEventKind.values[event.kind.index],
        text: text,
        failureCode: event.failureCode == null
            ? null
            : SttFailureCode.values[event.failureCode!.index],
        retryable: event.retryable,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _activeGenerations.clear();
    _lastSequences.clear();
    pigeon.NativeSttFlutterApi.setUp(null);
    await _host.dispose();
    final controllers = _controllers.values.toList(growable: false);
    _controllers.clear();
    await Future.wait(controllers.map((controller) => controller.close()));
  }

  SttAvailability _availabilityFromNative(
    pigeon.NativeSttAvailability native,
  ) => SttAvailability(
    microphonePermission:
        SttPermission.values[native.microphonePermission.index],
    speechPermission: SttPermission.values[native.speechPermission.index],
    onDeviceAvailable: native.onDeviceAvailable,
    localeSupported: native.localeSupported,
    modelStatus: SttModelStatus.values[native.modelStatus.index],
  );

  void _ensureActive() {
    if (_disposed) throw StateError('SttService가 이미 dispose되었습니다.');
  }
}
