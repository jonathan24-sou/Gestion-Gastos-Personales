import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'services/local_cipher.dart';
import 'services/local_database.dart';
import 'services/notification_service.dart';
import 'services/supabase_sync.dart';

const _ink = Color(0xff20352f);
const _green = Color(0xff537d63);
const _cream = Color(0xfff6f4ee);
final _money = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  final cipher = LocalCipher(const FlutterSecureStorage());
  final database = LocalDatabase(cipher);
  final notifications = NotificationService();
  String? setupMessage;
  var supabaseReady = false;

  if (SupabaseSync.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseSync.url,
        publishableKey: SupabaseSync.anonKey,
      );
      supabaseReady = true;
    } catch (error) {
      setupMessage = 'No se pudo iniciar Supabase: $error';
    }
  }
  try {
    await notifications.initialize();
  } catch (error) {
    setupMessage = [
      ?setupMessage,
      'No se pudieron activar las notificaciones: $error',
    ].join('\n');
  }

  runApp(
    ExpenseApp(
      database: database,
      cipher: cipher,
      notifications: notifications,
      supabaseReady: supabaseReady,
      sync: SupabaseSync(database),
      setupMessage: setupMessage,
    ),
  );
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({
    super.key,
    required this.database,
    required this.cipher,
    required this.notifications,
    required this.supabaseReady,
    required this.sync,
    this.setupMessage,
  });

  final LocalDatabase database;
  final LocalCipher cipher;
  final NotificationService notifications;
  final bool supabaseReady;
  final SupabaseSync sync;
  final String? setupMessage;

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  bool _guestMode = false;

  bool get _signedIn =>
      widget.supabaseReady && Supabase.instance.client.auth.currentUser != null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis gastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: _cream,
        ),
        scaffoldBackgroundColor: _cream,
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _cream,
          foregroundColor: _ink,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: _signedIn || _guestMode
          ? ExpenseHome(
              database: widget.database,
              cipher: widget.cipher,
              notifications: widget.notifications,
              sync: widget.sync,
              signedIn: _signedIn,
              setupMessage: widget.setupMessage,
              onSignOut: () async {
                if (_signedIn) await Supabase.instance.client.auth.signOut();
                setState(() => _guestMode = false);
              },
              onOpenLogin: () => setState(() => _guestMode = false),
            )
          : LoginScreen(
              supabaseReady: widget.supabaseReady,
              setupMessage: widget.setupMessage,
              onGuest: () => setState(() => _guestMode = true),
              onAuthenticated: () => setState(() {}),
            ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.supabaseReady,
    required this.onGuest,
    required this.onAuthenticated,
    this.setupMessage,
  });

  final bool supabaseReady;
  final VoidCallback onGuest;
  final VoidCallback onAuthenticated;
  final String? setupMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.supabaseReady || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (auth.currentUser == null) {
        setState(() {
          _error = 'Revisa tu correo para confirmar la cuenta y vuelve a iniciar sesión.';
        });
        return;
      }
      widget.onAuthenticated();
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'No se pudo conectar: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tus finanzas,\na tu manera.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Registra gastos, organiza presupuestos y conserva tus tickets.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: _ink.withValues(alpha: .7)),
                  ),
                  const SizedBox(height: 28),
                  if (widget.supabaseReady) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                                return 'Escribe un correo válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 8) {
                                return 'Usa al menos 8 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorText(_error!),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _register ? 'Crear cuenta' : 'Entrar',
                                      ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                    _register = !_register;
                                    _error = null;
                                  }),
                            child: Text(
                              _register
                                  ? 'Ya tengo una cuenta'
                                  : 'Crear una cuenta nueva',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const _InfoCard(
                      message: 'Configura SUPABASE_URL y SUPABASE_ANON_KEY para activar el inicio de sesión y la sincronización. Tus datos locales funcionan sin conexión.',
                    ),
                    if (widget.setupMessage != null) ...[
                      const SizedBox(height: 12),
                      _ErrorText(widget.setupMessage!),
                    ],
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onGuest,
                      icon: const Icon(Icons.phone_android),
                      label: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Continuar sin cuenta'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpenseHome extends StatefulWidget {
  const ExpenseHome({
    super.key,
    required this.database,
    required this.cipher,
    required this.notifications,
    required this.sync,
    required this.signedIn,
    required this.onSignOut,
    required this.onOpenLogin,
    this.setupMessage,
  });

  final LocalDatabase database;
  final LocalCipher cipher;
  final NotificationService notifications;
  final SupabaseSync sync;
  final bool signedIn;
  final VoidCallback onSignOut;
  final VoidCallback onOpenLogin;
  final String? setupMessage;

  @override
  State<ExpenseHome> createState() => _ExpenseHomeState();
}

class _ExpenseHomeState extends State<ExpenseHome> {
  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  List<ExpenseCategory> _categories = [];
  bool _loading = true;
  bool _syncing = false;
  int _tab = 0;
  String? _error;
  final Set<String> _notifiedBudgets = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.signedIn) _synchronize(showMessage: false);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.database.getExpenses(),
        widget.database.getBudgets(),
        widget.database.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses = values[0] as List<Expense>;
        _budgets = values[1] as List<Budget>;
        _categories = values[2] as List<ExpenseCategory>;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudieron leer tus datos: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _synchronize({bool showMessage = true}) async {
    if (!widget.signedIn || _syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await widget.sync.synchronize();
      await _refresh();
      if (showMessage && mounted) {
        _message('Sincronización completada.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Error de sincronización: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  DateTime get _weekStart {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day - today.weekday + 1);
  }

  double _spentForCategory(int categoryId) {
    return _expenses
        .where(
          (expense) =>
              expense.categoryId == categoryId &&
              !expense.date.isBefore(_weekStart),
        )
        .fold(0, (total, expense) => total + expense.amount);
  }

  Future<void> _addOrEditExpense([Expense? expense]) async {
    final saved = await showDialog<Expense>(
      context: context,
      builder: (context) => ExpenseDialog(
        categories: _categories,
        cipher: widget.cipher,
        existing: expense,
      ),
    );
    if (saved == null) return;
    try {
      await widget.database.saveExpense(saved);
      await _refresh();
      final budget = _budgets
          .where((item) => item.categoryId == saved.categoryId)
          .firstOrNull;
      if (budget != null) {
        final spent = _spentForCategory(saved.categoryId);
        final percentage = (spent / budget.amount * 100).round();
        final key =
            '${budget.id}-${_weekStart.toIso8601String().substring(0, 10)}';
        if (percentage >= 80 && _notifiedBudgets.add(key)) {
          await widget.notifications.notifyBudgetThreshold(
            category: _categoryName(saved.categoryId),
            percentage: percentage,
          );
        }
      }
    } catch (error) {
      _message('No se pudo guardar el gasto: $error');
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Quieres eliminar “${expense.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.database.deleteExpense(expense.id);
      final receipt = expense.receiptPath;
      if (receipt != null) {
        final file = File(receipt);
        if (await file.exists()) await file.delete();
      }
      await _refresh();
    } catch (error) {
      _message('No se pudo eliminar el gasto: $error');
    }
  }

  Future<void> _addOrEditBudget([Budget? budget]) async {
    final saved = await showDialog<Budget?>(
      context: context,
      builder: (context) => BudgetDialog(
        categories: _categories.where((category) {
          return !_budgets.any(
            (item) => item.categoryId == category.id && item.id != budget?.id,
          );
        }).toList(),
        existing: budget,
      ),
    );
    if (saved == null) return;
    try {
      if (saved.amount <= 0) {
        await widget.database.deleteBudget(saved.id);
      } else {
        await widget.database.saveBudget(saved);
      }
      await _refresh();
    } catch (error) {
      _message('No se pudo guardar el presupuesto: $error');
    }
  }

  String _categoryName(int id) =>
      _categories
          .where((category) => category.id == id)
          .map((category) => category.name)
          .firstOrNull ??
      'Otros';

  Future<void> _showReceipt(String receiptPath) async {
    try {
      final file = File(receiptPath);
      if (!await file.exists()) {
        throw const FileSystemException('Archivo no encontrado');
      }
      final encrypted = await file.readAsBytes();
      final image = Uint8List.fromList(
        await widget.cipher.decryptBytes(utf8.decode(encrypted)),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.memory(image, fit: BoxFit.contain),
          ),
        ),
      );
    } catch (error) {
      _message('No se pudo abrir el recibo: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _budgetPage(), _expensesPage()];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tab == 0
              ? 'Mis gastos'
              : _tab == 1
              ? 'Presupuestos'
              : 'Movimientos',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (widget.signedIn)
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: _syncing ? null : () => _synchronize(),
              icon: _syncing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
            ),
          IconButton(
            tooltip: widget.signedIn ? 'Cerrar sesión' : 'Iniciar sesión',
            onPressed: widget.signedIn ? widget.onSignOut : widget.onOpenLogin,
            icon: Icon(widget.signedIn ? Icons.logout : Icons.person_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                children: [
                  if (widget.setupMessage != null) ...[
                    _InfoCard(message: widget.setupMessage!),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null) ...[
                    _ErrorText(_error!),
                    const SizedBox(height: 14),
                  ],
                  pages[_tab],
                ],
              ),
            ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditExpense(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar gasto'),
            )
          : _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditBudget(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo presupuesto'),
            )
          : FloatingActionButton(
              onPressed: () => _addOrEditExpense(),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Presupuesto',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Gastos',
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    final now = DateTime.now();
    final monthly = _expenses
        .where(
          (expense) =>
              expense.date.year == now.year && expense.date.month == now.month,
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
    final weeklyBudgets = _budgets
        .where((budget) => budget.period == 'weekly')
        .fold(0.0, (sum, budget) => sum + budget.amount);
    final weeklySpent = _expenses
        .where((expense) => !expense.date.isBefore(_weekStart))
        .fold(0.0, (sum, expense) => sum + expense.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'es_MX').format(now).toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  letterSpacing: 1.3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _money.format(monthly),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'gastado este mes',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: weeklyBudgets == 0
                      ? 0
                      : (weeklySpent / weeklyBudgets).clamp(0, 1),
                  backgroundColor: Colors.white24,
                  color: const Color(0xffb5d5a5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                weeklyBudgets == 0
                    ? 'Aún no tienes presupuestos semanales'
                    : '${_money.format(weeklySpent)} de ${_money.format(weeklyBudgets)} esta semana',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Gastos por categoría'),
        const SizedBox(height: 12),
        _categoryChart(),
        const SizedBox(height: 24),
        _SectionTitle(
          'Últimos movimientos',
          action: TextButton(
            onPressed: () => setState(() => _tab = 2),
            child: const Text('Ver todos'),
          ),
        ),
        if (_expenses.isEmpty)
          const _EmptyCard(
            icon: Icons.receipt_long_outlined,
            message: 'Aún no hay gastos. Agrega el primero con +.',
          )
        else
          ..._expenses.take(4).map(_expenseTile),
      ],
    );
  }

  Widget _categoryChart() {
    final totals = <int, double>{};
    for (final expense in _expenses.where(
      (item) => !item.date.isBefore(_weekStart),
    )) {
      totals.update(
        expense.categoryId,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    if (totals.isEmpty) {
      return const _EmptyCard(
        icon: Icons.bar_chart,
        message: 'Tus gastos semanales aparecerán aquí.',
      );
    }
    final entries = _categories
        .map((category) {
          return MapEntry(category, totals[category.id] ?? 0);
        })
        .where((entry) => entry.value > 0)
        .toList();
    return Container(
      height: 235,
      padding: const EdgeInsets.fromLTRB(10, 20, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              entries
                  .map((entry) => entry.value)
                  .reduce((a, b) => a > b ? a : b) *
              1.25,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[index].key.name.split(' ').first,
                      style: const TextStyle(fontSize: 10, color: _ink),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (index) {
            final item = entries[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.value,
                  width: 25,
                  borderRadius: BorderRadius.circular(7),
                  color: Color(item.key.colorValue),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _budgetPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoCard(
          message: 'Límites semanales por categoría. Recibirás un aviso al superar el 80%.',
        ),
        const SizedBox(height: 18),
        if (_budgets.isEmpty)
          const _EmptyCard(
            icon: Icons.savings_outlined,
            message: 'Todavía no tienes presupuestos. Crea uno para empezar.',
          )
        else
          ..._budgets.map((budget) {
            final spent = _spentForCategory(budget.categoryId);
            final ratio = spent / budget.amount;
            final category = _categories.firstWhere(
              (item) => item.id == budget.categoryId,
              orElse: () => ExpenseCategory.defaults.last,
            );
            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _CategoryIcon(category: category),
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: ratio.clamp(0, 1),
                          color: ratio >= .8 ? Colors.deepOrange : _green,
                          backgroundColor: _cream,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${_money.format(spent)} de ${_money.format(budget.amount)}',
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Editar presupuesto',
                  onPressed: () => _addOrEditBudget(budget),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _expensesPage() {
    if (_expenses.isEmpty) {
      return const _EmptyCard(
        icon: Icons.receipt_long_outlined,
        message: 'Todavía no registras movimientos.',
      );
    }
    final grouped = <String, List<Expense>>{};
    for (final expense in _expenses) {
      final day = DateFormat('yyyy-MM-dd').format(expense.date);
      grouped.putIfAbsent(day, () => []).add(expense);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final day = DateTime.parse(entry.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
              child: Text(
                DateFormat('EEEE d MMMM', 'es_MX').format(day),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            ...entry.value.map(_expenseTile),
          ],
        );
      }).toList(),
    );
  }

  Widget _expenseTile(Expense expense) {
    final category = _categories.firstWhere(
      (item) => item.id == expense.categoryId,
      orElse: () => ExpenseCategory.defaults.last,
    );
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: expense.receiptPath == null
            ? null
            : () => _showReceipt(expense.receiptPath!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: _CategoryIcon(category: category),
        title: Text(
          expense.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${category.name} · ${DateFormat('d MMM', 'es_MX').format(expense.date)}${expense.receiptPath == null ? '' : ' · Ticket'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _money.format(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _addOrEditExpense(expense);
                if (value == 'delete') _deleteExpense(expense);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({
    super.key,
    required this.categories,
    required this.cipher,
    this.existing,
  });

  final List<ExpenseCategory> categories;
  final LocalCipher cipher;
  final Expense? existing;

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late int _categoryId;
  late DateTime _date;
  String? _receiptPath;
  String? _newReceipt;
  bool _saving = false;
  String? _cameraError;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _categoryId = existing?.categoryId ?? widget.categories.first.id;
    _date = existing?.date ?? DateTime.now();
    _receiptPath = existing?.receiptPath;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() {
          _newReceipt = image.path;
          _cameraError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _cameraError = 'No se pudo abrir la cámara: $error');
      }
    }
  }

  Future<String?> _persistReceipt(String expenseId) async {
    final imagePath = _newReceipt;
    if (imagePath == null) return _receiptPath;
    final directory = await getApplicationDocumentsDirectory();
    final receipts = Directory(path.join(directory.path, 'receipts'));
    await receipts.create(recursive: true);
    final output = File(path.join(receipts.path, '$expenseId.enc'));
    final clearBytes = await File(imagePath).readAsBytes();
    final encrypted = await widget.cipher.encryptBytes(clearBytes);
    await output.writeAsBytes(utf8.encode(encrypted), flush: true);
    return output.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id =
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString();
      final title = _title.text.trim();
      final amount = double.parse(_amount.text.trim().replaceAll(',', '.'));
      final receiptPath = await _persistReceipt(id);
      if (mounted) {
        Navigator.pop(
          context,
          Expense(
            id: id,
            title: title,
            amount: amount,
            date: _date,
            categoryId: _categoryId,
            receiptPath: receiptPath,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _cameraError = 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo gasto' : 'Editar gasto'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.length < 2
                        ? 'Escribe al menos 2 caracteres.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Importe',
                    prefixText: '\$ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Escribe un importe mayor que cero.';
                    }
                    if (amount > 99999999) {
                      return 'El importe excede el límite permitido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _categoryId = value);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) setState(() => _date = selected);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('d MMMM yyyy', 'es_MX').format(_date)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _newReceipt != null || _receiptPath != null
                        ? 'Cambiar foto del ticket'
                        : 'Fotografiar ticket',
                  ),
                ),
                if (_newReceipt != null || _receiptPath != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'La imagen se cifra antes de guardarse en el dispositivo.',
                    ),
                  ),
                if (_cameraError != null) ...[
                  const SizedBox(height: 8),
                  _ErrorText(_cameraError!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class BudgetDialog extends StatefulWidget {
  const BudgetDialog({super.key, required this.categories, this.existing});

  final List<ExpenseCategory> categories;
  final Budget? existing;

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late int _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId ?? widget.categories.first.id;
    _amount = TextEditingController(
      text: widget.existing?.amount.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Presupuesto semanal' : 'Editar presupuesto',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: widget.existing == null
                  ? (value) {
                      if (value != null) setState(() => _categoryId = value);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Límite semanal',
                prefixText: '\$ ',
              ),
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                if (amount == null || !amount.isFinite || amount <= 0) {
                  return 'Escribe un límite mayor que cero.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              Budget(
                id: widget.existing!.id,
                categoryId: widget.existing!.categoryId,
                amount: 0,
              ),
            ),
            child: const Text('Eliminar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final id = widget.existing?.id ?? _categoryId.toString();
            Navigator.pop(
              context,
              Budget(
                id: id,
                categoryId: _categoryId,
                amount: double.parse(_amount.text.trim().replaceAll(',', '.')),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final ExpenseCategory category;

  IconData get _icon => switch (category.id) {
    1 => Icons.restaurant_outlined,
    2 => Icons.directions_bus_outlined,
    3 => Icons.home_outlined,
    4 => Icons.health_and_safety_outlined,
    _ => Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .14),
      child: Icon(_icon, color: color),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        ?action,
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff1cf),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xff896315)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xff684e15), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffffe7e4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xff9a3025), fontSize: 13),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: _green),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
