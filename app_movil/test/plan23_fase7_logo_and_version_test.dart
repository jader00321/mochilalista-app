import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class _TestAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  List<UserModel> get localProfiles => const [];

  @override
  AuthStatus get status => AuthStatus.profileSelection;

  @override
  UserModel? get user => null;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => null;

  @override
  Future<void> checkInitialState() async {}

  @override
  Future<bool> profileHasPin(int profileId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  @override
  void updateContext(int? businessId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLicenseProvider extends ChangeNotifier implements LicenseProvider {
  final LicenseModel _license = LicenseModel(
    deviceFingerprint: 'TEST-P23-F7',
    tipoPlan: 'TRIAL',
    estadoActual: 'ACTIVA',
    fechaInicio: DateTime(2026, 11, 20),
    fechaExpiracion: DateTime(2026, 12, 20),
    fechaUltimoCheck: DateTime(2026, 11, 25),
    eulaAcceptedVersion: '1.0',
    eulaAcceptedTimestamp: DateTime(2026, 11, 20),
    lastExecutedAppVersion: OwnerLegalIdentity.currentAppVersionWithBuild,
  );

  @override
  LicenseModel? get license => _license;

  @override
  bool get isInitialized => true;

  @override
  String get deviceFingerprint => 'TEST-P23-F7';

  @override
  Future<void> checkLicense({DateTime? overrideNow}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestDriveService implements IGoogleDriveBackupService {
  @override
  Future<GoogleDriveUser?> getCurrentUser() async => null;

  @override
  Future<DriveBackupConfig> getConfig() async =>
      const DriveBackupConfig(isEnabled: false);

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rawEmojiRegex = RegExp(
    r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PLAN MAESTRO 23 - FASE 7: Logo Optimizado, Versión 9.41.0+85 y 0px Overflow', () {
    test('1. assets/logo.png es PNG RGBA 256x256 válido y pesa < 80 KB', () {
      final logoFile = File('assets/logo.png');
      expect(logoFile.existsSync(), isTrue);

      final bytes = logoFile.readAsBytesSync();
      expect(bytes.length, lessThan(80 * 1024));
      expect(
        bytes.sublist(0, 8),
        equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      );

      final decoded = img.decodePng(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(256));
      expect(decoded.height, equals(256));
      expect(decoded.numChannels, equals(4));
      expect(decoded.hasAlpha, isTrue);
    });

    test('2. Sincronización unificada a 9.41.0+85 sin emojis crudos en Changelog', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: 9.41.0+85'));
      expect(OwnerLegalIdentity.currentAppVersion, equals('9.41.0'));
      expect(
        OwnerLegalIdentity.currentAppVersionWithBuild,
        equals('9.41.0+85'),
      );
      expect(AppChangelogRegistry.currentVersion, equals('9.41.0+85'));

      final latest = AppChangelogRegistry.getLatestChangelog();
      expect(latest.length, greaterThanOrEqualTo(2));
      for (final item in latest) {
        expect(rawEmojiRegex.hasMatch(item.title), isFalse,
            reason: 'Emoji crudo en título de changelog: ${item.title}');
        expect(rawEmojiRegex.hasMatch(item.description), isFalse,
            reason: 'Emoji crudo en descripción de changelog');
      }

      final combinedText =
          latest.map((e) => '${e.title} ${e.description}'.toLowerCase()).join(' ');
      expect(combinedText, contains('tarifas'));
      expect(combinedText, contains('qr'));
      expect(combinedText, contains('arm64'));

      // El archivo histórico de 9.40.0+84 permanece intacto
      final archived940 =
          AppChangelogRegistry.getChangelogForVersion('9.40.0+84');
      expect(archived940.length, equals(3));
    });

    testWidgets(
        '3. OnboardingScreen y ProfileSelectionScreen consumen assets/logo.png con 0px Overflow en 320/360/412dp @ 1.3x',
        (tester) async {
      final viewports = <Size>[
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;

        final errors = <FlutterErrorDetails>[];
        final prevHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
        };

        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider(),
                ),
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _TestAuthProvider(),
                ),
                ChangeNotifierProvider<InventoryProvider>.value(
                  value: _TestInventoryProvider(),
                ),
                ChangeNotifierProvider<LicenseProvider>.value(
                  value: _TestLicenseProvider(),
                ),
              ],
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: const MaterialApp(
                  home: OnboardingScreen(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));

          final assetLogoFinder = find.byWidgetPredicate((w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'assets/logo.png');
          expect(assetLogoFinder, findsWidgets,
              reason: 'OnboardingScreen debe cargar assets/logo.png en $size');

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider(),
                ),
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _TestAuthProvider(),
                ),
                ChangeNotifierProvider<LicenseProvider?>.value(
                  value: _TestLicenseProvider(),
                ),
                ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
                  value: GoogleDriveBackupProvider(service: _TestDriveService()),
                ),
              ],
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: const MaterialApp(
                  home: Scaffold(body: ProfileSelectionScreen()),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));

          expect(assetLogoFinder, findsWidgets,
              reason:
                  'ProfileSelectionScreen debe cargar assets/logo.png en $size');

          final overflowErrors = errors
              .where((e) =>
                  e.exceptionAsString().toLowerCase().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'Se detectó overflow en $size @ 1.3x: ${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
          );
        } finally {
          FlutterError.onError = prevHandler;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    });
  });
}
