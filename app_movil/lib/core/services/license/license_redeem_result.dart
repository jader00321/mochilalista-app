import 'package:app_movil/core/models/license_model.dart';

/// Clasificación tipada del estado de un canje de licencia criptográfica
enum LicenseRedeemStatus {
  /// Canje exitoso: se acreditó un nuevo plan, días adicionales o créditos de IA
  success,

  /// El código ingresado ya fue aplicado anteriormente en este mismo dispositivo (mismo nonce)
  alreadyRedeemedSameNonce,

  /// El código corresponde a una emisión previa que ya fue superada por un código posterior
  supersededOlderNonce,

  /// El código fue generado para otro celular (discrepancia de Hardware ID)
  hardwareMismatch,

  /// El código ya cumplió su período de vigencia contratado
  expiredToken,

  /// La firma matemática Ed25519 no coincide o el token fue manipulado
  invalidSignatureOrTampered,

  /// El formato es inválido (no contiene payload y firma, o base64/json corrupto)
  invalidFormat,
}

/// Excepción estructurada de validación que preserva 100% de compatibilidad con `Exception`
class LicenseValidationException implements Exception {
  final LicenseRedeemStatus status;
  final String message;
  final int? tokenNonce;
  final int? currentNonce;
  final String? tokenDeviceId;
  final String? currentDeviceId;

  const LicenseValidationException({
    required this.status,
    required this.message,
    this.tokenNonce,
    this.currentNonce,
    this.tokenDeviceId,
    this.currentDeviceId,
  });

  @override
  String toString() => message;
}

/// Resultado integral y rico en detalles tras un intento de canje de licencia
class LicenseRedeemResult {
  final LicenseRedeemStatus status;
  final bool isSuccess;
  final String message;
  final int? tokenNonce;
  final int? currentNonce;
  final String? tokenDeviceId;
  final String? currentDeviceId;
  final String? plan;
  final int daysAdded;
  final int aiCreditsAdded;
  final DateTime? newExpirationDate;
  final LicenseModel? currentLicenseSnapshot;

  const LicenseRedeemResult({
    required this.status,
    required this.isSuccess,
    required this.message,
    this.tokenNonce,
    this.currentNonce,
    this.tokenDeviceId,
    this.currentDeviceId,
    this.plan,
    this.daysAdded = 0,
    this.aiCreditsAdded = 0,
    this.newExpirationDate,
    this.currentLicenseSnapshot,
  });

  /// Factory para resultado exitoso
  factory LicenseRedeemResult.success({
    required String message,
    required String plan,
    int daysAdded = 0,
    int aiCreditsAdded = 0,
    DateTime? newExpirationDate,
    int? tokenNonce,
    String? tokenDeviceId,
    LicenseModel? currentLicenseSnapshot,
  }) {
    return LicenseRedeemResult(
      status: LicenseRedeemStatus.success,
      isSuccess: true,
      message: message,
      plan: plan,
      daysAdded: daysAdded,
      aiCreditsAdded: aiCreditsAdded,
      newExpirationDate: newExpirationDate,
      tokenNonce: tokenNonce,
      tokenDeviceId: tokenDeviceId,
      currentLicenseSnapshot: currentLicenseSnapshot,
    );
  }

  /// Factory a partir de una excepción tipada
  factory LicenseRedeemResult.fromException(
    LicenseValidationException exception, {
    LicenseModel? currentLicenseSnapshot,
  }) {
    return LicenseRedeemResult(
      status: exception.status,
      isSuccess: false,
      message: exception.message,
      tokenNonce: exception.tokenNonce,
      currentNonce: exception.currentNonce,
      tokenDeviceId: exception.tokenDeviceId,
      currentDeviceId: exception.currentDeviceId,
      currentLicenseSnapshot: currentLicenseSnapshot,
    );
  }

  /// Factory para error genérico o formato inválido
  factory LicenseRedeemResult.failure({
    required LicenseRedeemStatus status,
    required String message,
    int? tokenNonce,
    int? currentNonce,
    String? tokenDeviceId,
    String? currentDeviceId,
    LicenseModel? currentLicenseSnapshot,
  }) {
    return LicenseRedeemResult(
      status: status,
      isSuccess: false,
      message: message,
      tokenNonce: tokenNonce,
      currentNonce: currentNonce,
      tokenDeviceId: tokenDeviceId,
      currentDeviceId: currentDeviceId,
      currentLicenseSnapshot: currentLicenseSnapshot,
    );
  }
}
