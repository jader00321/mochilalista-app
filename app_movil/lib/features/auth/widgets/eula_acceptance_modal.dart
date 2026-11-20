import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/license_provider.dart';

/// Modal interactivo de Contrato de Licencia de Usuario Final (EULA)
/// con mecanismo de scroll obligatorio antes de permitir la aceptación,
/// diálogo de barrera ante cancelación y blindaje bajo el marco legal peruano.
class EulaAcceptanceModal extends StatefulWidget {
  final bool isReadOnly;
  final VoidCallback? onExitApp;

  const EulaAcceptanceModal({
    super.key,
    this.isReadOnly = false,
    this.onExitApp,
  });

  /// Abre el modal de forma estática
  static Future<bool?> show(
    BuildContext context, {
    bool isReadOnly = false,
    VoidCallback? onExitApp,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: isReadOnly,
      builder: (_) => EulaAcceptanceModal(
        isReadOnly: isReadOnly,
        onExitApp: onExitApp,
      ),
    );
  }

  @override
  State<EulaAcceptanceModal> createState() => _EulaAcceptanceModalState();
}

class _EulaAcceptanceModalState extends State<EulaAcceptanceModal> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _hasAcceptedCheckbox = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isReadOnly) {
      _hasScrolledToBottom = true;
      _hasAcceptedCheckbox = true;
    } else {
      _scrollController.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isReadOnly) {
          setState(() {
            _hasScrolledToBottom = true;
            _hasAcceptedCheckbox = true;
          });
          return;
        }
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (maxScroll <= 0) {
            setState(() => _hasScrolledToBottom = true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll <= 0 || currentScroll >= maxScroll - 16.0) {
      if (!_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  Future<void> _handleAccept() async {
    if (!_hasScrolledToBottom || !_hasAcceptedCheckbox || _isSaving) return;

    setState(() => _isSaving = true);
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv != null) {
      await licenseProv.recordEulaAcceptance("1.0");
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleCancel() async {
    if (widget.isReadOnly) {
      Navigator.of(context).pop(false);
      return;
    }

    // Diálogo de barrera legal en modo obligatorio
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (barrierCtx) {
        final isDark = Theme.of(barrierCtx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber[800], size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Aceptación Obligatoria",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            "Para operar MochilaLista POS y garantizar la protección legal de su información comercial conforme al D.L. 822 y la Ley N° 29733, es indispensable aceptar los Términos de Licencia (EULA).\n\nSi no está de acuerdo con los términos, debe salir de la aplicación.",
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(barrierCtx).pop(false),
              child: const Text("Revisar Contrato"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(barrierCtx).pop(true),
              child: const Text("Salir de la App"),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      if (widget.onExitApp != null) {
        widget.onExitApp!();
      } else {
        SystemNavigator.pop();
      }
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera Legal Completa sin Truncar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            OwnerLegalIdentity.legalEulaTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            OwnerLegalIdentity.legalSubtitleCommercial,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[600],
                            ),
                          ),
                          Text(
                            OwnerLegalIdentity.legalAuthorTitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isReadOnly)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Guía Visual Dinámica de Lectura
                if (!widget.isReadOnly && !_hasScrolledToBottom)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Desliza hasta el final del contrato para habilitar la aceptación",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contenedor con Scroll de las 7 Cláusulas Oficiales Reforzadas
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : const Color(0xFFF9FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 14.0, right: 22.0, top: 12.0, bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContractHeader(isDark),
                            const Divider(height: 18),
                            _buildClause(
                              "CLÁUSULA PRIMERA: PROPIEDAD INTELECTUAL Y TITULARIDAD EXCLUSIVA",
                              "MochilaLista POS Comercial, incluyendo su código fuente compilado, arquitectura de base de datos SQLite, algoritmos de cotización inteligente e interfaces visuales, es una obra protegida por el Decreto Legislativo 822 (Ley sobre el Derecho de Autor del Perú) e INDECOPI. Julio Angello Vasquez Navarro retiene el 100% de los derechos morales y patrimoniales. Este contrato constituye una licencia limitada de uso, jamás una cesión ni venta de software o código fuente.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA SEGUNDA: ALCANCE MULTINEGOCIO POR LICENCIA DE HARDWARE",
                              "La licencia se vincula al identificador de hardware único (Hardware ID / DeviceFingerprint) del dispositivo móvil Android. El Licenciatario cuenta con la facultad legal de administrar múltiples perfiles comerciales o sucursales dentro del mismo dispositivo físico, rigiéndose todos bajo la misma licencia y compartiendo la cuota mensual de escaneos IA asignada al equipo.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA TERCERA: PROHIBICIÓN EXPRESA DE FRAUDE E INGENIERÍA INVERSA",
                              "Queda terminantemente prohibido descompilar, realizar ingeniería inversa, modificar el bytecode Dex/Smali, reempaquetar el APK, alterar firmas criptográficas Ed25519, burlar el reloj del sistema, falsificar el ANDROID_ID, clonar la base de datos a otros dispositivos o redistribuir comercialmente el software sin autorización previa y por escrito del autor, bajo apercibimiento de las acciones civiles y penales tipificadas en los Artículos 216 y siguientes del Código Penal Peruano.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA CUARTA: DESLINDE DE RESPONSABILIDAD BYOK (CLAVES DE TERCEROS)",
                              "MochilaLista permite la integración voluntaria de claves de API de Google AI Studio / Gemini propiedad del usuario (BYOK). El Licenciatario asume la total responsabilidad civil, contractual y técnica por los costos, cuotas y uso de su cuenta ante Google LLC. El Licenciante no almacena, no transmite ni responde por suspensiones o cobros derivados del proveedor externo.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA QUINTA: PRIVACIDAD DE DATOS (LEY N° 29733) Y RESPONSABILIDAD DE RESPALDOS",
                              "En estricto cumplimiento de la Ley N° 29733 (Ley de Protección de Datos Personales) y bajo una arquitectura Offline-First, toda la información de catálogo, costos, inventario, clientes y ventas reside exclusivamente en la memoria local del dispositivo móvil. El Licenciante no recopila datos comerciales ni mantiene servidores centrales de almacenamiento. Es responsabilidad exclusiva del usuario generar periódicamente sus respaldos cifrados (.mlbg). El Licenciante no asume responsabilidad patrimonial por pérdidas de información debidas a daño, formateo, robo o extravío del teléfono.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA SEXTA: POLÍTICA DE ACTUALIZACIONES Y VIGENCIA",
                              "1. Periodo de Prueba (Trial): 30 días calendario con 50 escaneos IA incluidos por dispositivo.\n2. Suscripciones Periódicas (Mensual, Trimestral, Semestral, Anual): Acceso durante el término contratado. Vencido el plazo, la app pasa a modo lectura de datos y exportación de respaldos sin pérdida de información.\n3. Licencia Perpetua: Acceso de por vida en el dispositivo registrado, incluyendo 12 meses de actualizaciones con nuevas funciones y parches correctivos de estabilidad gratuitos de por vida.",
                              isDark,
                            ),
                            _buildClause(
                              "CLÁUSULA SÉPTIMA: JURISDICCIÓN Y SOLUCIÓN DE CONTROVERSIAS",
                              "Cualquier controversia derivada de la interpretación o ejecución de este contrato se someterá expresamente a la competencia administrativa de la Dirección de Derecho de Autor del INDECOPI y/o a los Juzgados y Tribunales del Distrito Judicial de Lima, República del Perú, renunciando a cualquier otro fuero.",
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                OwnerLegalIdentity.watermarkNotice,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Checkbox de consentimiento explícito tras scroll
                if (!widget.isReadOnly) ...[
                  InkWell(
                    onTap: _hasScrolledToBottom
                        ? () => setState(() => _hasAcceptedCheckbox = !_hasAcceptedCheckbox)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _hasAcceptedCheckbox,
                            onChanged: _hasScrolledToBottom
                                ? (v) => setState(() => _hasAcceptedCheckbox = v ?? false)
                                : null,
                            activeColor: Colors.blue[700],
                          ),
                          Expanded(
                            child: Text(
                              "He leído y acepto íntegramente los Términos de Licencia y Propiedad Intelectual.",
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasScrolledToBottom
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Botonera Inferior Responsiva y Equilibrada
                _buildActionButtons(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    if (widget.isReadOnly) {
      return ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          "Cerrar",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        final acceptBtn = ElevatedButton(
          onPressed: (_hasScrolledToBottom && _hasAcceptedCheckbox && !_isSaving)
              ? _handleAccept
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.3),
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  "Aceptar Términos de Licencia",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
        );

        final cancelBtn = TextButton(
          onPressed: _handleCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 44),
            alignment: Alignment.center,
          ),
          child: Text(
            "Cancelar",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              fontSize: 12,
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              acceptBtn,
              const SizedBox(height: 6),
              cancelBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 1,
              child: cancelBtn,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: acceptBtn,
            ),
          ],
        );
      },
    );
  }

  Widget _buildContractHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CONTRATO DE LICENCIA DE USUARIO FINAL (EULA)",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "AUTOR Y TITULAR: ${OwnerLegalIdentity.authorFullName.toUpperCase()}",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.blue[400],
          ),
        ),
        Text(
          OwnerLegalIdentity.legalFrameworkNotice,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildClause(String title, String body, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.lightBlue[200] : Colors.blue[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
