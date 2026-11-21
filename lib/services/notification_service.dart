import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await scheduleWeeklyReminder();
  }

  Future<void> scheduleWeeklyReminder() async {
    final now = DateTime.now();
    var daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0 &&
        (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
      daysUntilMonday = 7;
    }
    final nextMonday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilMonday,
      9,
    );
    await _plugin.zonedSchedule(
      80,
      'Revisa tu presupuesto semanal',
      'Consulta tus gastos y mantén tus finanzas bajo control.',
      tz.TZDateTime.from(nextMonday, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'presupuestos_semanales',
          'Recordatorios de presupuesto',
          channelDescription: 'Avisos semanales de revisión de presupuesto',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> notifyBudgetThreshold({
    required String category,
    required int percentage,
  }) async {
    await _plugin.show(
      81,
      'Presupuesto cerca del límite',
      'Has utilizado el $percentage% del presupuesto de $category.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alertas_presupuesto',
          'Alertas de presupuesto',
          channelDescription: 'Avisos al acercarse al límite de gasto',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
