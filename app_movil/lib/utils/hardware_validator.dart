import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class HardwareValidator {
  
  // ==========================================
  // 1. VALIDACIÓN DE INTERNET ESTABLE
  // ==========================================
  static Future<bool> checkInternet(BuildContext context, {VoidCallback? onNavigateToManual}) async {
    // 1. Validar hardware (WiFi/Datos encendidos)
    // 🔥 CORRECCIÓN: Adaptado a la versión actual de tu paquete (retorna un solo ConnectivityResult)
    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    
    if (connectivityResult == ConnectivityResult.none) {
      if (context.mounted) {
        _showPremiumAnimatedModal(
          context: context,
          title: 'Sin Conexión a Internet',
          message: 'Esta función requiere conexión a Internet para procesar datos en la nube. Por favor, activa tu WiFi o Datos Móviles.',
          icon: Icons.wifi_off_rounded,
          iconColor: Colors.redAccent,
          onNavigateToManual: onNavigateToManual,
        );
      }
      return false;
    }

    // 2. Hacer Ping HTTP real para validar estabilidad
    try {
      final response = await http.get(Uri.parse('https://clients3.google.com/generate_204'))
                                 .timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 204) {
        return true; 
      }
    } catch (_) {
      if (context.mounted) {
        _showPremiumAnimatedModal(
          context: context,
          title: 'Señal Inestable',
          message: 'Tu conexión a Internet es muy lenta o inestable en este momento. La operación podría fallar.',
          icon: Icons.signal_cellular_connected_no_internet_0_bar_rounded,
          iconColor: Colors.orange,
          onNavigateToManual: onNavigateToManual,
        );
      }
      return false;
    }
    return false;
  }

  // ==========================================
  // 2. VALIDACIÓN DE GPS (UBICACIÓN)
  // ==========================================
  static Future<bool> checkGPS(BuildContext context) async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      if (context.mounted) {
        _showPremiumAnimatedModal(
          context: context,
          title: 'Ubicación Desactivada',
          message: 'Para registrar la ubicación exacta de tu negocio en el mapa, por favor enciende el GPS de tu celular.',
          icon: Icons.location_off_rounded,
          iconColor: Colors.orange,
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          _showPremiumAnimatedModal(
            context: context,
            title: 'Permiso Denegado',
            message: 'Mochila Lista necesita acceso a tu ubicación para poder configurar tu tienda en el mapa.',
            icon: Icons.not_listed_location_rounded,
            iconColor: Colors.redAccent,
          );
        }
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showPremiumAnimatedModal(
          context: context,
          title: 'Permisos Bloqueados',
          message: 'Has bloqueado permanentemente el acceso a la ubicación. Ve a la Configuración de tu Android, busca la app y permite el acceso al GPS.',
          icon: Icons.settings_rounded,
          iconColor: Colors.grey,
        );
      }
      return false;
    }

    return true; 
  }

  // ==========================================
  // 3. DISEÑO DEL MODAL PREMIUM ANIMADO
  // ==========================================
  static void _showPremiumAnimatedModal({
    required BuildContext context, 
    required String title, 
    required String message, 
    required IconData icon,
    required Color iconColor,
    VoidCallback? onNavigateToManual,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Animación de rebote (Bounce)
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono Superior Destacado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 40),
                  ),
                  const SizedBox(height: 20),
                  
                  // Título
                  Text(
                    title, 
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 22, 
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5
                    )
                  ),
                  const SizedBox(height: 12),
                  
                  // Mensaje
                  Text(
                    message, 
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15, 
                      height: 1.5, 
                      color: isDark ? Colors.grey[400] : Colors.grey[700]
                    )
                  ),
                  const SizedBox(height: 28),
                  
                  // Botones Dinámicos
                  if (onNavigateToManual != null) ...[
                    // Si viene del escáner IA, muestra la opción de ir a manual
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); 
                          onNavigateToManual(); 
                        },
                        child: const Text('Ir a Cotización Manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ] else ...[
                    // Si es una validación general (GPS), solo muestra un botón de Entendido
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}