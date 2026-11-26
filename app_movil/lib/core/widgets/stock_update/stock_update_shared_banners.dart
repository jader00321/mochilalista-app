part of '../stock_update_modal.dart';

extension _StockUpdateSharedBannersExtension on _StockUpdateModalState {
  Widget _buildSharedStockSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_maxPhysicalUnits == 0 && _poolBaseUnits > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF78350F).withValues(alpha: 0.25)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.amber.shade700 : const Color(0xFFFCD34D),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.amber[300]
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Unidades base insuficientes para 1 $_unidadVenta",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amber[200]
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Quedan $_poolBaseUnits unidades base sueltas que no alcanzan para formar 1 paquete de esta variante (requiere $_factor unidades). Puedes editar el producto para crear una variante por Unidad o ajustar el factor.",
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.amber[100] : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.amber[700]
                          : const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _navigateToEdit,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text(
                      "Editar Producto",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (((widget.presentation.cupoMaximoVariante == 0) ||
                (_parsedInput == 0)) &&
            _maxPhysicalUnits > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF78350F).withValues(alpha: 0.25)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.amber.shade700 : const Color(0xFFFCD34D),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.amber[300]
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Stock asignado para vender agotado (0 disp.)",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amber[200]
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "El stock asignado para vender llegó a 0, pero aún cuentas con $_poolBaseUnits unidades base en inventario (hasta $_maxPhysicalUnits $_unidadVenta disponibles). Aumenta el cupo o pulsa \"Restaurar al máximo\".",
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.amber[100] : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.amber[700]
                              : const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _update(_maxPhysicalUnits),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Restaurar al máximo ($_maxPhysicalUnits)",
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.amber[200]
                              : const Color(0xFF92400E),
                          side: BorderSide(
                            color: isDark
                                ? Colors.amber[400]!
                                : const Color(0xFFB45309),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _navigateToEdit,
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Editar Producto",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.blue.shade700 : const Color(0xFF93C5FD),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.blue[300]
                          : const Color(0xFF1E40AF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Inventario base compartido",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.blue[200]
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Inventario base compartido: $_poolBaseUnits und. · Máximo posible: $_maxPhysicalUnits $_unidadVenta.\n\nPuedes acotar un stock disponible para vender menor para esta variante sin alterar las unidades físicas del almacén.",
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.blue[100] : const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.blue[400]!
                                : Colors.blue[800]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _update(_maxPhysicalUnits),
                        icon: const Icon(Icons.refresh, size: 13),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Usar máximo ($_maxPhysicalUnits)",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.blue[400]!
                                : Colors.blue[800]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _navigateToEdit,
                        icon: const Icon(Icons.edit_note, size: 14),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Editar Producto",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Banner Temporal Animado de Exceso de Máximo Físico
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showExcessWarning
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.shade900.withValues(alpha: 0.35)
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
                width: 1.3,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isDark
                      ? Colors.orange.shade300
                      : Colors.orange.shade900,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "No puedes aumentar más del máximo permitido ($_maxPhysicalUnits $_unidadVenta según tus $_poolBaseUnits unidades base compartidas).",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.orange.shade200
                              : Colors.orange.shade900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "El cambio de la cantidad de unidades base solo se puede realizar en la ventana de Editar Producto.",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _navigateToEdit,
                          icon: const Icon(Icons.arrow_forward, size: 13),
                          label: const Text(
                            "Ir a Editar Producto",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            foregroundColor: isDark
                                ? Colors.orange.shade200
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
