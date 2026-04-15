import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 

import '../models/smart_quotation_model.dart';
import '../providers/workbench_provider.dart';
import '../screens/manual_quotation_screen.dart'; 
import '../../../widgets/custom_snackbar.dart';

class QuickActionsBottomSheet extends StatelessWidget {
  final SmartQuotationModel quotation;
  final bool isDark; 
  final BuildContext parentContext; // 🔥 CONTEXTO INMORTAL PARA EL DIÁLOGO

  const QuickActionsBottomSheet({
    super.key, 
    required this.quotation, 
    required this.isDark, 
    required this.parentContext
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: isDark ? Colors.amber[300] : Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quotation.clientName ?? "Opciones Rápidas",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white10 : Colors.grey[200], height: 1),
            const SizedBox(height: 12),
            
            _buildListTile(
              icon: Icons.copy_all, 
              color: isDark ? Colors.blue[300]! : Colors.blue, 
              title: "Duplicar Cotización", 
              subtitle: "Crea una copia idéntica para editar", 
              isDark: isDark, 
              onTap: () {
                Navigator.pop(context); 
                _handleClone();
              }
            ),
            
            _buildListTile(
              icon: Icons.edit, 
              color: isDark ? Colors.orange[300]! : Colors.orange, 
              title: "Cambiar Nombre / Cliente", 
              subtitle: "Actualiza el título de esta lista", 
              isDark: isDark, 
              onTap: () {
                Navigator.pop(context);
                _handleRename();
              }
            ),

            _buildListTile(
              icon: Icons.share, 
              color: isDark ? Colors.green[400]! : Colors.green, 
              title: "Compartir con Cliente", 
              subtitle: "Enviar resumen por WhatsApp o redes", 
              isDark: isDark, 
              onTap: () {
                Navigator.pop(context);
                _handleQuickShare();
              }
            ),

            Divider(color: isDark ? Colors.white10 : Colors.grey[200], indent: 70),

            _buildListTile(
              icon: Icons.delete_outline, 
              color: isDark ? Colors.red[400]! : Colors.red, 
              title: "Eliminar Definitivamente", 
              subtitle: null,
              isDark: isDark, 
              onTap: () {
                Navigator.pop(context);
                _handleDelete();
              }
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required Color color, required String title, String? subtitle, required bool isDark, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), radius: 24, child: Icon(icon, color: color, size: 24)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])) : null,
      onTap: onTap,
    );
  }

  Future<void> _handleClone() async {
    showDialog(context: parentContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final prov = Provider.of<WorkbenchProvider>(parentContext, listen: false);
    int? newId = await prov.cloneQuotation(quotation.id); 
    
    if (parentContext.mounted) {
      Navigator.pop(parentContext); 
      if (newId != null) {
        Navigator.push(parentContext, MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: newId)));
      } else {
        CustomSnackBar.show(parentContext, message: "Error al duplicar la lista.", isError: true);
      }
    }
  }

  Future<void> _handleRename() async {
    final textCtrl = TextEditingController(text: quotation.clientName);
    bool isSaving = false;

    await showDialog(
      context: parentContext,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Renombrar Cotización", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: textCtrl,
              enabled: !isSaving,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                labelText: "Nombre del Cliente o Título",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              if (!isSaving)
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800], 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: isSaving ? null : () async {
                  final newName = textCtrl.text.trim();
                  if (newName.isNotEmpty && newName != quotation.clientName) {
                    setStateModal(() => isSaving = true);
                    
                    final prov = Provider.of<WorkbenchProvider>(parentContext, listen: false);
                    bool success = await prov.renameQuotation(quotation.id, newName); 
                    
                    if (parentContext.mounted) {
                      Navigator.pop(ctx); 
                      CustomSnackBar.show(parentContext, message: success ? "Nombre actualizado" : "Error al cambiar nombre", isError: !success);
                    }
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _handleDelete() async {
    final bool isDraft = quotation.status == 'DRAFT';
    final bool isSold = quotation.status == 'SOLD';
    
    String warningMsg = "¿Estás seguro de que deseas eliminar este borrador?";
    
    if (isSold) {
        warningMsg = "⚠️ ATENCIÓN EXTREMA: Esta lista ya ha sido VENDIDA. Eliminarla podría causar inconsistencias en tu historial y caja.\n\n¿Estás absolutamente seguro de eliminarla definitivamente?";
    } else if (!isDraft) {
        warningMsg = "⚠️ ATENCIÓN: Esta cotización está en proceso (no es un borrador).\n\n¿Realmente deseas eliminarla definitivamente?";
    }

    final confirm = await showDialog<bool>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning_amber, color: isDark ? Colors.red[300] : Colors.red, size: 30), const SizedBox(width: 8), Expanded(child: Text("Eliminar Lista", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)))]),
        content: Text(warningMsg, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Sí, Eliminar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ),
        ],
      ),
    );

    // 🔥 USAMOS EL DIÁLOGO ANIMADO CON EL CONTEXTO INMORTAL
    if (confirm == true && parentContext.mounted) {
      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder: (_) => _DeletingProgressDialog(
          quotationId: quotation.id,
          isDraft: isDraft,
          isDark: isDark,
          parentContext: parentContext,
        ),
      );
    }
  }

  Future<void> _handleQuickShare() async {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(quotation.createdAt));
    
    String text = "Hola 👋, te comparto el resumen de tu cotización:\n\n";
    text += "📝 *Cliente:* ${quotation.clientName ?? 'General'}\n";
    text += "📅 *Fecha:* $dateStr\n";
    
    if (quotation.institutionName != null && quotation.institutionName!.trim().isNotEmpty) {
      text += "🏫 *Colegio:* ${quotation.institutionName}";
      if (quotation.gradeLevel != null && quotation.gradeLevel!.trim().isNotEmpty) {
        text += " - ${quotation.gradeLevel}";
      }
      text += "\n";
    }

    text += "\n📦 *Cantidad de Productos:* ${quotation.itemCount} ítems\n";
    text += "💰 *Total a Pagar:* ${currency.format(quotation.totalAmount)}\n";
    
    if (quotation.totalSavings > 0) {
      text += "✨ *Ahorraste:* ${currency.format(quotation.totalSavings)}\n";
    }
    
    text += "\n¡Quedamos a tu disposición para confirmar la venta!";
    
    await Share.share(text, subject: 'Cotización - ${quotation.clientName}');
  }
}

// 🔥 WIDGET ANIMADO PARA ELIMINACIÓN DE MESAS DE TRABAJO (Con degradación de estados automática)
class _DeletingProgressDialog extends StatefulWidget {
  final int quotationId;
  final bool isDraft;
  final bool isDark;
  final BuildContext parentContext; 

  const _DeletingProgressDialog({
    required this.quotationId,
    required this.isDraft,
    required this.isDark,
    required this.parentContext,
  });

  @override
  State<_DeletingProgressDialog> createState() => _DeletingProgressDialogState();
}

class _DeletingProgressDialogState extends State<_DeletingProgressDialog> {
  String _statusText = "Iniciando proceso...";
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _executeDeletionSequence();
  }

  Future<void> _executeDeletionSequence() async {
    final prov = Provider.of<WorkbenchProvider>(widget.parentContext, listen: false);

    try {
      if (!widget.isDraft) {
        setState(() {
          _statusText = "Desvinculando protecciones...";
          _progress = 0.5;
        });
        // La rebajamos a DRAFT primero. Ya lo hace deleteQuotation en workbench, pero el progreso visual queda mejor
        await Future.delayed(const Duration(milliseconds: 600)); 
      }

      if (mounted) {
        setState(() {
          _statusText = "Eliminando de la base de datos...";
          _progress = 0.8;
        });
      }

      bool success = await prov.deleteQuotation(widget.quotationId);

      if (mounted) {
        setState(() {
          _statusText = success ? "¡Eliminada!" : "Operación denegada";
          _progress = 1.0;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500)); 

      if (mounted) {
        Navigator.pop(context); 
        if (success) {
          CustomSnackBar.show(widget.parentContext, message: "Lista eliminada exitosamente", isError: false);
        } else {
          CustomSnackBar.show(widget.parentContext, message: "El servidor bloqueó la eliminación.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.show(widget.parentContext, message: "Hubo un error de conexión durante el proceso.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 6,
                    backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(widget.isDark ? Colors.red[400]! : Colors.red),
                  ),
                ),
                Icon(Icons.delete_sweep, color: widget.isDark ? Colors.red[400] : Colors.red, size: 28),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _statusText,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}