import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          // 🔥 Verde brillante en modo oscuro para resaltar, Verde corporativo en claro
          backgroundColor: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isDark ? 0 : 3, // Sin sombra en modo oscuro para un look más limpio
        ),
        child: isLoading
            ? const SizedBox(
                height: 24, width: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
              )
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}