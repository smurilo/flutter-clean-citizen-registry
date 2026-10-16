import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Versioned schema. New versions append to [_migrations]; existing installs upgrade in place.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _migrations = <int, List<String>>{
    1: [
      '''CREATE TABLE citizens (
           id TEXT PRIMARY KEY,
           name TEXT NOT NULL,
           cpf TEXT NOT NULL UNIQUE,
           birth_date TEXT NOT NULL,
           phone TEXT,
           cep TEXT NOT NULL,
           street TEXT NOT NULL,
           number TEXT NOT NULL,
           district TEXT NOT NULL,
           city TEXT NOT NULL,
           uf TEXT NOT NULL,
           ibge_code TEXT NOT NULL,
           created_at TEXT NOT NULL,
           sync_status TEXT NOT NULL DEFAULT 'pending',
           sync_attempts INTEGER NOT NULL DEFAULT 0
         )''',
      'CREATE INDEX idx_citizens_sync ON citizens (sync_status)',
      'CREATE TABLE cep_cache (cep TEXT PRIMARY KEY, json TEXT NOT NULL, fetched_at TEXT NOT NULL)',
    ],
    2: ['CREATE TABLE cities_cache (uf TEXT PRIMARY KEY, json TEXT NOT NULL, fetched_at TEXT NOT NULL)'],
  };

  static int get latestVersion => _migrations.keys.reduce((a, b) => a > b ? a : b);

  static Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path ?? p.join(await f.getDatabasesPath(), 'citizen_registry.db'),
      options: OpenDatabaseOptions(
        version: latestVersion,
        onCreate: (db, v) => _upgrade(db, 0, v),
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      for (final sql in _migrations[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }
}
