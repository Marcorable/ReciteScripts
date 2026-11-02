final class Script {
  const Script({
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
