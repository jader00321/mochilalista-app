import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';        
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';

class BusinessInfoCard extends StatelessWidget {
  final BusinessModel? business;
  final bool isCommunityClient; 

  const BusinessInfoCard({super.key, this.business, this.isCommunityClient = false});

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("No se pudo abrir el mapa");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark; 

    if (business == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50], 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.blue.withOpacity(0.3))
        ),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, color: Colors.blue[400], size: 48),
            const SizedBox(height: 12),
            Text(
              "Aún no tienes un negocio registrado", 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const SizedBox(height: 8),
            Text(
              "Registra tu negocio para habilitar las cotizaciones, inventario y la mesa de trabajo.", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)
            ),
          ],
        ),
      );
    }

    // 🔥 DECODIFICAR PREFERENCIAS DE PRIVACIDAD
    bool showAddress = true;
    bool showRuc = true;
    if (business!.printerConfig != null && business!.printerConfig!.isNotEmpty) {
      try {
        final Map<String, dynamic> prefs = json.decode(business!.printerConfig!);
        showAddress = prefs['show_address'] ?? true;
        showRuc = prefs['show_ruc'] ?? true;
      } catch (_) {}
    }

    // Si es el dueño, él SIEMPRE ve todo. Solo ocultamos si es Cliente.
    final bool canSeeAddress = !isCommunityClient || showAddress;
    final bool canSeeRuc = !isCommunityClient || showRuc;
    final hasMap = canSeeAddress && business!.latitud != null && business!.longitud != null;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias, 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: isDark ? Colors.blue[900]?.withOpacity(0.5) : Colors.blue[900]),
            child: Row(
              children: [
                const Icon(Icons.storefront, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(business!.commercialName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                if (canSeeRuc)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text("RUC: ${business!.ruc ?? '---'}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          
          if (hasMap)
            SizedBox(
              key: ValueKey('${business!.latitud}_${business!.longitud}'), 
              height: 180,
              width: double.infinity,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(business!.latitud!, business!.longitud!),
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), 
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app_movil',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(business!.latitud!, business!.longitud!),
                        width: 40, height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      )
                    ],
                  )
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canSeeAddress)
                   _buildRow(Icons.location_on, business!.address ?? "Referencia no registrada", isDark ? Colors.white : Colors.black87)
                else
                   _buildRow(Icons.location_off, "Dirección Privada", isDark ? Colors.grey[500]! : Colors.grey),
                
                if (hasMap) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => _openGoogleMaps(business!.latitud!, business!.longitud!),
                    child: Row(
                      children: [
                        Icon(Icons.map, size: 20, color: Colors.blue[400]), 
                        const SizedBox(width: 12),
                        Text("Abrir App de Navegación", style: TextStyle(color: Colors.blue[400], fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ],
                    ),
                  )
                ] else if (canSeeAddress) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.location_off, size: 20, color: Colors.grey[500]),
                      const SizedBox(width: 12),
                      Text("Ubicación en mapa no registrada", style: TextStyle(color: Colors.grey[500], fontSize: 15, fontStyle: FontStyle.italic)),
                    ],
                  )
                ],
                const Divider(height: 24),
                _buildRow(Icons.verified_user, isCommunityClient ? "Tienda Verificada" : "Cuenta Verificada", isDark ? Colors.white : Colors.black87),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 15))),
      ],
    );
  }
}