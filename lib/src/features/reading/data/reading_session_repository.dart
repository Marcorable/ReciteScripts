import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';

final class ReadingSessionStartException implements Exception {
  const ReadingSessionStartException(this.preparation);

  final SttPreparation preparation;
}

abstract interface class ReadingSessionRepository {
  ReadingSessionState? get state;

  Stream<ReadingSessionState> get states;

  Future<ReadingSessionState> start({
    required Script script,
    required int repetitions,
  });

  Future<void> moveBackOneWord();

  Future<void> continueNextRepetition();

  Future<bool> openAppSettings();

  Future<void> leave();

  Future<void> dispose();
}
