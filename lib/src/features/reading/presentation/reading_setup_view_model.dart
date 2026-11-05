import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maltto/src/features/reading/data/reading_session_repository.dart';
import 'package:maltto/src/features/reading/domain/reading_session.dart';
import 'package:maltto/src/features/scripts/model/script.dart';
import 'package:maltto/src/infrastructure/stt/stt_models.dart';

enum ReadingSetupStartIssue {
  permissionRequired,
  permissionDenied,
  modelPreparing,
  unsupported,
  audioUnavailable,
  interrupted,
  temporaryFailure,
}

final class ReadingSetupViewModel extends ChangeNotifier {
  ReadingSetupViewModel({required this.script, required this.repository});

  final Script script;
  final ReadingSessionRepository repository;

  int _repetitions = 1;
  bool _isStarting = false;
  bool _isOpeningSettings = false;
  ReadingSetupStartIssue? _startIssue;
  bool _disposed = false;

  int get repetitions => _repetitions;
  bool get isStarting => _isStarting;
  bool get isOpeningSettings => _isOpeningSettings;
  ReadingSetupStartIssue? get startIssue => _startIssue;

  void selectRepetitions(int repetitions) {
    if (repetitions < 1 || repetitions > 10) {
      throw RangeError.range(repetitions, 1, 10, 'repetitions');
    }
    if (_repetitions == repetitions) return;
    _repetitions = repetitions;
    notifyListeners();
  }

  Future<ReadingSessionState?> start() async {
    if (_isStarting) throw StateError('낭독 시작을 이미 처리하고 있습니다.');
    _isStarting = true;
    _startIssue = null;
    notifyListeners();
    try {
      final state = await repository.start(
        script: script,
        repetitions: _repetitions,
      );
      if (_disposed) {
        await repository.leave();
        throw StateError('낭독 시작 화면이 종료되었습니다.');
      }
      return state;
    } on ReadingSessionStartException catch (error) {
      _startIssue = switch (error.preparation.status) {
        SttPreparationStatus.permissionRequired =>
          ReadingSetupStartIssue.permissionRequired,
        SttPreparationStatus.permissionDenied =>
          ReadingSetupStartIssue.permissionDenied,
        SttPreparationStatus.modelDownloadRequired ||
        SttPreparationStatus.modelDownloading =>
          ReadingSetupStartIssue.modelPreparing,
        SttPreparationStatus.unsupported => ReadingSetupStartIssue.unsupported,
        SttPreparationStatus.ready => switch (error.preparation.failureCode) {
          SttFailureCode.audio || SttFailureCode.audioFormatMismatch =>
            ReadingSetupStartIssue.audioUnavailable,
          SttFailureCode.interrupted => ReadingSetupStartIssue.interrupted,
          _ => ReadingSetupStartIssue.temporaryFailure,
        },
      };
      return null;
    } on Object {
      _startIssue = ReadingSetupStartIssue.temporaryFailure;
      return null;
    } finally {
      _isStarting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> openAppSettings() async {
    if (_isOpeningSettings) return false;
    _isOpeningSettings = true;
    notifyListeners();
    try {
      final opened = await repository.openAppSettings();
      if (!opened) _startIssue = ReadingSetupStartIssue.temporaryFailure;
      return opened;
    } on Object {
      _startIssue = ReadingSetupStartIssue.temporaryFailure;
      return false;
    } finally {
      _isOpeningSettings = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelStart() async {
    if (!_isStarting) return;
    await repository.leave();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_isStarting) unawaited(repository.leave());
    super.dispose();
  }
}
