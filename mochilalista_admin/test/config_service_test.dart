import 'dart:io';
import 'package:test/test.dart';
import '../lib/config_service.dart';

void main() {
  late Directory tempDir;
  late Directory dataDir;
  late Directory backupsDir;
  late ConfigService configService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ml_config_test_');
    dataDir = Directory('${tempDir.path}/data');
    backupsDir = Directory('${tempDir.path}/backups');
    configService = ConfigService(
      dataDirectory: dataDir,
      backupsDirectory: backupsDir,
    );
    await configService.init();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('1. Inicialización y Valores de Fábrica Oficiales', () {
    test('Crea owner_config.json automáticamente si no existe', () async {
      expect(await configService.configFile.exists(), isTrue);
    });

    test('Identidad legal y Yape/Plin oficiales preconfigurados', () {
      final legal = configService.legalIdentity;
      expect(legal['author_full_name'], equals('Julio Angello Vasquez Navarro'));
      expect(legal['commercial_name'], equals('MochilaLista'));
      expect(legal['support_phone'], equals('+51 922 836 879'));

      final pm = configService.paymentMethods;
      expect(pm['yape_plin_phone'], equals('922836879'));
      expect(pm['yape_plin_holder'], equals('Julio Angello Vasquez Navarro'));
    });

    test('Cuentas BCP y BBVA inicializadas limpias como cadenas vacías (cero XXXX)', () {
      final pm = configService.paymentMethods;
      expect(pm['bcp_account_number'], equals(''));
      expect(pm['bcp_cci'], equals(''));
      expect(pm['bcp_account_holder'], equals(''));
      expect(pm['bbva_account_number'], equals(''));
      expect(pm['bbva_cci'], equals(''));
      expect(pm['bbva_account_holder'], equals(''));

      // Verificar que ninguna clave contiene placeholders "XXXX"
      final asString = pm.toString();
      expect(asString.contains('XXXX'), isFalse);
    });

    test('Catálogo oficial sincronizado con 9 ítems y cuotas IA acumulativas', () {
      final catalog = configService.catalog;
      expect(catalog.containsKey('TRIAL'), isTrue);
      expect(catalog['TRIAL']['price'], equals(0.0));
      expect(catalog['TRIAL']['ai_credits'], equals(50));

      expect(catalog.containsKey('MENSUAL'), isTrue);
      expect(catalog['MENSUAL']['price'], equals(35.0));
      expect(catalog['MENSUAL']['ai_credits'], equals(50));

      expect(catalog.containsKey('TRIMESTRAL'), isTrue);
      expect(catalog['TRIMESTRAL']['price'], equals(90.0));
      expect(catalog['TRIMESTRAL']['ai_credits'], equals(180));

      expect(catalog.containsKey('SEMESTRAL'), isTrue);
      expect(catalog['SEMESTRAL']['price'], equals(160.0));
      expect(catalog['SEMESTRAL']['ai_credits'], equals(450));

      expect(catalog.containsKey('ANUAL'), isTrue);
      expect(catalog['ANUAL']['price'], equals(280.0));
      expect(catalog['ANUAL']['ai_credits'], equals(1200));

      expect(catalog.containsKey('PERPETUO_LIBERADO'), isTrue);
      expect(catalog['PERPETUO_LIBERADO']['price'], equals(850.0));
      expect(catalog['PERPETUO_LIBERADO']['ai_credits'], equals(200));

      expect(catalog.containsKey('PASE_ACTUALIZACION_ANUAL'), isTrue);
      expect(catalog['PASE_ACTUALIZACION_ANUAL']['price'], equals(150.0));
      expect(catalog['PASE_ACTUALIZACION_ANUAL']['ai_credits'], equals(100));

      expect(catalog.containsKey('RECARGA_IA_150'), isTrue);
      expect(catalog['RECARGA_IA_150']['price'], equals(20.0));
      expect(catalog['RECARGA_IA_150']['ai_credits'], equals(150));

      expect(catalog.containsKey('EXTENSION_CORTESIA'), isTrue);
      expect(catalog['EXTENSION_CORTESIA']['price'], equals(0.0));
      expect(catalog['EXTENSION_CORTESIA']['days'], equals(7));

      expect(catalog.containsKey('HARDWARE_MIGRATION_FEE'), isTrue);
      expect(configService.migrationFee, equals(40.0));
    });
  });

  group('2. Persistencia, Recarga Real en Disco y Respaldos Automáticos', () {
    test('saveConfig persiste en disco y genera snapshot previo en backups/', () async {
      final initialBackups = backupsDir.listSync().length;
      expect(initialBackups, equals(0));

      // Modificar precios y cuentas
      final current = Map<String, dynamic>.from(configService.config);
      final catalog = Map<String, dynamic>.from(current['catalog'] as Map);
      catalog['MENSUAL'] = {
        'price': 40.0,
        'days': 30,
        'ai_credits': 60,
        'label': 'Plan Mensual Promo',
      };
      current['catalog'] = catalog;

      final pm = Map<String, dynamic>.from(current['payment_methods'] as Map);
      pm['bcp_account_number'] = '191-99887766-0-55';
      pm['bcp_cci'] = '002-191-009988776605-55';
      pm['bcp_account_holder'] = 'Julio Vasquez';
      current['payment_methods'] = pm;

      await configService.saveConfig(current);

      // 1. Debe haber creado un snapshot en backups/
      final backups = backupsDir.listSync();
      expect(backups.length, equals(1));
      expect(backups.first.path.contains('owner_config_backup_'), isTrue);
      expect(backups.first.path.contains('pre_save'), isTrue);

      // 2. Nueva instancia debe recargar los valores modificados desde disco
      final reloadedService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await reloadedService.init();

      expect(reloadedService.getPlanPrice('MENSUAL'), equals(40.0));
      expect(reloadedService.getPlanAiCredits('MENSUAL'), equals(60));
      expect(reloadedService.paymentMethods['bcp_account_number'], equals('191-99887766-0-55'));
    });

    test('Sanitiza valores negativos en catálogo impidiendo precios o días < 0', () async {
      final current = Map<String, dynamic>.from(configService.config);
      final catalog = Map<String, dynamic>.from(current['catalog'] as Map);
      catalog['MENSUAL'] = {
        'price': -20.0,
        'days': -5,
        'ai_credits': -10,
        'label': 'Plan Invalido',
      };
      current['catalog'] = catalog;

      await configService.saveConfig(current);

      expect(configService.getPlanPrice('MENSUAL'), equals(0.0));
      expect(configService.getPlanDays('MENSUAL'), equals(0));
      expect(configService.getPlanAiCredits('MENSUAL'), equals(0));
    });
  });

  group('3. Motor de Renderizado de Plantillas y Supresión de Cuentas Vacías', () {
    test('Con cuentas BCP y BBVA vacías no se genera ninguna línea bancaria ni XXXX', () {
      final rendered = configService.renderTemplate('expiring_reminder', {
        'titular': 'Carlos Mendoza',
        'negocio': 'Librería Central',
        'dias_restantes': 3,
        'vencimiento': '2026-11-22',
      });

      expect(rendered.contains('Carlos Mendoza'), isTrue);
      expect(rendered.contains('Librería Central'), isTrue);
      expect(rendered.contains('Yape / Plin: 922836879'), isTrue);
      expect(rendered.contains('BCP'), isFalse);
      expect(rendered.contains('BBVA'), isFalse);
      expect(rendered.contains('XXXX'), isFalse);
    });

    test('Al configurar cuenta BCP se renderiza limpia con número y CCI', () async {
      final current = Map<String, dynamic>.from(configService.config);
      final pm = Map<String, dynamic>.from(current['payment_methods'] as Map);
      pm['bcp_account_number'] = '191-12345678-0-12';
      pm['bcp_cci'] = '002-191-001234567801-23';
      pm['bcp_account_holder'] = 'Julio Angello Vasquez Navarro';
      current['payment_methods'] = pm;
      await configService.saveConfig(current);

      final rendered = configService.renderTemplate('expiring_reminder', {
        'titular': 'Carlos Mendoza',
        'negocio': 'Librería Central',
        'dias_restantes': 3,
        'vencimiento': '2026-11-22',
      });

      expect(rendered.contains('🏦 BCP: 191-12345678-0-12 (CCI: 002-191-001234567801-23)'), isTrue);
      expect(rendered.contains('BBVA'), isFalse);
    });

    test('Plantilla license_issued coloca el código en línea limpia e independiente', () {
      const sampleToken = 'ML9-eyJkIjoiTUwtOUs0QiIsInAiOiJNRU5TVUFMIiwiaWF0IjoiMjAyNi0xMS0xOSJ9.c2lnbmF0dXJl';
      final rendered = configService.renderTemplate('license_issued', {
        'titular': 'Carlos Mendoza',
        'negocio': 'Librería Central',
        'plan': 'MENSUAL',
        'dias': 30,
        'device_id': 'ML-9K4B',
        'vencimiento': '2026-12-19',
        'creditos_ia': 50,
        'codigo': sampleToken,
      });

      // El parser inteligente de app_movil busca líneas con regex ML9-...
      final lines = rendered.split('\n').map((l) => l.trim()).toList();
      expect(lines.contains(sampleToken), isTrue,
          reason: 'El código oficial ML9 debe aparecer en una línea limpia sin texto antes o después');
    });
  });

  group('4. Restauración de Fábrica (resetToDefaults)', () {
    test('Restaura valores originales y crea snapshot de respaldo previo', () async {
      // Modificar algo primero
      final current = Map<String, dynamic>.from(configService.config);
      final catalog = Map<String, dynamic>.from(current['catalog'] as Map);
      catalog['MENSUAL'] = {'price': 999.0, 'days': 1, 'ai_credits': 1};
      current['catalog'] = catalog;
      await configService.saveConfig(current);

      final backupsBefore = backupsDir.listSync().length;

      // Ejecutar reset
      await configService.resetToDefaults();

      // Debe haber creado otro backup con 'pre_reset'
      final backupsAfter = backupsDir.listSync();
      expect(backupsAfter.length, equals(backupsBefore + 1));
      expect(backupsAfter.any((f) => f.path.contains('pre_reset')), isTrue);

      // El precio debe haber vuelto a 35.0
      expect(configService.getPlanPrice('MENSUAL'), equals(35.0));
      expect(configService.getPlanAiCredits('MENSUAL'), equals(50));
    });
  });
}
