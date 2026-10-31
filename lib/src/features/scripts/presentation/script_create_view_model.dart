import 'package:flutter/foundation.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';

final class ScriptCreateViewModel extends ChangeNotifier {
  ScriptCreateViewModel(this._repository);

  final ScriptRepository _repository;

  String? _titleError;
  String? _bodyError;
  String? _saveError;
  bool _isSaving = false;
  bool _isDisposed = false;

  String? get titleError => _titleError;
  String? get bodyError => _bodyError;
  String? get saveError => _saveError;
  bool get isSaving => _isSaving;

  Future<bool> save({required String title, required String body}) async {
    if (_isSaving) return false;

    _titleError = title.trim().isEmpty ? '제목을 입력하세요.' : null;
    _bodyError = body.trim().isEmpty ? '본문을 입력하세요.' : null;
    _saveError = null;
    if (_titleError != null || _bodyError != null) {
      notifyListeners();
      return false;
    }

    _isSaving = true;
    notifyListeners();
    try {
      await _repository.create(title: title, body: body);
      return true;
    } on Object {
      if (!_isDisposed) {
        _saveError = '저장하지 못했습니다. 다시 시도해 주세요.';
      }
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
