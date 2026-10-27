final class StoredScript {
  const StoredScript({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}

abstract interface class ScriptService {
  Stream<List<StoredScript>> watchAll();
}
