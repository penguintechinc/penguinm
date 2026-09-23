import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Owns the `package:sqlite3` connection shared by [SqliteOfflineStore] and
/// [SyncQueue]: schema migrations (tracked via `PRAGMA user_version`) and
/// parameterised `execute`/`select` primitives. SQL text is never built by
/// string interpolation — every value flows through bound `?` parameters.
class OfflineDatabase {
  /// Opens (creating if needed) a file-backed database at [path] and
  /// applies any pending migrations. Data persists across process restarts.
  OfflineDatabase.open(String path) : _db = sqlite.sqlite3.open(path) {
    _migrate();
  }

  /// Opens a private in-memory database and applies migrations. Used by
  /// tests and as the default value of `offlineStoreProvider`'s database
  /// before an app overrides it with [openAppDatabase].
  OfflineDatabase.inMemory() : _db = sqlite.sqlite3.openInMemory() {
    _migrate();
  }

  final sqlite.Database _db;

  /// How many [transaction] calls are currently nested on the call stack.
  /// `0` means the next [transaction] call is the outermost one and must
  /// use `BEGIN`/`COMMIT`/`ROLLBACK`; any positive value means a `BEGIN` is
  /// already open and the next call must use a named `SAVEPOINT` instead
  /// (SQLite has no nested `BEGIN`).
  int _transactionDepth = 0;

  /// Runs `sql` with positionally-bound [parameters], discarding any rows
  /// it returns. Used for `INSERT`/`UPDATE`/`DELETE`/DDL statements.
  void execute(String sql, [List<Object?> parameters = const []]) {
    _db.execute(sql, parameters);
  }

  /// Runs `sql` with positionally-bound [parameters] and returns every row
  /// as a [sqlite.ResultSet] (an `Iterable<Row>` supporting map-style
  /// column access).
  sqlite.ResultSet select(String sql, [List<Object?> parameters = const []]) {
    return _db.select(sql, parameters);
  }

  /// The rowid sqlite assigned to the most recent successful `INSERT`.
  int get lastInsertRowId => _db.lastInsertRowId;

  /// Runs [action] inside a SQLite transaction. The outermost call opens a
  /// real transaction (`BEGIN` ... `COMMIT`, or `ROLLBACK` if [action]
  /// throws) exactly as before. A call made while already inside another
  /// [transaction] — SQLite disallows a second `BEGIN` — instead opens a
  /// named `SAVEPOINT` and releases or rolls back only that savepoint, so
  /// an inner failure undoes just the inner writes without aborting the
  /// outer transaction (the outer caller decides, by catching or not,
  /// whether the inner failure also fails the outer action). Used for
  /// multi-statement changes that must apply as one atomic unit — e.g.
  /// [SyncQueue] moving a write out of `pending_writes` and into
  /// `dead_letters` together, so a crash mid-move can never leave a write
  /// in both tables or neither — and by [_migrate] to keep a multi-DDL
  /// schema step all-or-nothing.
  T transaction<T>(T Function() action) {
    final depth = _transactionDepth;
    final savepoint = 'penguin_offline_sp_$depth';
    _transactionDepth = depth + 1;
    if (depth == 0) {
      _db.execute('BEGIN');
    } else {
      _db.execute('SAVEPOINT $savepoint');
    }
    try {
      final result = action();
      if (depth == 0) {
        _db.execute('COMMIT');
      } else {
        _db.execute('RELEASE SAVEPOINT $savepoint');
      }
      return result;
    } catch (_) {
      if (depth == 0) {
        _db.execute('ROLLBACK');
      } else {
        _db.execute('ROLLBACK TO SAVEPOINT $savepoint');
        _db.execute('RELEASE SAVEPOINT $savepoint');
      }
      rethrow;
    } finally {
      _transactionDepth = depth;
    }
  }

  /// Applies schema migrations in order, gated by `PRAGMA user_version`
  /// (exposed here as [sqlite.Database.userVersion]) so an already-migrated
  /// database is a no-op to reopen. A fresh database runs every migration
  /// in one call, landing directly on the latest version. Each version
  /// step runs inside [transaction] so a step with more than one DDL
  /// statement applies atomically — a failure partway through rolls back
  /// every statement the step already ran (not just the failing one) and
  /// leaves `user_version` unadvanced, instead of leaving the schema in a
  /// half-migrated state that the next [_migrate] call can't recover from.
  void _migrate() {
    if (_db.userVersion < 1) {
      transaction(() {
        _db.execute('''
          CREATE TABLE IF NOT EXISTS cache_entries (
            collection TEXT NOT NULL,
            id TEXT NOT NULL,
            json TEXT NOT NULL,
            fetched_at INTEGER NOT NULL,
            PRIMARY KEY (collection, id)
          )
        ''');
        _db.execute('''
          CREATE TABLE IF NOT EXISTS pending_writes (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT,
            idempotency_key TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        _db.userVersion = 1;
      });
    }
    if (_db.userVersion < 2) {
      // Dead letters used to be deleted from pending_writes in the same
      // step they were emitted on SyncQueue.deadLetters — if nothing was
      // listening at that instant, the write was gone for good. This table
      // makes a dead letter durable until a caller acknowledges or retries
      // it (spec §4.7: "surfaced to the user, never silently dropped").
      transaction(() {
        _db.execute('''
          CREATE TABLE IF NOT EXISTS dead_letters (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT,
            idempotency_key TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            failed_at INTEGER NOT NULL,
            status INTEGER,
            reason TEXT
          )
        ''');
        _db.userVersion = 2;
      });
    }
  }

  /// Closes the native connection. Safe to call once; using the database
  /// afterwards throws.
  void close() => _db.close();
}

/// Opens (creating parent directories as needed) the per-product offline
/// database at `<getApplicationSupportDirectory()>/penguin_offline/<productKey>.sqlite`.
Future<OfflineDatabase> openAppDatabase({required String productKey}) async {
  final supportDir = await getApplicationSupportDirectory();
  final offlineDir = Directory(p.join(supportDir.path, 'penguin_offline'));
  if (!offlineDir.existsSync()) {
    offlineDir.createSync(recursive: true);
  }
  final dbPath = p.join(offlineDir.path, '$productKey.sqlite');
  return OfflineDatabase.open(dbPath);
}
