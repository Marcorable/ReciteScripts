import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maltto/src/features/scripts/data/script_repository.dart';
import 'package:maltto/src/features/scripts/model/script.dart';

final class ScriptListViewModel extends ChangeNotifier {
  ScriptListViewModel(this._repository);

  final ScriptRepository _repository;
  StreamSubscription<List<Script>>? _subscription;
  List<Script> _scripts = const [];

  List<Script> get scripts => _scripts;

  void load() {
    if (_subscription != null) return;
    _subscription = _repository.watchAll().listen((scripts) {
      _scripts = List.unmodifiable(scripts);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
