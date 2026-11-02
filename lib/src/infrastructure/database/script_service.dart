final class StoredScript {
  const StoredScript({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class ScriptService {
  Stream<List<StoredScript>> watchAll();

  Future<List<StoredScript>> getAll();

  Future<StoredScript> create({required String title, required String body});

  Future<void> delete(int id);
}
