import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';        
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isLoadingLoc = false;
  bool _isGpsAvailable = true;
  
  late AnimationController _markerAnimController;
  late Animation<double> _markerAnimation;

  @override
  void initState() {
    super.initState();
    _markerAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _markerAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _markerAnimController, curve: Curves.easeInOut));
    
    _checkGpsStatus();
    if (widget.initialLat == null || widget.initialLng == null) {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _markerAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkGpsStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    setState(() { _isGpsAvailable = serviceEnabled; });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLoc = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      setState(() { _isGpsAvailable = serviceEnabled; });
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
    } catch (e) {
      debugPrint("Error GPS: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLoc = false);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(1.0, 18.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(1.0, 18.0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPanelHeight = MediaQuery.of(context).padding.bottom + 150;

    final filter = isDark 
      ? const ColorFilter.matrix([
          -1,  0,  0, 0, 255, 
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1, 0,
        ])
      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: (widget.initialLat != null && widget.initialLng != null) 
                  ? LatLng(widget.initialLat!, widget.initialLng!) 
                  : const LatLng(-12.046374, -77.042793),
              initialZoom: 16.0,
            ),
            children: [
              ColorFiltered(
                colorFilter: filter,
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_movil',
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 40), 
            child: ScaleTransition(
              scale: _markerAnimation,
              child: const Icon(Icons.location_on, size: 55, color: Colors.redAccent),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: "btn_back",
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              elevation: 4,
              child: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          if (!_isGpsAvailable)
            Positioned(
              top: MediaQuery.of(context).padding.top + 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("GPS Apagado", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: bottomPanelHeight + 16, 
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "btn_zoom_in",
                  backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
                  onPressed: _zoomIn,
                  child: Icon(Icons.add, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "btn_zoom_out",
                  backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
                  onPressed: _zoomOut,
                  child: Icon(Icons.remove, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btn_gps",
                  backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
                  onPressed: _getCurrentLocation,
                  child: _isLoadingLoc 
                    ? const CircularProgressIndicator(strokeWidth: 3) 
                    : Icon(Icons.my_location, color: _isGpsAvailable ? Colors.blue : Colors.grey, size: 28),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, -5))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Mueve el mapa para ubicar tu negocio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Text("Arrastra para ajustar la posición exacta", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, _mapController.camera.center);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0
                      ),
                      child: const Text("GUARDAR ESTA UBICACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}