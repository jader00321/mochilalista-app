import 'package:flutter/material.dart';

class SuperSwitch extends StatelessWidget {
  final int current;
  final Function(int) onChanged;
  final bool isDark;

  const SuperSwitch({
    super.key,
    required this.current,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Estado actual: Variado (Seleccione uno para unificar)", 
              style: TextStyle(fontSize: 12, color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic)
            ),
          ),
        Container(
          height: 42,
          decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: current == 0 ? Alignment.centerLeft : (current == 2 ? Alignment.centerRight : Alignment.center),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: current == 1 
                    ? const SizedBox.shrink() 
                    : FractionallySizedBox(
                        widthFactor: 0.5, 
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: current == 0 ? (isDark ? Colors.orange[800] : Colors.white) : (isDark ? Colors.green[700] : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque, 
                      onTap: () => onChanged(0), 
                      child: Center(child: Text("Ocultar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 0 ? (isDark ? Colors.white : Colors.orange[800]) : Colors.grey)))
                    )
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque, 
                      onTap: () => onChanged(2), 
                      child: Center(child: Text("Publicar Todos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: current == 2 ? (isDark ? Colors.white : Colors.green[700]) : Colors.grey)))
                    )
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
