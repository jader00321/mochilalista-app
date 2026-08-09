import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/team_provider.dart';
import '../../../../widgets/custom_snackbar.dart';

class AccessCodesTab extends StatelessWidget {
  const AccessCodesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final teamProv = Provider.of<TeamProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.qr_code, color: Colors.white),
              label: const Text("Generar Código de Invitación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showGenerateCodeModal(context),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await teamProv.fetchAccessCodes(auth.activeBusinessId!);
            },
            child: teamProv.accessCodes.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text("No hay códigos activos."))])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: teamProv.accessCodes.length,
                    itemBuilder: (context, index) {
                      final code = teamProv.accessCodes[index];
                      final isExhausted = code.isExhausted;

                      return Card(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            code.codigo,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isExhausted ? Colors.grey : Colors.green, letterSpacing: 1.5),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text("Rol: ${code.rolAOtorgar.replaceAll("_", " ").toUpperCase()}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                              Text("Usos: ${code.usosActuales} / ${code.usosMaximos}", style: TextStyle(color: isExhausted ? Colors.red : Colors.grey)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final ok = await teamProv.deleteAccessCode(auth.activeBusinessId!, code.id);
                              if (ok && context.mounted) {
                                CustomSnackBar.show(context, message: "Código eliminado", isError: false);
                              }
                            },
                          ),
                          onTap: () {
                             // Copiar al portapapeles
                             Clipboard.setData(ClipboardData(text: code.codigo));
                             CustomSnackBar.show(context, message: "Código copiado al portapapeles", isError: false);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // --- MODAL: GENERADOR DE CÓDIGOS ---
  void _showGenerateCodeModal(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final teamProv = Provider.of<TeamProvider>(context, listen: false);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    String selectedRole = "trabajador";
    int maxUses = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Generador de Códigos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(labelText: "Rol a otorgar", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: "trabajador", child: Text("Trabajador / Cajero")),
                    DropdownMenuItem(value: "cliente_comunidad", child: Text("Cliente de Comunidad (VIP)")),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Usos permitidos:", style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => maxUses = maxUses > 1 ? maxUses - 1 : 1)),
                        Text(maxUses == 1000 ? "Infinito" : maxUses.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => maxUses = maxUses == 10 ? 1000 : (maxUses == 1000 ? 1000 : maxUses + 1))),
                      ],
                    )
                  ],
                ),
                Text("Nota: Sube a 'Infinito' si es un código general para tus clientes.", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: teamProv.isLoading ? null : () async {
                      final newCode = await teamProv.generateAccessCode(auth.activeBusinessId!, selectedRole, maxUses, null);
                      if (newCode != null && ctx.mounted) {
                        Navigator.pop(ctx);
                        _showCodeSuccessDialog(context, newCode.codigo);
                      } else if (ctx.mounted) {
                        CustomSnackBar.show(context, message: teamProv.errorMessage, isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: teamProv.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Generar Código", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  void _showCodeSuccessDialog(BuildContext context, String codigo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¡Código Generado!", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Comparte este código con la persona que deseas invitar:"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 2)),
              child: Text(codigo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar")),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: const Text("Copiar", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              Navigator.pop(ctx);
              CustomSnackBar.show(context, message: "Código copiado al portapapeles", isError: false);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, color: Colors.white, size: 18),
            label: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse("https://wa.me/?text=¡Únete a mi equipo en MochilaLista! Tu código de acceso es: *$codigo*");
              try {
                 await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (_) {
                 if (context.mounted) CustomSnackBar.show(context, message: "No se pudo abrir WhatsApp", isError: true);
              }
            },
          )
        ],
      ),
    );
  }
}
