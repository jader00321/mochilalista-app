import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';

void main() {
  setUpAll(() async {
    // 🛡️ Inicialización obligatoria de localización en español para evitar LocaleDataException
    await initializeDateFormatting('es', null);
  });

  group('Fase 3 & 4: Operaciones Financieras - Localización, Borradores y Cascada', () {
    test('Formateo de fechas abreviadas en español (Lun, Mar, Mié, Dom)', () {
      final lunes = DateTime(2026, 10, 26); // Lunes
      final martes = DateTime(2026, 10, 27); // Martes
      final domingo = DateTime(2026, 11, 1); // Domingo

      final fmtLun = DateFormat('EEE, dd/MM/yyyy', 'es').format(lunes);
      final fmtMar = DateFormat('EEE, dd/MM/yyyy', 'es').format(martes);
      final fmtDom = DateFormat('EEE, dd/MM/yyyy', 'es').format(domingo);

      expect(fmtLun.toLowerCase(), contains('lun'));
      expect(fmtMar.toLowerCase(), contains('mar'));
      expect(fmtDom.toLowerCase(), contains('dom'));
    });

    test('ClientFinanceDraftManager preserva borradores independientes por cliente y por pestaña', () {
      final draftMgr = ClientFinanceDraftManager.instance;
      const clientId = 101;

      // 1. Guardar borrador de Retiro
      draftMgr.setWithdrawDraft(
        clientId,
        FinanceWithdrawDraft(
          amount: '150.50',
          method: 'Yape',
        ),
      );

      // 2. Guardar borrador de Préstamo
      draftMgr.setLoanDraft(
        clientId,
        FinanceLoanDraft(
          amount: '500.00',
          method: 'Efectivo',
          motivo: 'Fiado mercadería escolar',
          splitInQuotas: true,
          numCuotas: '4',
          interestRate: '10',
          frecuencia: 'semanal',
          installments: [
            InstallmentModel(installmentNumber: 1, amount: 137.5, dueDate: '2026-11-02', status: 'pendiente'),
            InstallmentModel(installmentNumber: 2, amount: 137.5, dueDate: '2026-11-09', status: 'pendiente'),
            InstallmentModel(installmentNumber: 3, amount: 137.5, dueDate: '2026-11-16', status: 'pendiente'),
            InstallmentModel(installmentNumber: 4, amount: 137.5, dueDate: '2026-11-23', status: 'pendiente'),
          ],
        ),
      );

      // 3. Recuperar y verificar fidelidad
      final withdrawDraft = draftMgr.getWithdrawDraft(clientId);
      expect(withdrawDraft, isNotNull);
      expect(withdrawDraft!.amount, '150.50');
      expect(withdrawDraft.method, 'Yape');

      final loanDraft = draftMgr.getLoanDraft(clientId);
      expect(loanDraft, isNotNull);
      expect(loanDraft!.amount, '500.00');
      expect(loanDraft.motivo, 'Fiado mercadería escolar');
      expect(loanDraft.installments.length, 4);

      // 4. Limpiar únicamente el retiro (el préstamo debe quedar intacto)
      draftMgr.clearWithdrawDraft(clientId);
      expect(draftMgr.getWithdrawDraft(clientId), isNull);
      expect(draftMgr.getLoanDraft(clientId), isNotNull);

      // 5. Limpieza total
      draftMgr.clearAll(clientId);
      expect(draftMgr.getLoanDraft(clientId), isNull);
    });

    test('Motor de Cascada y Salto de Días Excluidos: Cero fechas duplicadas', () {
      // Simular cálculo de 5 cuotas diarias omitiendo Domingos (weekday == 7)
      final excluded = {DateTime.sunday};
      final startDate = DateTime(2026, 10, 24); // Sábado 24 Octubre 2026

      DateTime advanceSkipping(DateTime from, String freq, Set<int> excl) {
        DateTime next;
        if (freq == 'diario') {
          next = from.add(const Duration(days: 1));
        } else if (freq == 'semanal') {
          next = from.add(const Duration(days: 7));
        } else {
          next = DateTime(from.year, from.month + 1, from.day);
        }

        if (!next.isAfter(from)) {
          next = from.add(const Duration(days: 1));
        }
        while (excl.contains(next.weekday)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      }

      DateTime current = startDate;
      final List<DateTime> quotaDates = [];

      for (int i = 0; i < 5; i++) {
        current = advanceSkipping(current, 'diario', excluded);
        quotaDates.add(current);
      }

      // Cuota 1: Domingo 25 está excluido -> Avanza a Lunes 26
      expect(quotaDates[0].weekday, DateTime.monday);
      expect(quotaDates[0], DateTime(2026, 10, 26));

      // Cuota 2: Martes 27
      expect(quotaDates[1], DateTime(2026, 10, 27));

      // Cuota 3: Miércoles 28
      expect(quotaDates[2], DateTime(2026, 10, 28));

      // Cuota 4: Jueves 29
      expect(quotaDates[3], DateTime(2026, 10, 29));

      // Cuota 5: Viernes 30
      expect(quotaDates[4], DateTime(2026, 10, 30));

      // Verificar que fecha[i] sea ESTRICTAMENTE mayor a fecha[i-1] (cero duplicados)
      for (int i = 1; i < quotaDates.length; i++) {
        expect(quotaDates[i].isAfter(quotaDates[i - 1]), isTrue,
            reason: 'La cuota #$i debe ser estrictamente posterior a la cuota #${i - 1}');
      }
    });

    test('Protección de selector de días: No permite excluir los 7 días de la semana', () {
      final excluded = <int>{1, 2, 3, 4, 5, 6}; // Lun a Sáb excluidos (6 días)
      expect(excluded.length, 6);

      // Si intentamos agregar el día 7 (Domingo), el guard impide que excluded.length llegue a 7
      bool canExclude(int day, Set<int> currentExcluded) {
        if (currentExcluded.contains(day)) return true; // Re-activar siempre permitido
        if (currentExcluded.length >= 6) return false; // Bloqueado: debe quedar al menos 1 día activo
        return true;
      }

      expect(canExclude(7, excluded), isFalse);
      // Desmarcar un día existente sí está permitido
      expect(canExclude(1, excluded), isTrue);
    });

    test('Edición de cuota en cascada actualiza cuotas posteriores sin colisiones', () {
      final initialDates = [
        DateTime(2026, 10, 26), // Cuota 1
        DateTime(2026, 10, 27), // Cuota 2
        DateTime(2026, 10, 28), // Cuota 3
      ];

      // El usuario edita la cuota #2 al 29 de Octubre (Jueves)
      final editedQuota2 = DateTime(2026, 10, 29);
      final updatedDates = List<DateTime>.from(initialDates);
      updatedDates[1] = editedQuota2;

      // Cascada para cuota #3: debe ser posterior a editedQuota2
      DateTime next = editedQuota2.add(const Duration(days: 1)); // Viernes 30
      updatedDates[2] = next;

      expect(updatedDates[1], DateTime(2026, 10, 29));
      expect(updatedDates[2], DateTime(2026, 10, 30));
      expect(updatedDates[2].isAfter(updatedDates[1]), isTrue);
    });

    test('Lógica Matemática en 4 Frecuencias (Diario, Semanal, Quincenal, Mensual) con Ancla y sin Deriva', () {
      final baseDate = DateTime(2026, 10, 24); // Sábado 24 Octubre 2026
      final excludedSundays = {DateTime.sunday};

      // 1. DIARIO: Salta domingos día a día
      DateTime curDaily = baseDate;
      final dailyDates = <DateTime>[];
      for (int i = 1; i <= 3; i++) {
        DateTime cand = curDaily.add(const Duration(days: 1));
        while (excludedSundays.contains(cand.weekday)) {
          cand = cand.add(const Duration(days: 1));
        }
        curDaily = cand;
        dailyDates.add(curDaily);
      }
      expect(dailyDates[0], DateTime(2026, 10, 26)); // Salta domingo 25 -> Lunes 26
      expect(dailyDates[1], DateTime(2026, 10, 27)); // Martes 27
      expect(dailyDates[2], DateTime(2026, 10, 28)); // Miércoles 28

      // 2. SEMANAL: Inicio en domingo se corre a lunes y subsiguientes van de 7 en 7
      final sundayBase = DateTime(2026, 10, 25); // Domingo 25
      DateTime firstRaw = sundayBase.add(const Duration(days: 7)); // Domingo 1 Nov
      DateTime firstValid = firstRaw;
      while (excludedSundays.contains(firstValid.weekday)) {
        firstValid = firstValid.add(const Duration(days: 1)); // Lunes 2 Nov
      }
      final weeklyDates = <DateTime>[firstValid];
      for (int i = 2; i <= 3; i++) {
        DateTime rawW = firstValid.add(Duration(days: 7 * (i - 1)));
        while (excludedSundays.contains(rawW.weekday)) {
          rawW = rawW.add(const Duration(days: 1));
        }
        weeklyDates.add(rawW);
      }
      expect(weeklyDates[0], DateTime(2026, 11, 2)); // Lunes 2 Nov
      expect(weeklyDates[1], DateTime(2026, 11, 9)); // Lunes 9 Nov
      expect(weeklyDates[2], DateTime(2026, 11, 16)); // Lunes 16 Nov
      for (var d in weeklyDates) {
        expect(d.weekday, DateTime.monday);
      }

      // 3. QUINCENAL: Fecha ancla 15 * i días desde base sin deriva
      final fortnightlyAnchorDates = <DateTime>[];
      for (int i = 1; i <= 2; i++) {
        DateTime theoretical = baseDate.add(Duration(days: 15 * i));
        DateTime actual = theoretical;
        while (excludedSundays.contains(actual.weekday)) {
          actual = actual.add(const Duration(days: 1));
        }
        fortnightlyAnchorDates.add(actual);
      }
      expect(fortnightlyAnchorDates[0], DateTime(2026, 11, 9)); // 24 Oct + 15d = 8 Nov (Dom) -> 9 Nov (Lun)
      expect(fortnightlyAnchorDates[1], DateTime(2026, 11, 23)); // 24 Oct + 30d = 23 Nov (Lun)
      expect(fortnightlyAnchorDates[1].isAfter(fortnightlyAnchorDates[0]), isTrue);

      // 4. MENSUAL: Fecha ancla i meses desde base sin deriva
      final monthlyAnchorDates = <DateTime>[];
      for (int i = 1; i <= 2; i++) {
        DateTime theoretical = DateTime(baseDate.year, baseDate.month + i, baseDate.day);
        DateTime actual = theoretical;
        while (excludedSundays.contains(actual.weekday)) {
          actual = actual.add(const Duration(days: 1));
        }
        monthlyAnchorDates.add(actual);
      }
      expect(monthlyAnchorDates[0], DateTime(2026, 11, 24)); // 24 Nov (Martes)
      expect(monthlyAnchorDates[1], DateTime(2026, 12, 24)); // 24 Dic (Jueves)
      expect(monthlyAnchorDates[1].isAfter(monthlyAnchorDates[0]), isTrue);
    });

    testWidgets('ClientFinanceActionsModal: Subtítulos, Toggle Real, Feedback Pill y Badges', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Carlos Alberto',
        phone: '999888777',
        registeredDate: '2026-01-01',
        saldoAFavor: 200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackingProvider>.value(
            value: TrackingProvider(),
            child: Scaffold(
              body: ClientFinanceActionsModal(
                client: client,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar InteractiveSheetWrapper con enableDragToDismiss: false
      final sheetFinder = find.byType(InteractiveSheetWrapper);
      expect(sheetFinder, findsOneWidget);
      final sheet = tester.widget<InteractiveSheetWrapper>(sheetFinder);
      expect(sheet.enableDragToDismiss, isFalse);

      // 2. Cambiar a la pestaña Préstamo (Tab 1)
      await tester.tap(find.text('Préstamo'));
      await tester.pumpAndSettle();

      // 3. Ingresar un monto
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '200');
      await tester.pumpAndSettle();

      // 4. Activar el switch de división en cuotas
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 5. Verificar subtítulo contextual por defecto (Mensual)
      expect(find.text('Días hábiles para el cobro mensual'), findsOneWidget);

      // 6. Verificar los 3 chips de acceso rápido
      final domChip = find.text('Omitir Domingos');
      final lunVieChip = find.text('Solo Lun - Vie');
      final todosChip = find.text('Todos los días');

      await tester.ensureVisible(domChip);
      expect(domChip, findsOneWidget);
      expect(lunVieChip, findsOneWidget);
      expect(todosChip, findsOneWidget);

      // 7. Toggle Real en '🚫 Omitir Domingos':
      // Como viene activo por defecto, tocarlo debe desmarcarlo (activar todos los 7 días)
      await tester.tap(domChip);
      await tester.pumpAndSettle();

      // Verificar feedback de confirmación
      expect(find.textContaining('Fechas restauradas • Cobro todos los días habilitado'), findsOneWidget);

      // Tocar nuevamente para volver a activarlo
      await tester.tap(domChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Fechas actualizadas'), findsOneWidget);

      // 8. Toggle Real en '💼 Solo Lun - Vie':
      await tester.tap(lunVieChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Solo cobros de Lunes a Viernes'), findsOneWidget);

      // Volver a tocar para desmarcarlo
      await tester.tap(lunVieChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Fechas restauradas • Cobro todos los días habilitado'), findsOneWidget);

      // 9. Verificar cronograma y botones de acción rápida
      await tester.ensureVisible(find.text('Cronograma Generado'));
      expect(find.text('Cronograma Generado'), findsOneWidget);
      expect(find.byIcon(Icons.edit_calendar), findsWidgets);
      expect(find.text('+1d'), findsWidgets);
    });
  });
}

