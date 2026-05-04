import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/crm_models.dart';
import '../../providers/tracking_provider.dart';
import '../../../../widgets/custom_snackbar.dart';

class PaymentEntryModal extends StatefulWidget {
  final ClientModel client;

  const PaymentEntryModal({super.key, required this.client});

  @override
  State<PaymentEntryModal> createState() => _PaymentEntryModalState();
}

class _PaymentEntryModalState extends State<PaymentEntryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountCtrl = TextEditingController();
  
  String _method = "Efectivo";
  bool _isLoading = false;
  
  String? _selectedTargetType; 
  int? _selectedTargetId;

  bool _keepAsCredit = false; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _amountCtrl.addListener(() {
      setState(() {}); 
    });
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TrackingProvider>(context, listen: false).loadClientDebts(widget.client.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double _calculateTargetDebt(TrackingProvider provider) {
    if (_tabController.index == 0) return widget.client.totalDebt;

    double targetDebt = widget.client.totalDebt;

    if (_tabController.index == 1 && _selectedTargetId != null) {
      if (_selectedTargetType == 'venta') {
        try {
          final sale = provider.currentClientDebts.firstWhere((s) => s.id == _selectedTargetId);
          targetDebt = sale.totalAmount - sale.paidAmount;
        } catch (_) {}
      } else if (_selectedTargetType == 'cuota') {
        for (var sale in provider.currentClientDebts) {
          try {
            final cuota = sale.installments.firstWhere((c) => c.id == _selectedTargetId);
            targetDebt = cuota.amount - cuota.montoPagado;
            break;
          } catch (_) {}
        }
      }
    }
    
    return targetDebt;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final provider = Provider.of<TrackingProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    double enteredAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    double maxDebtAllowed = widget.client.totalDebt; // Ahora siempre es la deuda total (permite cascada global)
    double targetDebt = _calculateTargetDebt(provider);
    
    bool isPayingWithSaldo = _method == "Saldo a Favor";
    bool generatesChange = !isPayingWithSaldo && (enteredAmount > maxDebtAllowed) && maxDebtAllowed > 0;
    double changeAmount = generatesChange ? (enteredAmount - maxDebtAllowed) : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90, 
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Registrar Abono", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(icon: Icon(Icons.close, size: 28, color: textColor), onPressed: () => Navigator.pop(context))
                  ],
                ),
                Text("Deuda Total: ${currency.format(widget.client.totalDebt)}", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: isDark ? Colors.green[400] : Colors.green),
                  decoration: InputDecoration(
                    labelText: "Monto a abonar",
                    labelStyle: TextStyle(color: isDark ? Colors.green[200] : Colors.green[700], fontSize: 16),
                    prefixText: "S/ ",
                    prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: isDark ? Colors.green[400] : Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? Colors.green.withOpacity(0.1) : Colors.green[50],
                  ),
                ),
                const SizedBox(height: 20),
                
                Text("Método de Pago", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey)),
                const SizedBox(height: 12),
                
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 10,
                    children: [
                      if (widget.client.saldoAFavor > 0) "Saldo a Favor", 
                      "Efectivo", "Yape", "Plin", "Transferencia", "Tarjeta"
                    ].map((m) {
                      final isSelected = _method == m;
                      final isSaldoBtn = m == "Saldo a Favor";
                      
                      return ChoiceChip(
                        label: Text(m, style: TextStyle(color: isSaldoBtn && !isSelected ? (isDark ? Colors.amber[300] : Colors.amber[900]) : null, fontSize: 15)),
                        selected: isSelected,
                        onSelected: (v) {
                          setState(() {
                            _method = m;
                            if (isSaldoBtn && _amountCtrl.text.isEmpty) {
                              double capAmount = widget.client.saldoAFavor < targetDebt ? widget.client.saldoAFavor : targetDebt;
                              _amountCtrl.text = capAmount.toStringAsFixed(2);
                            }
                          });
                        },
                        selectedColor: isSaldoBtn ? (isDark ? Colors.amber.withOpacity(0.3) : Colors.amber[100]) : (isDark ? Colors.green.withOpacity(0.3) : Colors.green[100]),
                        backgroundColor: isSaldoBtn ? (isDark ? Colors.amber.withOpacity(0.1) : Colors.amber[50]) : (isDark ? const Color(0xFF14141C) : Colors.grey[100]),
                        labelStyle: TextStyle(
                          color: isSelected ? (isSaldoBtn ? (isDark ? Colors.amber[200] : Colors.amber[900]) : (isDark ? Colors.green[300] : Colors.green[900])) : (isDark ? Colors.white70 : Colors.black), 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        ),
                        side: BorderSide(color: isSaldoBtn ? (isDark ? Colors.amber.withOpacity(0.5) : Colors.amber.shade300) : Colors.transparent),
                      );
                    }).toList(),
                  ),
                ),

                if (isPayingWithSaldo)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text("Saldo Disponible: ${currency.format(widget.client.saldoAFavor)}", style: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontSize: 14, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
            unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey,
            indicatorColor: isDark ? Colors.blue[300] : Colors.blue[800],
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            onTap: (index) {
              if (index == 0) {
                setState(() {
                  _selectedTargetType = null;
                  _selectedTargetId = null;
                });
              }
            },
            tabs: const [
              Tab(text: "Distribución Automática"),
              Tab(text: "Pago Específico"),
            ],
          ),
          
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

          Expanded(
            child: provider.isLoadingDebts
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGeneralPreviewTab(provider.currentClientDebts, isDark),
                      _buildSpecificSelectionTab(provider.currentClientDebts, isDark),
                    ],
                  ),
          ),

          if (changeAmount > 0.01)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? Colors.amber.withOpacity(0.1) : Colors.amber[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.amber.withOpacity(0.3) : Colors.amber.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: isDark ? Colors.amber[300] : Colors.amber[900], size: 28),
                      const SizedBox(width: 10),
                      Text("Excedente: ${currency.format(changeAmount)}", style: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OptionButton(
                          title: "Dar Vuelto",
                          isSelected: !_keepAsCredit,
                          onTap: () => setState(() => _keepAsCredit = false),
                          color: Colors.orange,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OptionButton(
                          title: "Guardar Saldo",
                          isSelected: _keepAsCredit,
                          onTap: () => setState(() => _keepAsCredit = true),
                          color: Colors.green,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submitPayment(maxDebtAllowed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(generatesChange && !_keepAsCredit ? "REGISTRAR Y DAR VUELTO" : "PROCESAR PAGO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeneralPreviewTab(List<SaleModel> debts, bool isDark) {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;

    if (amount <= 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 70, color: isDark ? Colors.white10 : Colors.blue[200]),
            const SizedBox(height: 16),
            Text("Ingresa un monto arriba\npara ver cómo se distribuirá el pago.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)),
          ],
        )
      );
    }

    List<Widget> impactPreview = [];
    double remaining = amount;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    for (var sale in debts) {
      if (remaining <= 0.01) break;

      if (sale.installments.isNotEmpty) {
        for (var cuota in sale.installments) {
          if (remaining <= 0.01) break;
          if (cuota.status != 'pagado') {
            double falta = cuota.amount - cuota.montoPagado;
            double aplicado = remaining >= falta ? falta : remaining;
            remaining -= aplicado;
            bool saldado = (falta - aplicado) <= 0.01;

            impactPreview.add(_buildImpactRow(
              saldado, 
              saldado ? "Cancela Cuota ${cuota.installmentNumber} (Venta #${sale.id})" : "Abono parcial a Cuota ${cuota.installmentNumber} (Venta #${sale.id})", 
              aplicado, currency, isDark
            ));
          }
        }
      } else {
        double falta = sale.totalAmount - sale.paidAmount;
        double aplicado = remaining >= falta ? falta : remaining;
        remaining -= aplicado;
        bool saldado = (falta - aplicado) <= 0.01;

        impactPreview.add(_buildImpactRow(
          saldado, 
          saldado ? "Cancela Venta #${sale.id} al contado" : "Abono parcial a Venta #${sale.id}", 
          aplicado, currency, isDark
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("El sistema aplicará tu pago en este orden:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
        const SizedBox(height: 16),
        ...impactPreview,
      ],
    );
  }

  Widget _buildImpactRow(bool saldado, String description, double amount, NumberFormat currency, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white, 
        border: Border.all(color: saldado ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green.shade200) : (isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200)), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          Icon(saldado ? Icons.check_circle : Icons.timelapse, color: saldado ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.orange[300] : Colors.orange), size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(description, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
          Text(currency.format(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: saldado ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.orange[300] : Colors.orange[800]))),
        ],
      ),
    );
  }

  Widget _buildSpecificSelectionTab(List<SaleModel> debts, bool isDark) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    if (debts.isEmpty) {
      return Center(child: Text("No hay deudas específicas.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16)));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.ads_click, color: isDark ? Colors.blue[300] : Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text("Selecciona la venta o cuota exacta que el cliente desea pagar.", style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[800], fontSize: 14))),
              if (_selectedTargetType != null)
                TextButton(
                  onPressed: () => setState((){ _selectedTargetType = null; _selectedTargetId = null; }),
                  child: Text("Limpiar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red))
                )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: debts.length,
            itemBuilder: (ctx, i) {
              final sale = debts[i];
              final double faltaVenta = sale.totalAmount - sale.paidAmount;
              
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF14141C) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                margin: const EdgeInsets.only(bottom: 16),
                child: sale.installments.isEmpty
                  ? RadioListTile<String>(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      value: "venta_${sale.id}",
                      groupValue: _selectedTargetType != null ? "${_selectedTargetType}_$_selectedTargetId" : null,
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetType = 'venta';
                          _selectedTargetId = sale.id;
                          _amountCtrl.text = faltaVenta.toStringAsFixed(2);
                        });
                      },
                      title: Text("Venta #${sale.id}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text("Falta: ${currency.format(faltaVenta)}", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                      activeColor: isDark ? Colors.blue[300] : Colors.blue[800],
                    )
                  : ExpansionTile(
                      title: Text("Venta #${sale.id} (A Crédito)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text("Deuda Restante: ${currency.format(faltaVenta)}", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      iconColor: isDark ? Colors.white : Colors.black,
                      collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
                      children: sale.installments.where((c) => c.status != 'pagado').map((cuota) {
                        final faltaCuota = cuota.amount - cuota.montoPagado;
                        return Container(
                          color: isDark ? Colors.black12 : Colors.grey[50],
                          child: RadioListTile<String>(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            value: "cuota_${cuota.id}",
                            groupValue: _selectedTargetType != null ? "${_selectedTargetType}_$_selectedTargetId" : null,
                            onChanged: (val) {
                              setState(() {
                                _selectedTargetType = 'cuota';
                                _selectedTargetId = cuota.id;
                                _amountCtrl.text = faltaCuota.toStringAsFixed(2);
                              });
                            },
                            title: Text("Cuota ${cuota.installmentNumber}", style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text("Vence: ${DateFormat('dd/MM').format(DateTime.parse(cuota.dueDate))}  |  Falta: ${currency.format(faltaCuota)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.orange[300] : Colors.orange, fontWeight: FontWeight.bold)),
                            activeColor: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        );
                      }).toList(),
                    )
              );
            },
          ),
        ),
      ],
    );
  }

  void _submitPayment(double maxDebtAllowed) async {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    
    if (amount <= 0) {
      CustomSnackBar.show(context, message: "Ingresa un monto válido", isError: true);
      return;
    }

    if (_tabController.index == 1 && _selectedTargetType == null) {
       CustomSnackBar.show(context, message: "Selecciona una cuota o venta a pagar", isError: true);
       return;
    }

    bool isPayingWithSaldo = _method == "Saldo a Favor";

    if (isPayingWithSaldo) {
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(context, message: "No tiene suficiente Saldo a Favor. Disponible: S/ ${widget.client.saldoAFavor.toStringAsFixed(2)}", isError: true);
        return;
      }
      if (amount > maxDebtAllowed) {
        amount = maxDebtAllowed;
      }
    } else {
      if (amount > maxDebtAllowed) {
         if (!_keepAsCredit) {
           amount = maxDebtAllowed; 
         }
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final prov = Provider.of<TrackingProvider>(context, listen: false);
      
      bool isAutomatic = _tabController.index == 0;
      int? ventaId = (!isAutomatic && _selectedTargetType == 'venta') ? _selectedTargetId : null;
      int? cuotaId = (!isAutomatic && _selectedTargetType == 'cuota') ? _selectedTargetId : null;

      String backendMethod = _method.toLowerCase().replaceAll(' ', '_');

      bool success = await prov.registerPayment(
        widget.client.id, 
        amount, 
        backendMethod, 
        ventaId: ventaId, 
        cuotaId: cuotaId,
        guardarVuelto: _keepAsCredit && !isPayingWithSaldo,
        isAutomatic: isAutomatic
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          CustomSnackBar.show(context, message: "¡Abono registrado exitosamente!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al registrar pago.", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _OptionButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isDark;

  const _OptionButton({required this.title, required this.isSelected, required this.onTap, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF14141C) : Colors.white),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title, 
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 15
          )
        ),
      ),
    );
  }
}