import 'stt_models.dart';

abstract interface class SttService {
  Future<SttAvailability> checkAvailability({required String locale});

  Future<SttPreparation> prepare({required String locale});

  Stream<SttEvent> events(String sessionId);

  Future<void> start(SttStartRequest request);

  Future<void> cancel(String sessionId);

  Future<void> dispose();
}
