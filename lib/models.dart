class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
  });

  final int id;
  final String name;
  final int iconCode;
  final int colorValue;

  static const defaults = <ExpenseCategory>[
    ExpenseCategory(
      id: 1,
      name: 'Alimentación',
      iconCode: 0xe25a,
      colorValue: 0xffe98a62,
    ),
    ExpenseCategory(
      id: 2,
      name: 'Transporte',
      iconCode: 0xe1d7,
      colorValue: 0xff5d9c91,
    ),
    ExpenseCategory(
      id: 3,
      name: 'Hogar',
      iconCode: 0xe318,
      colorValue: 0xff7588bc,
    ),
    ExpenseCategory(
      id: 4,
      name: 'Salud',
      iconCode: 0xe3f3,
      colorValue: 0xffc77791,
    ),
    ExpenseCategory(
      id: 5,
      name: 'Otros',
      iconCode: 0xe54e,
      colorValue: 0xffba9957,
    ),
  ];
}

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.receiptPath,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final int categoryId;
  final String? receiptPath;
}

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    this.period = 'weekly',
  });

  final String id;
  final int categoryId;
  final double amount;
  final String period;
}
