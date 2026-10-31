import 'package:drift/drift.dart';

Future<void> migrateSchema(
  Migrator migrator, {
  required int from,
  required int to,
}) async {
  if (from >= to) return;

  // schemaVersion 1 is the initial schema. Add each future migration here,
  // preserving user rows instead of recreating the database.
  throw StateError('No migration is registered from schema $from to $to.');
}
