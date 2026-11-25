import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/config/owner_commercial_defaults.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/commercial_catalog_provider.dart';
import 'package:app_movil/core/services/license/commercial_config_sync_service.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';

const String _expectedOfficialPublicSha256 =
    '1c3ec0b9d87ff8acb49b1df871b65c0b40e47d1f11c65b348b5407b80a65e106';

dynamic _canonicalizeValue(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((e) => e.toString()).toList()..sort();
    final out = <String, dynamic>{};
    for (final k in sortedKeys) {
      out[k] = _canonicalizeValue(value[k]);
    }
    return out;
  }
  if (value is List) {
    return value.map(_canonicalizeValue).toList();
  }
  return value;
}

Future<String> _signAdminCanonicalPayload(
  Map<String, dynamic> payload,
  SimpleKeyPair keyPair, {
  bool omitDomainPrefix = false,
}) async {
  final payloadJson = jsonEncode(_canonicalizeValue(payload));
  final payloadB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(
    utf8.encode(payloadJson),
  );
  final signedBytes = utf8.encode(
    omitDomainPrefix ? payloadB64 : 'MLC1-$payloadB64',
  );
  final sig = await Ed25519().sign(signedBytes, keyPair: keyPair);
  final sigB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(sig.bytes);
  return 'MLC1-$payloadB64.$sigB64';
}

Map<String, dynamic> _buildAdminVectorPayload({
  required int revision,
  required int iatUnix,
}) {
  final products = <String, dynamic>{};
  for (final entry in EffectiveCommercialConfig.defaultPlansMap.entries) {
    final spec = entry.value;
    products[entry.key] = <String, dynamic>{
      'ai': entry.key == 'mensual' ? 60 : spec.aiCredits,
      'd': spec.days,
      'ds': spec.description,
      'lb': spec.label,
      'pr': entry.key == 'mensual' ? 39.0 : spec.price,
      'um': (entry.key == 'perpetua' || entry.key == 'pase_anual_updates')
          ? 12
          : spec.updatesMonths,
    };
  }

  return _canonicalizeValue(<String, dynamic>{
        'bbva': <String, String>{
          'acc': '0011-0123-0200456789',
          'cci': '011-123-000200456789-34',
          'h': 'Julio Angello Vasquez',
        },
        'bcp': <String, String>{
          'acc': '191-55566677-0-99',
          'cci': '002-191-005556667709-99',
          'h': 'Julio Angello Vasquez',
        },
        'iat': iatUnix,
        'p': products,
        'sup': '+51 999 777 666',
        'v': 1,
        'ver': revision,
        'yh': 'Julio Angello Vasquez Navarro',
        'yp': '999777666',
      })
      as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
      'PLAN MAESTRO 24 - FASE 5: Verificación Cruzada Real Admin <-> Móvil y OwnerCommercialDefaults',
      () {
    late SimpleKeyPair sharedTestKeyPair;
    late List<int> sharedTestPubBytes;

    setUpAll(() async {
      // Misma semilla sintética fija usada en mochilalista_admin/test/plan24_fase5_cross_parity_test.dart
      final seed = List<int>.generate(32, (i) => (i * 7 + 13) & 0xFF);
      sharedTestKeyPair = await Ed25519().newKeyPairFromSeed(seed);
      final pub = await sharedTestKeyPair.extractPublicKey();
      sharedTestPubBytes = pub.bytes;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Ed25519LicenseValidator.setTestPublicKey(null);
    });

    tearDown(() {
      Ed25519LicenseValidator.setTestPublicKey(null);
    });

    test(
        '1. Huella SHA-256 pública oficial embebida en Ed25519LicenseValidator coincide al 100 %',
        () {
      Ed25519LicenseValidator.setTestPublicKey(null);
      final activeBytes = Ed25519LicenseValidator.activePublicKeyBytes;
      expect(activeBytes.length, equals(32));
      final actualSha = sha256.convert(activeBytes).toString().toLowerCase();
      expect(actualSha, equals(_expectedOfficialPublicSha256));
    });

    test(
        '2. Integridad 1:1 OwnerCommercialDefaults <-> OwnerLegalIdentity <-> EffectiveCommercialConfig.defaults()',
        () {
      expect(
        OwnerLegalIdentity.commercialSyncDefaultRevision,
        equals(OwnerCommercialDefaults.commercialSyncDefaultRevision),
      );
      expect(
        OwnerLegalIdentity.authorFullName,
        equals(OwnerCommercialDefaults.authorFullName),
      );
      expect(
        OwnerLegalIdentity.appCommercialName,
        equals(OwnerCommercialDefaults.appCommercialName),
      );
      expect(
        OwnerLegalIdentity.legalFrameworkNotice,
        equals(OwnerCommercialDefaults.legalFrameworkNotice),
      );
      expect(
        OwnerLegalIdentity.personalDataLawNotice,
        equals(OwnerCommercialDefaults.personalDataLawNotice),
      );
      expect(
        OwnerLegalIdentity.supportPhone,
        equals(OwnerCommercialDefaults.supportPhone),
      );
      expect(
        OwnerLegalIdentity.supportWhatsAppUrl,
        equals(OwnerCommercialDefaults.supportWhatsAppUrl),
      );
      expect(
        OwnerLegalIdentity.officialWebsite,
        equals(OwnerCommercialDefaults.officialWebsite),
      );
      expect(
        OwnerLegalIdentity.yapePlinHolder,
        equals(OwnerCommercialDefaults.yapePlinHolder),
      );
      expect(
        OwnerLegalIdentity.yapePlinPhone,
        equals(OwnerCommercialDefaults.yapePlinPhone),
      );
      expect(
        OwnerLegalIdentity.bcpAccountHolder,
        equals(OwnerCommercialDefaults.bcpAccountHolder),
      );
      expect(
        OwnerLegalIdentity.bcpAccountNumber,
        equals(OwnerCommercialDefaults.bcpAccountNumber),
      );
      expect(
        OwnerLegalIdentity.bcpCciNumber,
        equals(OwnerCommercialDefaults.bcpCciNumber),
      );
      expect(
        OwnerLegalIdentity.bbvaAccountHolder,
        equals(OwnerCommercialDefaults.bbvaAccountHolder),
      );
      expect(
        OwnerLegalIdentity.bbvaAccountNumber,
        equals(OwnerCommercialDefaults.bbvaAccountNumber),
      );
      expect(
        OwnerLegalIdentity.bbvaCciNumber,
        equals(OwnerCommercialDefaults.bbvaCciNumber),
      );
      expect(
        OwnerLegalIdentity.defaultCommercialPlans,
        equals(OwnerCommercialDefaults.defaultCommercialPlans),
      );

      // Versiones compiladas intactas
      expect(OwnerLegalIdentity.currentAppVersion, equals('9.41.0'));
      expect(
        OwnerLegalIdentity.currentAppVersionWithBuild,
        equals('9.41.0+85'),
      );

      // EffectiveCommercialConfig.defaults() expone los 8 planes con um = 12 en perpetua y pase anual
      final defaults = EffectiveCommercialConfig.defaults();
      expect(defaults.hasSyncedOverride, isFalse);
      expect(defaults.plansById.length, equals(8));
      expect(defaults.perpetua.updatesMonths, equals(12));
      expect(defaults.paseAnualUpdates.updatesMonths, equals(12));
      expect(defaults.mensual.price, equals(35.0));
      expect(defaults.migracion.price, equals(40.0));
    });

    test(
        '3. Recepción cruzada real Admin -> Móvil MLC1 (BCP/BBVA, 8 productos, um=12), seguridad Ed25519, anti-downgrade y reset',
        () async {
      Ed25519LicenseValidator.setTestPublicKey(sharedTestPubBytes);

      final iatUnix =
          (DateTime.utc(2026, 11, 25, 18, 30, 0).millisecondsSinceEpoch / 1000)
              .floor();
      final payloadRev5 = _buildAdminVectorPayload(revision: 5, iatUnix: iatUnix);
      final tokenRev5 =
          await _signAdminCanonicalPayload(payloadRev5, sharedTestKeyPair);

      final provider = CommercialCatalogProvider();
      final applyRes = await provider.applyToken(
        tokenRev5,
        nowUtc: DateTime.utc(2026, 11, 25, 18, 35, 0),
      );
      expect(applyRes.isValid, isTrue);
      expect(applyRes.status, equals('VALID'));
      expect(applyRes.revision, equals(5));

      expect(provider.hasSyncedOverride, isTrue);
      expect(provider.revision, equals(5));
      expect(provider.supportPhone, equals('+51 999 777 666'));
      expect(provider.yapeHolder, equals('Julio Angello Vasquez Navarro'));
      expect(provider.yapePhone, equals('999777666'));
      expect(provider.hasBcpConfigured, isTrue);
      expect(provider.bcpAccount, equals('191-55566677-0-99'));
      expect(provider.bcpCci, equals('002-191-005556667709-99'));
      expect(provider.hasBbvaConfigured, isTrue);
      expect(provider.bbvaAccount, equals('0011-0123-0200456789'));
      expect(provider.bbvaCci, equals('011-123-000200456789-34'));
      expect(provider.mensual.price, equals(39.0));
      expect(provider.mensual.aiCredits, equals(60));
      expect(provider.perpetua.updatesMonths, equals(12));
      expect(provider.paseAnualUpdates.updatesMonths, equals(12));
      expect(provider.effectiveConfig.plansById.length, equals(8));

      // Persistencia verificada en SharedPreferences y recarga en frío
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(CommercialConfigSyncService.prefsKey), isTrue);

      final reloadedProvider = CommercialCatalogProvider();
      await reloadedProvider.loadFromStorage(prefs: prefs);
      expect(reloadedProvider.hasSyncedOverride, isTrue);
      expect(reloadedProvider.revision, equals(5));
      expect(reloadedProvider.bcpAccount, equals('191-55566677-0-99'));
      expect(reloadedProvider.mensual.price, equals(39.0));

      // Seguridad: rechaza 1 carácter alterado en el payload
      final parts = tokenRev5.substring('MLC1-'.length).split('.');
      final flipChar = parts[0][12] == 'A' ? 'B' : 'A';
      final tampered =
          'MLC1-${parts[0].substring(0, 12)}$flipChar${parts[0].substring(13)}.${parts[1]}';
      final tamperedRes = await provider.previewToken(tampered);
      expect(tamperedRes.isValid, isFalse);
      expect(tamperedRes.status, equals('INVALID_SIGNATURE'));

      // Seguridad: rechaza firma sin separación de dominio MLC1-
      final noDomainTok = await _signAdminCanonicalPayload(
        payloadRev5,
        sharedTestKeyPair,
        omitDomainPrefix: true,
      );
      final noDomainRes = await provider.previewToken(noDomainTok);
      expect(noDomainRes.isValid, isFalse);
      expect(noDomainRes.status, equals('INVALID_SIGNATURE'));

      // Anti-downgrade: rechaza ver: 4 estando activa ver: 5
      final payloadRev4 = _buildAdminVectorPayload(
        revision: 4,
        iatUnix: iatUnix + 60,
      );
      final tokenRev4 =
          await _signAdminCanonicalPayload(payloadRev4, sharedTestKeyPair);
      final downgradeRes = await provider.applyToken(tokenRev4);
      expect(downgradeRes.isValid, isFalse);
      expect(downgradeRes.status, equals('DOWNGRADE_REJECTED'));
      expect(provider.revision, equals(5));

      // Reset restaura exactamente los defaults de OwnerCommercialDefaults
      await provider.resetToCompiledDefaults(prefs: prefs);
      expect(provider.hasSyncedOverride, isFalse);
      expect(provider.revision, equals(0));
      expect(provider.mensual.price, equals(35.0));
      expect(provider.perpetua.updatesMonths, equals(12));
      expect(provider.paseAnualUpdates.updatesMonths, equals(12));
      expect(provider.supportPhone, equals(OwnerCommercialDefaults.supportPhone));
      expect(provider.hasBcpConfigured, isFalse);
      expect(provider.hasBbvaConfigured, isFalse);
      expect(prefs.containsKey(CommercialConfigSyncService.prefsKey), isFalse);
    });
  });
}
