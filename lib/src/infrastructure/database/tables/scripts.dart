import 'package:drift/drift.dart';

class ScriptRows extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().customConstraint(
    "NOT NULL CHECK (length(trim(title, ' ' || char(9) || char(10) || char(13))) > 0)",
  )();

  TextColumn get body => text().customConstraint(
    "NOT NULL CHECK (length(trim(body, ' ' || char(9) || char(10) || char(13))) > 0)",
  )();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}
