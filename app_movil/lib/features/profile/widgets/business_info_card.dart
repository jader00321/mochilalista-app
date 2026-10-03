import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';        
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/utils/hardware_validator.dart'; // 🔥 IMPORT DE SEGURIDAD

class BusinessInfoCard extends StatefulWidget {
  final BusinessModel? business;
  final bool isCommunityClient; 

  const BusinessInfoCard({super.key, this.business, this.isCommunityClient = false});

  @override
  State<BusinessInfoCard> createState() => _BusinessInfoCardState();
}

class _BusinessInfoCardState extends State<BusinessInfoCard> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    // 🔥 VALIDACIÓN DE INTERNET ANTES DE SALIR A MAPS
    bool hasInternet = await HardwareValidator.checkInternet(context);
    if (!hasInternet) return;

    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("No se pudo abrir el mapa");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; 

    if (widget.business == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50], 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3))
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

    bool showAddress = true;
    bool showRuc = true;
    if (widget.business!.printerConfig != null && widget.business!.printerConfig!.isNotEmpty) {
      try {
        final Map<String, dynamic> prefs = json.decode(widget.business!.printerConfig!);
        showAddress = prefs['show_address'] ?? true;
        showRuc = prefs['show_ruc'] ?? true;
      } catch (_) {}
    }

    final bool canSeeAddress = !widget.isCommunityClient || showAddress;
    final bool canSeeRuc = !widget.isCommunityClient || showRuc;
    final hasMap = canSeeAddress && widget.business!.latitud != null && widget.business!.longitud != null;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias, 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [Colors.blue[900]!.withValues(alpha: 0.8), Colors.blue[800]!.withValues(alpha: 0.5)] : [Colors.blue[800]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.business!.commercialName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                if (canSeeRuc)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text("RUC: ${widget.business!.ruc ?? '---'}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          
          if (hasMap)
            RepaintBoundary(
              child: SizedBox(
                key: ValueKey('${widget.business!.latitud}_${widget.business!.longitud}'), 
                height: 180,
                width: double.infinity,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(widget.business!.latitud!, widget.business!.longitud!),
                        initialZoom: 16.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), 
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: isDark 
                            ? const ColorFilter.matrix([
                                -1,  0,  0, 0, 255, 
                                 0, -1,  0, 0, 255,
                                 0,  0, -1, 0, 255,
                                 0,  0,  0, 1, 0,
                              ])
                            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app_movil',
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(widget.business!.latitud!, widget.business!.longitud!),
                              width: 40, height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            )
                          ],
                        )
                      ],
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                        foregroundColor: Colors.white,
                        onPressed: () => _openGoogleMaps(context, widget.business!.latitud!, widget.business!.longitud!),
                        child: const Icon(Icons.map_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canSeeAddress)
                   _buildRow(Icons.location_on, widget.business!.address ?? "Referencia no registrada", isDark ? Colors.white : Colors.black87)
                else
                   _buildRow(Icons.location_off, "Dirección Privada", isDark ? Colors.grey[500]! : Colors.grey),
                
                if (!hasMap && canSeeAddress) ...[
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
                _buildRow(Icons.verified_user, widget.isCommunityClient ? "Tienda Verificada" : "Cuenta Verificada", isDark ? Colors.white : Colors.black87),
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