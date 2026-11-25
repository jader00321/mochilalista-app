import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/config/owner_commercial_defaults.dart';
import 'package:app_movil/core/services/license/commercial_config_sync_service.dart';

/// Especificación declarativa tipada de un producto comercial o tarifa técnica.
class CommercialSyncProductSpec {
  final String id;
  final double price;
  final int days;
  final int aiCredits;
  final int updatesMonths;
  final String label;
  final String description;

  const CommercialSyncProductSpec({
    required this.id,
    required this.price,
    required this.days,
    required this.aiCredits,
    required this.updatesMonths,
    required this.label,
    required this.description,
  });

  String get formattedPrice => 'S/ ${price.toStringAsFixed(2)}';
}

/// Vista efectiva inmutable de tarifas, soporte y medios de pago combinando los valores
/// compilados de fábrica con la ficha declarativa `MLC1-...` si existe en `SharedPreferences`.
class EffectiveCommercialConfig {
  final bool hasSyncedOverride;
  final int revision;
  final int? issuedAtUnix;
  final String? issuedAtLimaLabel;
  final String? appliedAtLimaLabel;
  final String supportPhone;
  final String supportWhatsAppUrl;
  final String yapeHolder;
  final String yapePhone;
  final String bcpHolder;
  final String bcpAccount;
  final String bcpCci;
  final String bbvaHolder;
  final String bbvaAccount;
  final String bbvaCci;
  final Map<String, CommercialSyncProductSpec> plansById;

  const EffectiveCommercialConfig({
    required this.hasSyncedOverride,
    required this.revision,
    required this.issuedAtUnix,
    required this.issuedAtLimaLabel,
    required this.appliedAtLimaLabel,
    required this.supportPhone,
    required this.supportWhatsAppUrl,
    required this.yapeHolder,
    required this.yapePhone,
    required this.bcpHolder,
    required this.bcpAccount,
    required this.bcpCci,
    required this.bbvaHolder,
    required this.bbvaAccount,
    required this.bbvaCci,
    required this.plansById,
  });

  static CommercialSyncProductSpec _buildSpecFromDefaults(String id) {
    final m = OwnerCommercialDefaults.defaultCommercialPlans[id]!;
    return CommercialSyncProductSpec(
      id: id,
      price: (m['pr'] as num).toDouble(),
      days: (m['d'] as num).toInt(),
      aiCredits: (m['ai'] as num).toInt(),
      updatesMonths: (m['um'] as num).toInt(),
      label: m['lb'] as String,
      description: m['ds'] as String,
    );
  }

  static final Map<String, CommercialSyncProductSpec> defaultPlansMap =
      Map<String, CommercialSyncProductSpec>.unmodifiable({
    for (final id in OwnerCommercialDefaults.defaultCommercialPlans.keys)
      id: _buildSpecFromDefaults(id),
  });

  static String deriveWhatsAppUrl(String phone) {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length >= 8) {
      return 'https://wa.me/$cleanDigits';
    }
    return OwnerCommercialDefaults.supportWhatsAppUrl;
  }

  /// Retorna la configuración compilada de fábrica sin overrides externos.
  factory EffectiveCommercialConfig.defaults() {
    // Mantiene compatibilidad estricta con el formato visual previo cuando yapePlinPhone conserva el valor base.
    final defaultYapePhone =
        OwnerCommercialDefaults.yapePlinPhone == '922836879'
            ? OwnerCommercialDefaults.supportPhone
            : OwnerCommercialDefaults.yapePlinPhone;
    return EffectiveCommercialConfig(
      hasSyncedOverride: false,
      revision: OwnerCommercialDefaults.commercialSyncDefaultRevision,
      issuedAtUnix: null,
      issuedAtLimaLabel: null,
      appliedAtLimaLabel: null,
      supportPhone: OwnerCommercialDefaults.supportPhone,
      supportWhatsAppUrl: OwnerCommercialDefaults.supportWhatsAppUrl,
      yapeHolder: OwnerCommercialDefaults.yapePlinHolder,
      yapePhone: defaultYapePhone,
      bcpHolder: OwnerCommercialDefaults.bcpAccountHolder,
      bcpAccount: OwnerCommercialDefaults.bcpAccountNumber,
      bcpCci: OwnerCommercialDefaults.bcpCciNumber,
      bbvaHolder: OwnerCommercialDefaults.bbvaAccountHolder,
      bbvaAccount: OwnerCommercialDefaults.bbvaAccountNumber,
      bbvaCci: OwnerCommercialDefaults.bbvaCciNumber,
      plansById: defaultPlansMap,
    );
  }

  /// Construye la configuración efectiva a partir de un snapshot `MLC1` verificado y guardado.
  factory EffectiveCommercialConfig.fromSaved(CommercialSavedConfig saved) {
    return EffectiveCommercialConfig.fromPayload(
      saved.payload,
      hasSyncedOverride: true,
      issuedAtLimaLabel: saved.issuedAtLima,
      appliedAtLimaLabel: saved.appliedAtLima,
    );
  }

  /// Construye una configuración tipada a partir de cualquier payload `MLC1` válido.
  factory EffectiveCommercialConfig.fromPayload(
    Map<String, dynamic> payload, {
    bool hasSyncedOverride = false,
    String? issuedAtLimaLabel,
    String? appliedAtLimaLabel,
  }) {
    final supRaw = (payload['sup']?.toString() ?? '').trim();
    final supportPhone = supRaw.isNotEmpty
        ? supRaw
        : OwnerCommercialDefaults.supportPhone;

    final yhRaw = (payload['yh']?.toString() ?? '').trim();
    final yapeHolder = yhRaw.isNotEmpty
        ? yhRaw
        : OwnerCommercialDefaults.yapePlinHolder;

    final ypRaw = (payload['yp']?.toString() ?? '').trim();
    final yapePhone = ypRaw.isNotEmpty ? ypRaw : supportPhone;

    final bcp = payload['bcp'] is Map ? payload['bcp'] as Map : const {};
    final bbva = payload['bbva'] is Map ? payload['bbva'] as Map : const {};
    final rawProducts = payload['p'] is Map ? payload['p'] as Map : const {};

    final mergedPlans = <String, CommercialSyncProductSpec>{};
    for (final entry in defaultPlansMap.entries) {
      final id = entry.key;
      final def = entry.value;
      final raw = rawProducts[id];
      if (raw is Map) {
        final rawLb = (raw['lb']?.toString() ?? '').trim();
        final rawDs = (raw['ds']?.toString() ?? '').trim();
        mergedPlans[id] = CommercialSyncProductSpec(
          id: id,
          price: (raw['pr'] as num?)?.toDouble() ?? def.price,
          days: (raw['d'] as num?)?.toInt() ?? def.days,
          aiCredits: (raw['ai'] as num?)?.toInt() ?? def.aiCredits,
          updatesMonths: (raw['um'] as num?)?.toInt() ?? def.updatesMonths,
          label: rawLb.isNotEmpty ? rawLb : def.label,
          description: rawDs.isNotEmpty ? rawDs : def.description,
        );
      } else {
        mergedPlans[id] = def;
      }
    }

    final iatUnix = (payload['iat'] as num?)?.toInt();
    final rev = (payload['ver'] as num?)?.toInt() ?? 0;

    return EffectiveCommercialConfig(
      hasSyncedOverride: hasSyncedOverride,
      revision: rev,
      issuedAtUnix: iatUnix,
      issuedAtLimaLabel:
          issuedAtLimaLabel ??
          (iatUnix != null
              ? CommercialConfigSyncService.formatLimaDateTime(iatUnix)
              : null),
      appliedAtLimaLabel: appliedAtLimaLabel,
      supportPhone: supportPhone,
      supportWhatsAppUrl: deriveWhatsAppUrl(supportPhone),
      yapeHolder: yapeHolder,
      yapePhone: yapePhone,
      bcpHolder: (bcp['h']?.toString() ?? '').trim(),
      bcpAccount: (bcp['acc']?.toString() ?? '').trim(),
      bcpCci: (bcp['cci']?.toString() ?? '').trim(),
      bbvaHolder: (bbva['h']?.toString() ?? '').trim(),
      bbvaAccount: (bbva['acc']?.toString() ?? '').trim(),
      bbvaCci: (bbva['cci']?.toString() ?? '').trim(),
      plansById: mergedPlans,
    );
  }

  bool get hasBcpConfigured => bcpAccount.trim().isNotEmpty;
  bool get hasBbvaConfigured => bbvaAccount.trim().isNotEmpty;

  CommercialSyncProductSpec get mensual => plansById['mensual']!;
  CommercialSyncProductSpec get trimestral => plansById['trimestral']!;
  CommercialSyncProductSpec get semestral => plansById['semestral']!;
  CommercialSyncProductSpec get anual => plansById['anual']!;
  CommercialSyncProductSpec get perpetua => plansById['perpetua']!;
  CommercialSyncProductSpec get bolsaExtraIa => plansById['bolsa_extra_ia']!;
  CommercialSyncProductSpec get paseAnualUpdates =>
      plansById['pase_anual_updates']!;
  CommercialSyncProductSpec get migracion => plansById['migracion']!;

  CommercialSyncProductSpec productById(String id) =>
      plansById[id] ?? defaultPlansMap[id] ?? mensual;

  Uri buildCustomWhatsAppOrderUri(String customMessage) {
    final cleanDigits = supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final base = cleanDigits.length >= 8
        ? 'https://wa.me/$cleanDigits'
        : supportWhatsAppUrl;
    final encoded = Uri.encodeComponent(customMessage);
    return Uri.parse('$base?text=$encoded');
  }
}

/// Proveedor reactivo global del catálogo comercial, cuentas de pago y teléfono oficial.
///
/// Combina los valores compilados de fábrica con configuraciones declarativas `MLC1-...`
/// almacenadas únicamente en `SharedPreferences`.
class CommercialCatalogProvider extends ChangeNotifier {
  final CommercialConfigSyncService _syncService;
  EffectiveCommercialConfig _config = EffectiveCommercialConfig.defaults();
  bool _isInitialized = false;

  CommercialCatalogProvider({CommercialConfigSyncService? syncService})
    : _syncService = syncService ?? CommercialConfigSyncService();

  bool get isInitialized => _isInitialized;
  EffectiveCommercialConfig get effectiveConfig => _config;
  bool get hasSyncedOverride => _config.hasSyncedOverride;
  int get revision => _config.revision;
  String? get issuedAtLimaLabel => _config.issuedAtLimaLabel;
  String? get appliedAtLimaLabel => _config.appliedAtLimaLabel;

  String get supportPhone => _config.supportPhone;
  String get supportWhatsAppUrl => _config.supportWhatsAppUrl;
  String get yapeHolder => _config.yapeHolder;
  String get yapePhone => _config.yapePhone;
  String get bcpHolder => _config.bcpHolder;
  String get bcpAccount => _config.bcpAccount;
  String get bcpCci => _config.bcpCci;
  String get bbvaHolder => _config.bbvaHolder;
  String get bbvaAccount => _config.bbvaAccount;
  String get bbvaCci => _config.bbvaCci;
  bool get hasBcpConfigured => _config.hasBcpConfigured;
  bool get hasBbvaConfigured => _config.hasBbvaConfigured;

  CommercialSyncProductSpec get mensual => _config.mensual;
  CommercialSyncProductSpec get trimestral => _config.trimestral;
  CommercialSyncProductSpec get semestral => _config.semestral;
  CommercialSyncProductSpec get anual => _config.anual;
  CommercialSyncProductSpec get perpetua => _config.perpetua;
  CommercialSyncProductSpec get bolsaExtraIa => _config.bolsaExtraIa;
  CommercialSyncProductSpec get paseAnualUpdates => _config.paseAnualUpdates;
  CommercialSyncProductSpec get migracion => _config.migracion;

  CommercialSyncProductSpec productById(String id) => _config.productById(id);

  /// Carga en frío la ficha `MLC1` persistida en `SharedPreferences` (si existe).
  Future<void> loadFromStorage({SharedPreferences? prefs}) async {
    final saved = await _syncService.getSavedConfig(prefs: prefs);
    _config = saved != null
        ? EffectiveCommercialConfig.fromSaved(saved)
        : EffectiveCommercialConfig.defaults();
    _isInitialized = true;
    notifyListeners();
  }

  /// Verifica un token `MLC1-...` (firma Ed25519 + esquema + anti-downgrade) sin aplicarlo todavía.
  Future<CommercialConfigVerificationResult> previewToken(
    String rawInput, {
    List<int>? publicKeyBytes,
    SharedPreferences? prefs,
  }) {
    return _syncService.parseAndVerifyToken(
      rawInput,
      checkDowngrade: true,
      publicKeyBytes: publicKeyBytes,
      prefs: prefs,
    );
  }

  /// Verifica y aplica en caliente una ficha `MLC1-...`, persistiendo en `SharedPreferences`
  /// y notificando a todas las pantallas suscritas.
  Future<CommercialConfigVerificationResult> applyToken(
    String rawInput, {
    List<int>? publicKeyBytes,
    SharedPreferences? prefs,
    DateTime? nowUtc,
  }) async {
    final res = await _syncService.applyVerifiedToken(
      rawInput,
      publicKeyBytes: publicKeyBytes,
      prefs: prefs,
      nowUtc: nowUtc,
    );
    if (res.isValid) {
      await loadFromStorage(prefs: prefs);
    }
    return res;
  }

  /// Elimina la ficha personalizada y restaura instantáneamente los valores compilados en el APK.
  Future<void> resetToCompiledDefaults({SharedPreferences? prefs}) async {
    await _syncService.resetToCompiledDefaults(prefs: prefs);
    _config = EffectiveCommercialConfig.defaults();
    _isInitialized = true;
    notifyListeners();
  }
}
