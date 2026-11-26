import '../core/commercial_constants.dart';
import 'config_defaults.dart';

/// Motor de renderizado de plantillas WhatsApp con supresión inteligente de bloques bancarios.
class ConfigTemplateRenderer {
  ConfigTemplateRenderer._();

  static String render({
    required String templateKeyOrRaw,
    required Map<String, dynamic> context,
    required Map<String, dynamic> templates,
    required Map<String, dynamic> paymentMethods,
    required Map<String, dynamic> legalIdentity,
  }) {
    String template = templateKeyOrRaw;
    if (templates.containsKey(templateKeyOrRaw)) {
      template = templates[templateKeyOrRaw] as String;
    } else {
      final canonKey = ConfigDefaults.canonicalTemplateKey(templateKeyOrRaw);
      if (templates.containsKey(canonKey)) {
        template = templates[canonKey] as String;
      }
    }

    final bcpBlock = _buildBankBlock(
      label: 'BCP',
      account: paymentMethods['bcp_account_number'] as String? ?? '',
      holder: paymentMethods['bcp_account_holder'] as String? ?? '',
      cci: paymentMethods['bcp_cci'] as String? ?? '',
    );
    final bbvaBlock = _buildBankBlock(
      label: 'BBVA',
      account: paymentMethods['bbva_account_number'] as String? ?? '',
      holder: paymentMethods['bbva_account_holder'] as String? ?? '',
      cci: paymentMethods['bbva_cci'] as String? ?? '',
    );

    final vars = <String, String>{
      '{autor}': legalIdentity['author_full_name'] as String? ??
          CommercialConstants.defaultAuthorName,
      '{yape_phone}': paymentMethods['yape_plin_phone'] as String? ??
          CommercialConstants.defaultYapePlinPhone,
      '{yape_titular}': paymentMethods['yape_plin_holder'] as String? ??
          CommercialConstants.defaultAuthorName,
      '{bloque_banco_bcp}': bcpBlock,
      '{bloque_banco_bbva}': bbvaBlock,
      '{commercial_name}': legalIdentity['commercial_name'] as String? ??
          CommercialConstants.defaultCommercialName,
      '{support_phone}': legalIdentity['support_phone'] as String? ??
          CommercialConstants.defaultSupportPhone,
    };

    context.forEach((key, val) {
      final cleanKey = key.startsWith('{') && key.endsWith('}') ? key : '{$key}';
      vars[cleanKey] = val?.toString() ?? '';
    });
    if (vars.containsKey('{codigo}') && !vars.containsKey('{codigo_licencia}')) {
      vars['{codigo_licencia}'] = vars['{codigo}']!;
    } else if (vars.containsKey('{codigo_licencia}') &&
        !vars.containsKey('{codigo}')) {
      vars['{codigo}'] = vars['{codigo_licencia}']!;
    }
    if (vars.containsKey('{commercial_name}') &&
        !vars.containsKey('{brand_name}')) {
      vars['{brand_name}'] = vars['{commercial_name}']!;
    }

    String result = template;
    vars.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    return result;
  }

  static String _buildBankBlock({
    required String label,
    required String account,
    required String holder,
    required String cci,
  }) {
    final trimmedAcc = account.trim();
    if (trimmedAcc.isEmpty) return '';
    final cciPart = cci.trim().isNotEmpty ? ' (CCI: ${cci.trim()})' : '';
    final holderPart = holder.trim().isNotEmpty ? ' - ${holder.trim()}' : '';
    return '\n🏦 $label: $trimmedAcc$cciPart$holderPart';
  }
}
