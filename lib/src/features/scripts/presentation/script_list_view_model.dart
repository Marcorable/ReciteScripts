import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';

final class ScriptListViewModel extends ChangeNotifier {
  ScriptListViewModel(this._repository);

  final ScriptRepository _repository;
  StreamSubscription<List<Script>>? _subscription;
  List<Script> _scripts = const [];
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _isDisposed = false;

  List<Script> get scripts => _scripts;
  bool get isLoading => _isLoading;
  bool get hasLoadError => _hasLoadError;

  void load() {
    if (_subscription != null) return;
    _subscription = _repository.watchAll().listen((scripts) {
      if (_isDisposed) return;
      _scripts = List.unmodifiable(scripts);
      _isLoading = false;
      _hasLoadError = false;
      notifyListeners();
    }, onError: _handleLoadError);
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    if (_isDisposed) return;
    _subscription = null;
    _isLoading = true;
    _hasLoadError = false;
    notifyListeners();
    load();
  }

  Future<bool> deleteScript(int id) async {
    try {
      await _repository.delete(id);
      return true;
    } on Object {
      return false;
    }
  }

  void _handleLoadError(Object _, StackTrace stackTrace) {
    if (_isDisposed) return;
    _isLoading = false;
    _hasLoadError = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
