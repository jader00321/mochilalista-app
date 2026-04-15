import 'package:flutter/material.dart';
import '../../../../widgets/universal_image.dart';

class QuoteEvidencePanel extends StatelessWidget {
  final bool hasImage;
  final bool hasText;
  final String? imageUrl;
  final bool isDark; // Adaptable
  final VoidCallback onImageTap;
  final VoidCallback onDownloadTap;
  final VoidCallback onTextEvidenceTap;

  const QuoteEvidencePanel({
    super.key,
    required this.hasImage,
    required this.hasText,
    this.imageUrl,
    required this.isDark,
    required this.onImageTap,
    required this.onDownloadTap,
    required this.onTextEvidenceTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(color: surfaceColor, border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: isDark ? Colors.purple[300] : Colors.purple,
          collapsedIconColor: isDark ? Colors.purple[300] : Colors.purple,
          title: Text("Evidencia de Origen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          leading: Icon(Icons.folder_open, color: isDark ? Colors.purple[300] : Colors.purple, size: 28),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage && imageUrl != null)
                  InkWell(
                    onTap: onImageTap,
                    child: Column(
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: UniversalImage(path: imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text("Ver Imagen", style: TextStyle(fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold))
                      ],
                    ),
                  )
                else
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_not_supported, color: isDark ? Colors.grey[600] : Colors.grey, size: 28), const SizedBox(height: 6), Text("Sin Img", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey))]),
                  ),
                
                const SizedBox(width: 20),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Lista procesada por IA:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      const SizedBox(height: 8),
                      if (hasText) ...[
                        OutlinedButton.icon(
                            onPressed: onTextEvidenceTap,
                            icon: const Icon(Icons.description, size: 20),
                            label: const Text("Ver Texto Original", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.purple[300] : Colors.purple, side: BorderSide(color: isDark ? Colors.purple.withOpacity(0.5) : Colors.purple.shade200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        ),
                        const SizedBox(height: 8),
                        Text("Toca para comparar lo que leyó la IA.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
                      ] else
                         Text("No hay texto original disponible.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                      
                      if (hasImage) ...[
                         const SizedBox(height: 16),
                         InkWell(
                           onTap: onDownloadTap, 
                           child: Row(children: [Icon(Icons.download, size: 18, color: isDark ? Colors.blue[300] : Colors.blue), const SizedBox(width: 6), Text("Guardar foto en galería", style: TextStyle(fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold))]),
                         )
                      ]
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}