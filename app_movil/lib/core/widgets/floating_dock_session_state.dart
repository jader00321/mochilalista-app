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

/// 🫧 SecondaryBubbleSessionState - Estado en Memoria Compartida para Burbuja Secundaria (DeepNavReturnPill)
///
/// Mantiene la persistencia de coordenadas (X, Y), lado de anclaje (isLeftEdge),
/// modo oculto en borde (isEdgeTucked) y tarea seleccionada a través de todas las pantallas
/// secundarias (Inventario, Catálogo, Clientes, Historial, etc.).
/// Notifica reactivamente a todas las instancias en IndexedStack mediante listeners.
/// NUNCA comparte variables con FloatingDockSessionState para blindar el Home.
class SecondaryBubbleSessionState {
  static bool _isLeftEdge = false; // Por defecto a la derecha para no tapar contenido
  static bool _isEdgeTucked = false;
  static double? _panX;
  static double? _panBottom;
  static int _selectedTaskIndex = 0;

  static final List<void Function()> _listeners = [];

  static bool get isLeftEdge => _isLeftEdge;
  static set isLeftEdge(bool value) {
    if (_isLeftEdge != value) {
      _isLeftEdge = value;
      notifyListeners();
    }
  }

  static bool get isEdgeTucked => _isEdgeTucked;
  static set isEdgeTucked(bool value) {
    if (_isEdgeTucked != value) {
      _isEdgeTucked = value;
      notifyListeners();
    }
  }

  static double? get panX => _panX;
  static set panX(double? value) {
    if (_panX != value) {
      _panX = value;
      notifyListeners();
    }
  }

  static double? get panBottom => _panBottom;
  static set panBottom(double? value) {
    if (_panBottom != value) {
      _panBottom = value;
      notifyListeners();
    }
  }

  static int get selectedTaskIndex => _selectedTaskIndex;
  static set selectedTaskIndex(int value) {
    if (_selectedTaskIndex != value) {
      _selectedTaskIndex = value;
      notifyListeners();
    }
  }

  /// Actualiza múltiples propiedades de manera atómica con una sola notificación
  static void updatePosition({
    required bool isLeftEdge,
    required bool isEdgeTucked,
    double? panX,
    double? panBottom,
    int? selectedTaskIndex,
    bool notify = true,
  }) {
    _isLeftEdge = isLeftEdge;
    _isEdgeTucked = isEdgeTucked;
    _panX = panX;
    _panBottom = panBottom;
    if (selectedTaskIndex != null) {
      _selectedTaskIndex = selectedTaskIndex;
    }
    if (notify) {
      notifyListeners();
    }
  }

  static void addListener(void Function() listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  static void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  static void notifyListeners() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Resetea a la configuración inicial limpia
  static void reset() {
    _isLeftEdge = false;
    _isEdgeTucked = false;
    _panX = null;
    _panBottom = null;
    _selectedTaskIndex = 0;
    notifyListeners();
  }
}

