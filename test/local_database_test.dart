import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_personales/models.dart';
import 'package:gastos_personales/services/local_cipher.dart';
import 'package:gastos_personales/services/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase database;
  late _MemoryStorage storage;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    storage = _MemoryStorage();
    database = LocalDatabase(
      LocalCipher(storage),
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() => database.close());

  test(
    'saves, updates, reads and deletes related expense and budget data',
    () async {
      final date = DateTime(2026, 11, 21);
      await database.saveExpense(
        Expense(
          id: 'expense-1',
          title: 'Supermercado',
          amount: 125.5,
          date: date,
          categoryId: 1,
          receiptPath: 'receipts/expense-1.enc',
        ),
      );
      await database.saveExpense(
        Expense(
          id: 'expense-1',
          title: 'Despensa',
          amount: 130,
          date: date,
          categoryId: 1,
        ),
      );
      await database.saveBudget(Budget(id: '1', categoryId: 1, amount: 900));

      final expenses = await database.getExpenses();
      final budgets = await database.getBudgets();
      final categories = await database.getCategories();
      expect(expenses, hasLength(1));
      expect(expenses.single.title, 'Despensa');
      expect(expenses.single.amount, 130);
      expect(expenses.single.receiptPath, 'receipts/expense-1.enc');
      expect(budgets.single.amount, 900);
      expect(categories.map((category) => category.id), [1, 2, 3, 4, 5]);

      await database.deleteExpense('expense-1');
      await database.deleteBudget('1');
      expect(await database.getExpenses(), isEmpty);
      expect(await database.getBudgets(), isEmpty);
      expect(
        await database.getPendingDeletions(),
        containsAll([
          {'entity_type': 'expense', 'entity_id': 'expense-1'},
          {'entity_type': 'budget', 'entity_id': '1'},
        ]),
      );
    },
  );
}

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}
