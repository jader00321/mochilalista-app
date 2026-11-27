part of '../discount_intelligent_modal.dart';

extension _DiscountIntelligentControlsPart on _DiscountIntelligentModalState {
  Widget _buildHeaderSection(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.purple.withValues(alpha: 0.2)
                      : Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_offer,
                  color: widget.isDark ? Colors.purple[300] : Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Gestión de Descuento",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _isActive,
          activeThumbColor: Colors.purple,
          onChanged: (val) {
            _updateState(() {
              _isActive = val;
              _activeRoundingTarget = null;
              _precioOfertaExacto = null;
              _recalcularPrecio();
            });
          },
        ),
      ],
    );
  }

  Widget _buildControlsBody({
    required Color textColor,
    required bool isKeyboardOpen,
    required double valor,
    required bool isFijo,
    required int discountPercentRounded,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isKeyboardOpen ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeSelectorRow(isFijo),
          SizedBox(height: isKeyboardOpen ? 12 : 20),
          _buildAmountField(textColor, isFijo),
          if (isFijo)
            _buildFijoExplanationBanner(
              valor: valor,
              discountPercentRounded: discountPercentRounded,
            ),
          const SizedBox(height: 12),
          _buildRoundingChipsRow(),
        ],
      ),
    );
  }

  Widget _buildModeSelectorRow(bool isFijo) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_tipoDescuento != 'porcentaje') {
                final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
                if (_precioBase > 0 && val > 0 && val < _precioBase) {
                  final double calcPercent =
                      ((_precioBase - val) / _precioBase) * 100;
                  _valorCtrl.text = calcPercent.round().toString();
                }
                _updateState(() {
                  _tipoDescuento = 'porcentaje';
                  _activeRoundingTarget = null;
                  _precioOfertaExacto = null;
                  _recalcularPrecio();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: _tipoDescuento == 'porcentaje'
                    ? Colors.purple
                    : (widget.isDark ? Colors.white10 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "% Porcentaje",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _tipoDescuento == 'porcentaje'
                        ? Colors.white
                        : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_tipoDescuento != 'fijo') {
                final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
                if (_precioBase > 0 && val > 0 && val < 100) {
                  final double calcOffer = _precioBase * (1 - (val / 100));
                  _valorCtrl.text = calcOffer.toStringAsFixed(2);
                }
                _updateState(() {
                  _tipoDescuento = 'fijo';
                  _activeRoundingTarget = null;
                  _precioOfertaExacto = null;
                  _recalcularPrecio();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isFijo
                    ? Colors.purple
                    : (widget.isDark ? Colors.white10 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "S/ Fijo",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFijo
                        ? Colors.white
                        : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(Color textColor, bool isFijo) {
    return TextField(
      controller: _valorCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      scrollPadding: const EdgeInsets.only(bottom: 90),
      onChanged: (_) => _onValorChanged(),
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: isFijo ? "Precio Oferta S/" : "Porcentaje de descuento (%)",
        labelStyle: TextStyle(
          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 14,
        ),
        prefixText: isFijo ? "S/ " : null,
        suffixText: !isFijo ? "%" : null,
        prefixStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        suffixStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        filled: true,
        fillColor: widget.isDark ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.purple, width: 2),
        ),
      ),
    );
  }

  Widget _buildFijoExplanationBanner({
    required double valor,
    required int discountPercentRounded,
  }) {
    if (valor > 0 && valor < _precioBase) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.purple.withValues(alpha: 0.15)
                : Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isDark
                  ? Colors.purple.withValues(alpha: 0.3)
                  : Colors.purple.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: widget.isDark ? Colors.purple[300] : Colors.purple[800],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Descuento aplicado: ${AppCurrency.format(_precioBase - valor)} menos sobre el precio normal de ${AppCurrency.format(_precioBase)} (-$discountPercentRounded%)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? Colors.purple[200]
                        : Colors.purple[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (valor >= _precioBase && _precioBase > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isDark
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: widget.isDark ? Colors.red[300] : Colors.red[800],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "El precio de oferta (${AppCurrency.format(valor)}) debe ser menor al precio regular (${AppCurrency.format(_precioBase)})",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.red[300] : Colors.red[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRoundingChipsRow() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          "Redondear oferta:",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        _RoundOfferChip(
          label: ".50",
          targetFraction: 0.50,
          isActive: _activeRoundingTarget == 0.50,
          isDark: widget.isDark,
          onTap: () => _roundOfferPrice(0.50),
        ),
        _RoundOfferChip(
          label: ".90",
          targetFraction: 0.90,
          isActive: _activeRoundingTarget == 0.90,
          isDark: widget.isDark,
          onTap: () => _roundOfferPrice(0.90),
        ),
        _RoundOfferChip(
          label: ".00",
          targetFraction: 1.00,
          isActive:
              _activeRoundingTarget == 1.00 || _activeRoundingTarget == 0.00,
          isDark: widget.isDark,
          onTap: () => _roundOfferPrice(1.00),
        ),
      ],
    );
  }
}

class _RoundOfferChip extends StatelessWidget {
  final String label;
  final double targetFraction;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _RoundOfferChip({
    required this.label,
    required this.targetFraction,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? Colors.purple.withValues(alpha: 0.35)
                    : Colors.purple.shade100)
              : (isDark ? const Color(0xFF1E1E28) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.purple.shade300 : Colors.purple.shade700)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Icon(
                Icons.check_rounded,
                size: 13,
                color: isDark ? Colors.purple[200] : Colors.purple[900],
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                color: isActive
                    ? (isDark ? Colors.purple[100] : Colors.purple[900])
                    : (isDark ? Colors.purple[300] : Colors.purple[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
