import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';

void main() {
  group('Fase 5: Rotación Automática de Snapshots y Blindaje de Backups', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_backup_rotation_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. DatabaseService: 35 escrituras automáticas consecutivas retienen exactamente 30 snapshots', () async {
      final dataDir = '${tempDir.path}/data';
      final backupDir = '${tempDir.path}/backups';
      final releasesDir = '${tempDir.path}/releases';

      final dbService = DatabaseService(
        dataDir: dataDir,
        backupDir: backupDir,
        releasesDir: releasesDir,
        maxAutoSnapshots: 30,
      );
      await dbService.init();

      // Ejecutar 35 escrituras automáticas consecutivas
      for (int i = 0; i < 35; i++) {
        await dbService.saveClients(
          [
            {
              'id': 'CLI-001',
              'business_name': 'Librería Test $i',
              'phone': '987654321',
            }
          ],
          reason: 'write_$i',
        );
        // Pequeño retardo para asegurar marcas de tiempo secuenciales
        await Future.delayed(const Duration(milliseconds: 2));
      }

      final dir = Directory(backupDir);
      final files = dir.listSync().whereType<File>().toList();

      final autoSnapshots = files.where((f) {
        final name = f.uri.pathSegments.last;
        final lower = name.toLowerCase();
        final isDbSnapshot = name.startsWith('sandbox_') || name.startsWith('prod_');
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('pre_import');
        return isDbSnapshot && !isProtected && name.endsWith('.json');
      }).toList();

      expect(
        autoSnapshots.length,
        equals(30),
        reason: 'Deben permanecer exactamente 30 snapshots automáticos en backups/',
      );

      // Verificar que el snapshot más reciente (write_34) existe
      final hasLatest = autoSnapshots.any((f) => f.path.contains('write_34'));
      expect(hasLatest, isTrue, reason: 'El snapshot más reciente debe estar conservado');
    });

    test('2. Preservación Indefinida de Backups Manuales y de Bóveda frente a 35 escrituras automáticas', () async {
      final dataDir = '${tempDir.path}/data';
      final backupDir = '${tempDir.path}/backups';
      final releasesDir = '${tempDir.path}/releases';

      final dbService = DatabaseService(
        dataDir: dataDir,
        backupDir: backupDir,
        releasesDir: releasesDir,
        maxAutoSnapshots: 30,
      );
      await dbService.init();

      final backupDirectory = Directory(backupDir);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      // Pre-sembrar respaldos protegidos
      final manualFile = File('$backupDir/manual_snapshot_2026.json');
      await manualFile.writeAsString('{"type": "manual_snapshot", "date": "2026-11-20"}');

      final vaultFile = File('$backupDir/vault_pre_import_2026.json');
      await vaultFile.writeAsString('{"type": "vault_pre_import", "date": "2026-11-20"}');

      final preRestoreFile = File('$backupDir/sandbox_clients_pre_restore_2026.json');
      await preRestoreFile.writeAsString('{"type": "pre_restore", "date": "2026-11-20"}');

      // Ejecutar 35 escrituras automáticas consecutivas
      for (int i = 0; i < 35; i++) {
        await dbService.saveClients(
          [
            {
              'id': 'CLI-002',
              'business_name': 'Comercial $i',
            }
          ],
          reason: 'auto_step_$i',
        );
        await Future.delayed(const Duration(milliseconds: 2));
      }

      // Verificar que los respaldos manuales y de bóveda JAMÁS fueron eliminados
      expect(manualFile.existsSync(), isTrue, reason: 'El archivo manual_snapshot_2026.json jamás debe ser eliminado');
      expect(vaultFile.existsSync(), isTrue, reason: 'El archivo vault_pre_import_2026.json jamás debe ser eliminado');
      expect(preRestoreFile.existsSync(), isTrue, reason: 'El archivo pre_restore jamás debe ser eliminado');

      final files = backupDirectory.listSync().whereType<File>().toList();
      final autoSnapshots = files.where((f) {
        final name = f.uri.pathSegments.last;
        final lower = name.toLowerCase();
        final isDbSnapshot = name.startsWith('sandbox_') || name.startsWith('prod_');
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('pre_import');
        return isDbSnapshot && !isProtected && name.endsWith('.json');
      }).toList();

      expect(autoSnapshots.length, equals(30), reason: 'Los automáticos se purgan a exactamente 30');
    });

    test('3. ConfigService: 35 guardados consecutivos retienen exactamente 30 owner_config_backup_*.json', () async {
      final dataDir = Directory('${tempDir.path}/data');
      final backupsDir = Directory('${tempDir.path}/backups');

      final configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
        maxAutoSnapshots: 30,
      );
      await configService.init();

      // Sembrar un backup de configuración manual que debe ser preservado
      final manualCfgFile = File('${backupsDir.path}/owner_config_backup_manual_custom.json');
      await manualCfgFile.writeAsString('{"type": "manual_config"}');

      // Ejecutar 35 guardados consecutivos
      for (int i = 0; i < 35; i++) {
        await configService.saveConfig({
          'system': {'test_run': i},
        });
        await Future.delayed(const Duration(milliseconds: 2));
      }

      final files = backupsDir.listSync().whereType<File>().toList();

      final autoConfigSnapshots = files.where((f) {
        final name = f.uri.pathSegments.last;
        final lower = name.toLowerCase();
        final isAutoConfig = name.startsWith('owner_config_backup_');
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('pre_import');
        return isAutoConfig && !isProtected && name.endsWith('.json');
      }).toList();

      expect(
        autoConfigSnapshots.length,
        equals(30),
        reason: 'Deben permanecer exactamente 30 respaldos automáticos de configuración',
      );

      // El archivo manual debe seguir intacto
      expect(manualCfgFile.existsSync(), isTrue, reason: 'El backup manual de config jamás se elimina');
    });

    test('4. Validación sintáctica y estructural de Iniciar_MochilaLista_Admin.bat', () {
      final candidate1 = File('../Iniciar_MochilaLista_Admin.bat');
      final candidate2 = File('Iniciar_MochilaLista_Admin.bat');
      final candidate3 = File(r'C:\Users\vjuli\Documents\mochilalista-app\Iniciar_MochilaLista_Admin.bat');

      final batFile = candidate1.existsSync()
          ? candidate1
          : (candidate2.existsSync() ? candidate2 : candidate3);

      expect(batFile.existsSync(), isTrue, reason: 'Iniciar_MochilaLista_Admin.bat debe existir');

      final content = batFile.readAsStringSync();

      expect(
        content.contains(r'%~dp0mochilalista_admin'),
        isTrue,
        reason: 'Debe contener posicionamiento absoluto relativo %~dp0mochilalista_admin',
      );

      expect(
        content.contains(r'findstr ":8080 "'),
        isTrue,
        reason: 'Debe verificar con precisión el puerto :8080 con espacio para evitar falsos positivos',
      );

      expect(
        content.contains(r'findstr "LISTENING"'),
        isTrue,
        reason: 'Debe verificar el estado LISTENING del socket',
      );

      expect(
        content.contains(r'http://localhost:8080'),
        isTrue,
        reason: 'Debe abrir automáticamente la URL http://localhost:8080 en el navegador',
      );
    });
  });
}
