part of 'cuota_morosidad_modal.dart';

mixin _CuotaMorosidadPreviewActionsMixin on _CuotaMorosidadStateBase {
  @override
  Widget _buildBottomAction(bool isDark, bool isVencida, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPreviewCard(isDark, isVencida, textColor),
        const SizedBox(height: 10),
        _buildActionButtons(isDark, isVencida),
      ],
    );
  }

  Widget _buildPreviewCard(bool isDark, bool isVencida, Color textColor) {
    final double previewBase = _montoOriginal;
    double previewMora = 0.0;
    double previewTotal = _montoOriginal;

    if (!isVencida) {
      previewMora = _computedMoraMonto;
      previewTotal = _montoOriginal;
    } else {
      if (_activeTab == 'manual') {
        previewMora = _computedMoraMonto;
        previewTotal = _computedTotal;
      } else {
        if (_autoActiva) {
          if (_calcularDesdeVencimiento) {
            int interval = 1;
            if (_autoFrecuencia == 'personalizado') {
              interval = int.tryParse(_customDaysCtrl.text) ?? 1;
              if (interval < 1) interval = 1;
            } else {
              switch (_autoFrecuencia) {
                case 'cada_2_dias': interval = 2; break;
                case 'cada_3_dias': interval = 3; break;
                case 'semanal': interval = 7; break;
                case 'quincenal': interval = 15; break;
                case 'mensual': interval = 30; break;
                case 'diario':
                default: interval = 1; break;
              }
            }
            final String? dueDateStr = widget.cuota['fecha_vencimiento']?.toString();
            DateTime? dueDate;
            try {
              dueDate = DateTime.tryParse(dueDateStr?.split('T').first ?? '');
            } catch (_) {}
            final todayNorm = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final int daysDiff = dueDate != null ? todayNorm.difference(dueDate).inDays : 0;
            final int daysOverdue = daysDiff > 0 ? daysDiff : 0;
            final int periods = daysOverdue ~/ interval;
            final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
            final double recargoPorPeriodo = _calcType == 'porcentaje'
                ? (_montoOriginal * (val / 100))
                : val;
            previewMora = periods * recargoPorPeriodo;
            previewTotal = _montoOriginal + previewMora;
          } else {
            previewMora = 0.0;
            previewTotal = _montoOriginal;
          }
        } else {
          previewMora = _moraMontoActual;
          previewTotal = _montoOriginal + _moraMontoActual;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Monto Base: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      Text(AppCurrency.format(previewBase), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Mora: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      Text(
                        previewMora > 0.01 ? "+ ${AppCurrency.format(previewMora)}" : "S/ 0.00",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: previewMora > 0.01 ? Colors.amber[800] : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, thickness: 0.8),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  !isVencida ? "Total Exigible Hoy (En Plazo):" : "Nuevo Total de la Cuota:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppCurrency.format(previewTotal),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: !isVencida ? Colors.blue[400] : Colors.green[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool isVencida) {
    final bool hasActiveMora = _moraMontoActual > 0.01 || _autoActiva;
    return Row(
      children: [
        if (hasActiveMora) ...[
          IconButton(
            onPressed: _isSaving ? null : _handleQuitarMora,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: "Quitar / Condonar Mora",
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
            ),
            child: Text(
              "Cancelar",
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isSaving
                    ? "Guardando..."
                    : (!isVencida ? "Guardar Regla Programada" : "Guardar y Aplicar"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
