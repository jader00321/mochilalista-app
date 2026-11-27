part of '../quick_sale_header.dart';

mixin _QuickSaleClientSectionsMixin on _QuickSaleHeaderBase {
  Widget _buildSelectedClientCard(
    BuildContext context,
    QuickSaleProvider provider,
  ) {
    final selectedClient = provider.selectedClient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF23232F) : Colors.blue[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? Colors.white12 : Colors.blue.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.isDark
                        ? Colors.blue.withValues(alpha: 0.25)
                        : Colors.blue[200],
                    radius: 22,
                    child: Text(
                      provider.clientName!.isNotEmpty
                          ? provider.clientName![0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        color: widget.isDark ? Colors.blue[300] : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.clientName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        if (provider.clientPhone != null &&
                            provider.clientPhone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.smartphone_rounded,
                                size: 13,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatPhone(provider.clientPhone!),
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (selectedClient?.docNumber != null &&
                            selectedClient!.docNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 13,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "DNI/RUC: ${selectedClient.docNumber}",
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (selectedClient?.address != null &&
                            selectedClient!.address!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  selectedClient.address!,
                                  style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (provider.clientNote != null &&
                            provider.clientNote!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Nota: ${provider.clientNote}",
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.teal[300]
                                  : Colors.teal[700],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isEditingClient
                          ? Icons.close_rounded
                          : Icons.edit_note_rounded,
                      color: widget.isDark
                          ? Colors.blue[300]
                          : Colors.blue[700],
                    ),
                    tooltip: _isEditingClient
                        ? "Cerrar edición"
                        : "Editar datos del cliente",
                    onPressed: () {
                      setState(() {
                        _isEditingClient = !_isEditingClient;
                      });
                    },
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isEditingClient
                    ? _buildInSituEditForm(provider)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              provider.setClientInfo(
                id: null,
                name: null,
                phone: null,
                clientNote: null,
                saleNote: provider.saleNote,
                saldo: 0,
              );
              setState(() {
                _isEditingClient = false;
                _nameCtrl.clear();
                _phoneCtrl.clear();
                _dniCtrl.clear();
                _addressCtrl.clear();
                _notesCtrl.clear();
              });
            },
            icon: const Icon(
              Icons.person_off_outlined,
              color: Colors.redAccent,
              size: 16,
            ),
            label: const Text(
              "Desvincular Cliente",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInSituEditForm(QuickSaleProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: widget.isDark ? Colors.white12 : Colors.blue.shade100),
          const SizedBox(height: 6),
          Text(
            "Editar Ficha del Cliente:",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.blue[200] : Colors.blue[900],
            ),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _nameCtrl,
            label: "Nombre Completo",
            icon: Icons.person_outline,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _phoneCtrl,
            label: "Teléfono / WhatsApp",
            icon: Icons.phone_outlined,
            isDark: widget.isDark,
            isPhone: true,
          ),
          const SizedBox(height: 10),
          _buildDniAndAddressRow(),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _notesCtrl,
            label: "Notas Internas del Cliente",
            icon: Icons.note_outlined,
            isDark: widget.isDark,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSavingClient
                  ? null
                  : () => _saveClientChanges(provider),
              icon: _isSavingClient
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSavingClient
                      ? "Guardando en BD..."
                      : "Guardar Cambios del Cliente",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkInClientSection(QuickSaleProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "O registra un cliente de paso:",
          style: TextStyle(
            color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _nameCtrl,
          label: "Nombre del Cliente",
          icon: Icons.person_outline,
          isDark: widget.isDark,
          onChanged: (val) {
            provider.setClientInfo(
              id: null,
              name: val.trim().isEmpty ? null : val,
              phone: provider.clientPhone,
              clientNote: provider.clientNote,
              saleNote: provider.saleNote,
              saldo: 0,
            );
          },
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _phoneCtrl,
          label: "Teléfono / WhatsApp",
          icon: Icons.phone_outlined,
          isDark: widget.isDark,
          isPhone: true,
          onChanged: (val) {
            final cleanPhone = val.replaceAll(' ', '');
            provider.setClientInfo(
              id: null,
              name: provider.clientName,
              phone: cleanPhone.trim().isEmpty ? null : cleanPhone,
              clientNote: provider.clientNote,
              saleNote: provider.saleNote,
              saldo: 0,
            );
          },
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showExtraWalkInFields = !_showExtraWalkInFields;
                  });
                },
                icon: Icon(
                  _showExtraWalkInFields
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                  size: 15,
                  color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                label: Text(
                  _showExtraWalkInFields
                      ? "Ocultar datos extra"
                      : "+ DNI, Dirección y Notas",
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              ),
            ),
            if (_nameCtrl.text.trim().isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSavingClient
                      ? null
                      : () => _registerWalkInClient(provider),
                  icon: _isSavingClient
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF00C853),
                          ),
                        )
                      : const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 15,
                          color: Color(0xFF00C853),
                        ),
                  label: Text(
                    "Guardar en Directorio",
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showExtraWalkInFields
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      _buildDniAndAddressRow(),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _notesCtrl,
                        label: "Notas de la Venta / Cliente",
                        icon: Icons.note_outlined,
                        isDark: widget.isDark,
                        onChanged: (val) {
                          provider.setClientInfo(
                            clientNote: val.trim().isEmpty ? null : val.trim(),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDniAndAddressRow() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildTextField(
            controller: _dniCtrl,
            label: "DNI / RUC",
            icon: Icons.badge_outlined,
            isDark: widget.isDark,
            keyboardType: TextInputType.number,
            maxLength: 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: _buildTextField(
            controller: _addressCtrl,
            label: "Dirección",
            icon: Icons.location_on_outlined,
            isDark: widget.isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPhone = false,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      keyboardType: isPhone
          ? TextInputType.phone
          : (keyboardType ?? TextInputType.text),
      inputFormatters: isPhone
          ? [FilteringTextInputFormatter.digitsOnly, _PhoneFormatter()]
          : (maxLength != null
                ? [LengthLimitingTextInputFormatter(maxLength)]
                : null),
      maxLength: isPhone ? 11 : maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.blueGrey[300] : Colors.blueGrey,
          size: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        isDense: true,
        counterText: "",
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );
  }
}
