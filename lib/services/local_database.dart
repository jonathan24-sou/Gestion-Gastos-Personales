import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import 'local_cipher.dart';

class LocalDatabase {
  LocalDatabase(this._cipher, {this.factory, this.databasePath});

  final LocalCipher _cipher;
  final DatabaseFactory? factory;
  final String? databasePath;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final factory = this.factory ?? databaseFactory;
    final databasePath =
        this.databasePath ??
        path.join(await factory.getDatabasesPath(), 'gastos_personales.db');
    _database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE budgets (
            id TEXT PRIMARY KEY,
            category_id INTEGER NOT NULL UNIQUE,
            amount_cipher TEXT NOT NULL,
            period TEXT NOT NULL,
            FOREIGN KEY (category_id) REFERENCES categories(id)
          )
        ''');
          await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            title_cipher TEXT NOT NULL,
            amount_cipher TEXT NOT NULL,
            date TEXT NOT NULL,
            category_id INTEGER NOT NULL,
            receipt_path TEXT,
            FOREIGN KEY (category_id) REFERENCES categories(id)
          )
        ''');
          await db.execute('''
          CREATE TABLE pending_deletions (
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            PRIMARY KEY (entity_type, entity_id)
          )
        ''');
          await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          final batch = db.batch();
          for (final category in ExpenseCategory.defaults) {
            batch.insert('categories', {
              'id': category.id,
              'name': category.name,
              'icon_code': category.iconCode,
              'color_value': category.colorValue,
            });
          }
          await batch.commit(noResult: true);
        },
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) return;
    await database.close();
    _database = null;
  }

  Future<List<Expense>> getExpenses() async {
    final rows = await (await _db).query('expenses', orderBy: 'date DESC');
    return Future.wait(rows.map(_expenseFromRow));
  }

  Future<Expense> _expenseFromRow(Map<String, Object?> row) async {
    final receiptCipher = row['receipt_path'] as String?;
    return Expense(
      id: row['id'] as String,
      title: await _cipher.decrypt(row['title_cipher'] as String),
      amount: double.parse(
        await _cipher.decrypt(row['amount_cipher'] as String),
      ),
      date: DateTime.parse(row['date'] as String),
      categoryId: row['category_id'] as int,
      receiptPath: receiptCipher == null
          ? null
          : await _cipher.decrypt(receiptCipher),
    );
  }

  Future<void> saveExpense(Expense expense) async {
    final db = await _db;
    final existing = await getExpense(expense.id);
    final receiptPath = expense.receiptPath ?? existing?.receiptPath;
    await db.transaction((transaction) async {
      await transaction.insert('expenses', {
        'id': expense.id,
        'title_cipher': await _cipher.encrypt(expense.title),
        'amount_cipher': await _cipher.encrypt(expense.amount.toString()),
        'date': expense.date.toIso8601String(),
        'category_id': expense.categoryId,
        'receipt_path': receiptPath == null
            ? null
            : await _cipher.encrypt(receiptPath),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.delete(
        'pending_deletions',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['expense', expense.id],
      );
    });
  }

  Future<void> deleteExpense(String id) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete('expenses', where: 'id = ?', whereArgs: [id]);
      await transaction.insert('pending_deletions', {
        'entity_type': 'expense',
        'entity_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Expense?> getExpense(String id) async {
    final rows = await (await _db).query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _expenseFromRow(rows.first);
  }

  Future<List<Budget>> getBudgets() async {
    final rows = await (await _db).query('budgets');
    return Future.wait(
      rows.map((row) async {
        return Budget(
          id: row['id'] as String,
          categoryId: row['category_id'] as int,
          amount: double.parse(
            await _cipher.decrypt(row['amount_cipher'] as String),
          ),
          period: row['period'] as String,
        );
      }),
    );
  }

  Future<void> saveBudget(Budget budget) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.insert('budgets', {
        'id': budget.id,
        'category_id': budget.categoryId,
        'amount_cipher': await _cipher.encrypt(budget.amount.toString()),
        'period': budget.period,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.delete(
        'pending_deletions',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['budget', budget.id],
      );
    });
  }

  Future<void> deleteBudget(String id) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete('budgets', where: 'id = ?', whereArgs: [id]);
      await transaction.insert('pending_deletions', {
        'entity_type': 'budget',
        'entity_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, String>>> getPendingDeletions() async {
    final rows = await (await _db).query('pending_deletions');
    return rows
        .map(
          (row) => {
            'entity_type': row['entity_type'] as String,
            'entity_id': row['entity_id'] as String,
          },
        )
        .toList();
  }

  Future<void> clearPendingDeletions() async {
    await (await _db).delete('pending_deletions');
  }

  Future<String?> getSyncOwner() async {
    final rows = await (await _db).query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['sync_owner_id'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSyncOwner(String userId) async {
    await (await _db).insert('app_settings', {
      'key': 'sync_owner_id',
      'value': userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ExpenseCategory>> getCategories() async {
    final rows = await (await _db).query('categories', orderBy: 'id');
    return rows
        .map(
          (row) => ExpenseCategory(
            id: row['id'] as int,
            name: row['name'] as String,
            iconCode: row['icon_code'] as int,
            colorValue: row['color_value'] as int,
          ),
        )
        .toList();
  }
}
