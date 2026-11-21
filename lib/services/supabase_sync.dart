import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'local_database.dart';

class SupabaseSync {
  SupabaseSync(this._database);

  final LocalDatabase _database;

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> synchronize() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para sincronizar tus datos.');
    }
    final syncOwner = await _database.getSyncOwner();
    if (syncOwner != null && syncOwner != user.id) {
      throw StateError(
        'Este dispositivo está vinculado a otra cuenta. No se mezclarán datos entre cuentas.',
      );
    }
    if (syncOwner == null) {
      await _database.setSyncOwner(user.id);
    }

    final pendingDeletions = await _database.getPendingDeletions();
    for (final deletion in pendingDeletions) {
      await _client
          .from(deletion['entity_type'] == 'expense' ? 'expenses' : 'budgets')
          .delete()
          .eq('user_id', user.id)
          .eq('id', deletion['entity_id']!);
    }
    if (pendingDeletions.isNotEmpty) {
      await _database.clearPendingDeletions();
    }

    final expenses = await _database.getExpenses();
    if (expenses.isNotEmpty) {
      await _client
          .from('expenses')
          .upsert(
            expenses
                .map(
                  (expense) => {
                    'id': expense.id,
                    'user_id': user.id,
                    'title': expense.title,
                    'amount': expense.amount,
                    'date': expense.date.toIso8601String(),
                    'category_id': expense.categoryId,
                  },
                )
                .toList(),
            onConflict: 'user_id,id',
          );
    }

    final budgets = await _database.getBudgets();
    if (budgets.isNotEmpty) {
      await _client
          .from('budgets')
          .upsert(
            budgets
                .map(
                  (budget) => {
                    'id': budget.id,
                    'user_id': user.id,
                    'category_id': budget.categoryId,
                    'amount': budget.amount,
                    'period': budget.period,
                  },
                )
                .toList(),
            onConflict: 'user_id,id',
          );
    }

    final remoteExpenses = await _client
        .from('expenses')
        .select('id,title,amount,date,category_id')
        .eq('user_id', user.id);
    for (final row in remoteExpenses) {
      final id = row['id'] as String;
      final existing = await _database.getExpense(id);
      await _database.saveExpense(
        Expense(
          id: id,
          title: row['title'] as String,
          amount: (row['amount'] as num).toDouble(),
          date: DateTime.parse(row['date'] as String),
          categoryId: row['category_id'] as int,
          receiptPath: existing?.receiptPath,
        ),
      );
    }

    final remoteBudgets = await _client
        .from('budgets')
        .select('id,category_id,amount,period')
        .eq('user_id', user.id);
    for (final row in remoteBudgets) {
      await _database.saveBudget(
        Budget(
          id: row['id'] as String,
          categoryId: row['category_id'] as int,
          amount: (row['amount'] as num).toDouble(),
          period: row['period'] as String,
        ),
      );
    }
  }
}
