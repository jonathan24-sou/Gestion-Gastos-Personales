import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_personales/main.dart';
import 'package:gastos_personales/models.dart';
import 'package:gastos_personales/services/local_cipher.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  testWidgets('login screen offers an offline guest path', (tester) async {
    var continuedAsGuest = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          supabaseReady: false,
          onGuest: () => continuedAsGuest = true,
          onAuthenticated: () {},
        ),
      ),
    );

    expect(find.text('Continuar sin cuenta'), findsOneWidget);
    await tester.tap(find.text('Continuar sin cuenta'));
    expect(continuedAsGuest, isTrue);
  });

  testWidgets('expense form rejects a non-positive amount', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseDialog(
            categories: ExpenseCategory.defaults,
            cipher: LocalCipher(const FlutterSecureStorage()),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Café');
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un importe mayor que cero.'), findsOneWidget);
  });
}
