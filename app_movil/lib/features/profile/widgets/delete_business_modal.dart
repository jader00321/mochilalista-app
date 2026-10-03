import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

class DeleteBusinessModal extends StatefulWidget {
  final int userId;
  final bool hasPin;

  const DeleteBusinessModal({
    super.key,
    required this.userId,
    required this.hasPin,
  });

  @override
  State<DeleteBusinessModal> createState() => _DeleteBusinessModalState();
}

class _DeleteBusinessModalState extends State<DeleteBusinessModal> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isDeleting = false;
  String _progressText = "";
  double _progressValue = 0.0;
  String _errorMessage = "";
  bool _isButtonEnabled = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_validateInput);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _validateInput() {
    final text = _textController.text;
    bool isValid = false;
    if (widget.hasPin) {
      isValid = text.length >= 4;
    } else {
      isValid = text.trim().toUpperCase() == 'ELIMINAR';
    }
    
    if (_isButtonEnabled != isValid) {
      setState(() => _isButtonEnabled = isValid);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _performDeletion() async {
    FocusScope.of(context).unfocus(); // Ocultar teclado inmediatamente
    
    setState(() {
      _isDeleting = true;
      _errorMessage = "";
      _progressText = "Iniciando limpieza...";
      _progressValue = 0.1;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await auth.deleteProfileAndDataWithProgress(
      widget.userId, 
      widget.hasPin ? _textController.text : null,
      (text, value) {
        if (mounted) {
          setState(() {
            _progressText = text;
            _progressValue = value;
          });
        }
      }
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isDeleting = false;
          _errorMessage = auth.errorMessage.isNotEmpty ? auth.errorMessage : "Ocurrió un error al eliminar.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: (scale - 0.8) * 5, // Fade in
            child: child,
          ),
        );
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        elevation: 10,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "¿Eliminar Definitivamente?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Esta acción borrará permanentemente todos los productos, ventas, clientes e historial de este negocio. No hay vuelta atrás.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(sizeFactor: animation, child: child),
                  ),
                  child: _isDeleting ? _buildProgressState(isDark) : _buildInputState(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputState(bool isDark) {
    return Column(
      key: const ValueKey("inputState"),
      children: [
        if (widget.hasPin)
          TextField(
            controller: _textController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: "Ingresa tu PIN",
              hintStyle: const TextStyle(letterSpacing: 0, fontWeight: FontWeight.normal),
              counterText: "",
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        else
          TextField(
            controller: _textController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: "Escribe ELIMINAR",
              hintStyle: const TextStyle(letterSpacing: 0, fontWeight: FontWeight.normal),
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  "Cancelar",
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isButtonEnabled ? _performDeletion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                  disabledForegroundColor: isDark ? Colors.white30 : Colors.grey[500],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Sí, Eliminar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressState(bool isDark) {
    return Padding(
      key: const ValueKey("progressState"),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: Tween<double>(
              begin: 0.0,
              end: _progressValue.clamp(0.0, 1.0),
            ),
            builder: (context, value, _) {
              return Stack(
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * 0.6 * value, // Aprox width
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.deepOrangeAccent],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _progressText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
