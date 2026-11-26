import 'package:intl/intl.dart';
import 'package:app_movil/core/providers/commercial_catalog_provider.dart';

/// Detalle estructurado de un plan comercial oficial para el modal flotante
class CommercialPlanDetail {
  final String id;
  final String name;
  final String price;
  final String desc;
  final String badge;
  final String aiBadge;
  final String duration;
  final String aiQuota;
  final String savings;
  final String idealFor;
  final List<String> benefits;
  final bool isPerpetual;
  final bool isExtraAi;
  final bool isUpdatePass;

  const CommercialPlanDetail({
    required this.id,
    required this.name,
    required this.price,
    required this.desc,
    required this.badge,
    required this.aiBadge,
    required this.duration,
    required this.aiQuota,
    required this.savings,
    required this.idealFor,
    required this.benefits,
    this.isPerpetual = false,
    this.isExtraAi = false,
    this.isUpdatePass = false,
  });
}

/// Combina los textos compilados de cada plan comercial con los precios, días, cuotas IA
/// y vigencias de updates vigentes desde [EffectiveCommercialConfig].
  List<CommercialPlanDetail> buildEffectiveCommercialPlans(
    EffectiveCommercialConfig config,
  ) {
    if (!config.hasSyncedOverride) {
      return officialCommercialPlansData;
    }

    final numFmt = NumberFormat('#,##0', 'en_US');
    return officialCommercialPlansData
        .map((base) {
          final spec = config.productById(base.id);
          final defSpec =
              EffectiveCommercialConfig.defaultPlansMap[base.id] ?? spec;

          final formattedAiCount = numFmt.format(spec.aiCredits);
          final effectiveAiBadge = spec.aiCredits > 0
              ? '+$formattedAiCount IA'
              : 'Sin bono IA';

          final durationChanged =
              spec.days != defSpec.days ||
              spec.updatesMonths != defSpec.updatesMonths;
          final String effectiveDuration;
          if (!durationChanged) {
            effectiveDuration = base.duration;
          } else if (base.isPerpetual) {
            effectiveDuration =
                'Vitalicia (De por vida, ${spec.updatesMonths} meses de updates)';
          } else if (base.isUpdatePass) {
            effectiveDuration =
                '${spec.updatesMonths} meses de actualizaciones de versión';
          } else if (spec.days > 0) {
            effectiveDuration = '${spec.days} días continuos';
          } else {
            effectiveDuration = 'Permanente (No expira nunca)';
          }

          final aiChanged = spec.aiCredits != defSpec.aiCredits;
          final String effectiveAiQuota;
          if (!aiChanged) {
            effectiveAiQuota = base.aiQuota;
          } else if (base.isExtraAi) {
            effectiveAiQuota = '+$formattedAiCount escaneos IA acumulativos';
          } else {
            effectiveAiQuota =
                '$formattedAiCount escaneos inteligentes IA incluidos';
          }

          final priceChanged = (spec.price - defSpec.price).abs() > 0.001;
          final effectiveSavings = priceChanged
              ? 'Tarifa comercial oficial actualizada: ${spec.formattedPrice}'
              : base.savings;

          final effectiveBenefits = (!aiChanged && !durationChanged)
              ? base.benefits
              : <String>[
                  if (base.isPerpetual)
                    'Licencia de por vida para el dispositivo vinculado (${spec.updatesMonths} meses de updates incluidos)'
                  else if (base.isUpdatePass)
                    '${spec.updatesMonths} meses adicionales de acceso a nuevas funciones y mejoras'
                  else if (base.isExtraAi)
                    'Recarga inmediata de $formattedAiCount escaneos acumulativos que nunca vencen'
                  else
                    'Acceso total comercial durante ${spec.days} días continuos',
                  if (!base.isExtraAi)
                    '$formattedAiCount escaneos IA incluidos para digitalizar listas y facturas',
                  'Operación 100% offline garantizada y soporte técnico directo vía WhatsApp',
                ];

          return CommercialPlanDetail(
            id: base.id,
            name: spec.label.trim().isNotEmpty ? spec.label.trim() : base.name,
            price: spec.formattedPrice,
            desc: spec.description.trim().isNotEmpty
                ? spec.description.trim()
                : base.desc,
            badge: base.badge,
            aiBadge: effectiveAiBadge,
            duration: effectiveDuration,
            aiQuota: effectiveAiQuota,
            savings: effectiveSavings,
            idealFor: base.idealFor,
            benefits: effectiveBenefits,
            isPerpetual: base.isPerpetual,
            isExtraAi: base.isExtraAi,
            isUpdatePass: base.isUpdatePass,
          );
        })
        .toList(growable: false);
  }

const List<CommercialPlanDetail> officialCommercialPlansData = [
  CommercialPlanDetail(
    id: "mensual",
    name: "Mensual",
    price: "S/ 35.00",
    desc: "Ideal para probar el sistema mes a mes",
    badge: "Flexible",
    aiBadge: "+50 IA",
    duration: "30 días continuos",
    aiQuota: "50 escaneos inteligentes IA incluidos",
    savings: "Tarifa flexible sin compromisos a largo plazo",
    idealFor: "Negocios que inician o desean probar la plataforma mes a mes",
    benefits: [
      "Acceso total a todos los módulos comerciales y financieros",
      "50 escaneos IA para digitalizar listas escolares y facturas",
      "Soporte técnico directo vía WhatsApp con el desarrollador",
      "Operación 100% offline garantizada para inventario y ventas",
      "Días restantes acumulables si renuevas antes del vencimiento",
    ],
  ),
  CommercialPlanDetail(
    id: "trimestral",
    name: "Trimestral",
    price: "S/ 90.00",
    desc: "Ahorro de S/ 15 vs mensual (S/ 30/mes)",
    badge: "Popular",
    aiBadge: "+180 IA",
    duration: "90 días continuos (3 meses)",
    aiQuota: "180 escaneos inteligentes IA incluidos",
    savings: "Ahorras S/ 15.00 frente a tres pagos mensuales (S/ 30.00/mes)",
    idealFor:
        "Comercios con campañas regulares de temporada escolar o festiva",
    benefits: [
      "Ahorro comercial directo frente al plan mensual",
      "180 escaneos IA acumulables con vigencia continua",
      "Copia de seguridad en Google Drive y exportación de reportes",
      "Soporte prioritario del desarrollador oficial",
      "Sin interrupciones durante un trimestre completo de ventas",
    ],
  ),
  CommercialPlanDetail(
    id: "semestral",
    name: "Semestral",
    price: "S/ 160.00",
    desc: "Ahorro de S/ 50 (S/ 26.60/mes)",
    badge: "Recomendado",
    aiBadge: "+450 IA",
    duration: "180 días continuos (6 meses)",
    aiQuota: "450 escaneos inteligentes IA incluidos",
    savings: "Ahorras S/ 50.00 frente al plan mensual (S/ 26.60/mes)",
    idealFor:
        "Librerías, bazares y papelerías que cubren toda la campaña escolar",
    benefits: [
      "Costo mensual optimizado a solo S/ 26.60 al mes",
      "450 escaneos IA para alta demanda de inicio de clases",
      "Radar Comercial y sugerencias inteligentes de precios",
      "Sincronización multi-dispositivo y respaldo en la nube",
      "Asesoría directa en configuración y carga de catálogos",
    ],
  ),
  CommercialPlanDetail(
    id: "anual",
    name: "Anual",
    price: "S/ 280.00",
    desc: "Mayor ahorro comercial (S/ 23.30/mes)",
    badge: "Mejor Precio",
    aiBadge: "+1,200 IA",
    duration: "365 días continuos (1 año completo)",
    aiQuota: "1,200 escaneos inteligentes IA incluidos",
    savings: "Máximo ahorro anual: S/ 140.00 de ahorro (S/ 23.30/mes)",
    idealFor:
        "Empresas y librerías consolidadas que buscan máxima rentabilidad",
    benefits: [
      "Tarifa mensual más económica del mercado (S/ 23.30/mes)",
      "1,200 escaneos IA para cubrir todo el año sin preocupaciones",
      "Todas las actualizaciones de versión mayores y menores incluidas",
      "Soporte VIP directo y asistencia en restauraciones",
      "Garantía de continuidad operativa sin cortes durante todo el año",
    ],
  ),
  CommercialPlanDetail(
    id: "perpetua",
    name: "Perpetua",
    price: "S/ 850.00",
    desc: "Pago único de por vida + 12 meses de updates",
    badge: "Liberada",
    aiBadge: "+200 IA",
    duration: "Vitalicia (De por vida, sin caducidad)",
    aiQuota: "200 escaneos IA iniciales incluidos",
    savings:
        "Pago único definitivo sin costos de suscripción mensual ni anual",
    idealFor:
        "Dueños de negocio que desean adquirir el software en propiedad definitiva",
    isPerpetual: true,
    benefits: [
      "Licencia de por vida para el dispositivo vinculado",
      "Cero pagos recurrentes obligatorios",
      "12 meses completos de actualizaciones de nuevas funciones incluidos",
      "Uso 100% offline indefinido de todas las funciones base",
      "Opción de transferir licencia en caso de cambio de celular certificado",
    ],
  ),
  CommercialPlanDetail(
    id: "bolsa_extra_ia",
    name: "Bolsa Extra IA",
    price: "S/ 20.00",
    desc: "+150 escaneos acumulativos sin vencimiento para cualquier plan",
    badge: "Bolsa IA",
    aiBadge: "+150 IA",
    duration: "Permanente (No expira nunca)",
    aiQuota: "+150 escaneos IA acumulativos",
    savings: "Tarifa reducida por escaneo: S/ 0.13 por escaneo inteligente",
    idealFor:
        "Negocios con picos intensivos de escaneo OCR de facturas y listas",
    isExtraAi: true,
    benefits: [
      "Recarga inmediata de 150 escaneos de alta precisión con Gemini IA",
      "Tus escaneos nunca vencen y se suman a tu saldo actual",
      "Compatible con cualquier plan activo (Mensual, Anual o Perpetua)",
      "Puede adquirirse tantas veces como sea necesario",
      "Escaneo instantáneo de listas escolares manuscritas y facturas físicas",
    ],
  ),
  CommercialPlanDetail(
    id: "pase_anual_updates",
    name: "Pase Anual de Updates",
    price: "S/ 150.00",
    desc: "12 meses extra de nuevas funciones para Licencias Perpetuas",
    badge: "Updates",
    aiBadge: "+100 IA",
    duration: "365 días de actualizaciones de versión",
    aiQuota: "+100 escaneos IA incluidos con la renovación",
    savings:
        "Extensión económica para mantener el software al día con nuevas normas",
    idealFor:
        "Usuarios de Licencia Perpetua que desean seguir recibiendo mejoras continuas",
    isUpdatePass: true,
    benefits: [
      "12 meses adicionales de acceso a nuevas funciones y mejoras",
      "100 escaneos IA de regalo con la renovación",
      "Compatibilidad con las últimas versiones de Android y cambios tributarios",
      "Tu licencia base sigue funcionando de por vida aunque no renueves el pase",
      "Soporte prioritario continuo del desarrollador oficial",
    ],
  ),
];
