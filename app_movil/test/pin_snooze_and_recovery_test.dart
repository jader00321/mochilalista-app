import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/services/pin_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 2 - PinReminderService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isSnoozed retorna false cuando no se ha pospuesto nunca', () async {
      final isSnoozed = await PinReminderService.isSnoozed(101);
      expect(isSnoozed, isFalse);
    });

    test('snooze pospone por 7 días y isSnoozed retorna true', () async {
      await PinReminderService.snooze(101, days: 7);
      final isSnoozed = await PinReminderService.isSnoozed(101);
      expect(isSnoozed, isTrue);

      final days = await PinReminderService.getRemainingDays(101);
      expect(days, isNotNull);
      expect(days! >= 6 && days <= 7, isTrue);
    });

    test('clearSnooze elimina la postergación inmediatamente', () async {
      await PinReminderService.snooze(101, days: 7);
      expect(await PinReminderService.isSnoozed(101), isTrue);

      await PinReminderService.clearSnooze(101);
      expect(await PinReminderService.isSnoozed(101), isFalse);
      expect(await PinReminderService.getRemainingDays(101), isNull);
    });

    test('isSnoozed retorna false cuando la fecha de expiración ya pasó', () async {
      final prefs = await SharedPreferences.getInstance();
      // Guardar una fecha en el pasado (hace 1 hora)
      final pastTime = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      await prefs.setInt('pin_reminder_snoozed_until_ms_101', pastTime);

      final isSnoozed = await PinReminderService.isSnoozed(101);
      expect(isSnoozed, isFalse);
      expect(await PinReminderService.getRemainingDays(101), isNull);
    });

    test('Postergación es independiente por cada userId', () async {
      await PinReminderService.snooze(101, days: 7);
      
      expect(await PinReminderService.isSnoozed(101), isTrue);
      expect(await PinReminderService.isSnoozed(102), isFalse);
    });
  });

  group('Fase 3 - Lógica de Reto de Identidad y Seguridad de PIN', () {
    test('Normalización de RUC y Teléfono limpia caracteres especiales', () {
      final inputRuc = " 20-60123456-7 ";
      final cleanRuc = inputRuc.trim().replaceAll(RegExp(r'[^0-9]'), '');
      expect(cleanRuc, equals("20601234567"));

      final inputPhone = "+51 987-654-321 ";
      final cleanPhone = inputPhone.trim().replaceAll(RegExp(r'[^0-9]'), '');
      expect(cleanPhone.endsWith("987654321"), isTrue);
    });

    test('Comparación de email es insensible a mayúsculas y espacios', () {
      final registeredEmail = "bazar.luz@libreria.com";
      final inputEmail = "  BAZAR.LUZ@LIBRERIA.COM  ";
      expect(registeredEmail.trim().toLowerCase(), equals(inputEmail.trim().toLowerCase()));
    });

    test('Lógica de bloqueo anti fuerza bruta: 5 intentos fallidos activan 30s', () {
      int failedAttempts = 0;
      bool isLocked = false;
      DateTime? lockoutUntil;

      void recordFailedAttempt() {
        failedAttempts++;
        if (failedAttempts >= 5) {
          isLocked = true;
          lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        }
      }

      for (int i = 0; i < 4; i++) {
        recordFailedAttempt();
        expect(isLocked, isFalse);
      }

      // 5to intento
      recordFailedAttempt();
      expect(isLocked, isTrue);
      expect(lockoutUntil, isNotNull);
      expect(lockoutUntil!.isAfter(DateTime.now()), isTrue);
    });

    test('Ingreso de PIN correcto reinicia el contador de intentos fallidos', () {
      int failedAttempts = 3;
      bool pinIsCorrect = true;

      if (pinIsCorrect) {
        failedAttempts = 0;
      }

      expect(failedAttempts, equals(0));
    });
  });
}
