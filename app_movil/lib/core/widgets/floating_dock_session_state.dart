/// 🌟 FloatingDockSessionState - Estado en Memoria Compartida para Globo Flotante
///
/// Mantiene la persistencia de coordenadas (X, Y), lado de anclaje (isLeftEdge)
/// y modo oculto en borde (isEdgeTucked) durante la navegación entre pantallas.
/// Evita que el dock o la píldora de retorno vuelvan arbitrariamente a tapar
/// áreas críticas (como el Dashboard Financiero en ProductDetailScreen).
class FloatingDockSessionState {
  static bool isLeftEdge = false; // Por defecto a la derecha para no tapar contenido izquierdo
  static bool isEdgeTucked = false;
  static double? panX;
  static double? panBottom;
  static bool isBubble = false;
  static int selectedTaskIndex = 0;

  /// Resetea a la configuración de fábrica si es necesario
  static void reset() {
    isLeftEdge = false;
    isEdgeTucked = false;
    panX = null;
    panBottom = null;
    isBubble = false;
    selectedTaskIndex = 0;
  }
}
