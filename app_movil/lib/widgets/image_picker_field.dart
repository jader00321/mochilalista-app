import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'universal_image.dart'; 

class ImagePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;

  const ImagePickerField({
    super.key, 
    required this.controller, 
    required this.label,
    required this.isDark,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      
      if (image != null) {
        setState(() {
          widget.controller.text = image.path; 
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.blue)),
                title: Text('Galería', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDark ? Colors.white : Colors.black87)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              const Divider(height: 1, indent: 60),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.orange)),
                title: Text('Cámara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDark ? Colors.white : Colors.black87)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String path = widget.controller.text;
    final bool hasImage = path.isNotEmpty && path != 'null';
    
    final bool isLocalPending = hasImage && !path.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.isDark ? Colors.grey[400] : Colors.grey[700])
        ),
        const SizedBox(height: 8),
        
        InkWell(
          onTap: () => _showOptions(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      UniversalImage(path: path),
                      
                      if (isLocalPending)
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Se subirá al guardar", 
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ),
                        ),

                      Positioned(
                        top: 10, right: 10,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                            onPressed: () => _showOptions(context),
                          ),
                        ),
                      )
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 48, color: widget.isDark ? Colors.white24 : Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          "Tocar para agregar imagen", 
                          style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)
                        )
                      ],
                    ),
                  ),
          ),
        ),
        
        if (hasImage)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => widget.controller.clear()),
              icon: Icon(Icons.delete_outline, size: 18, color: widget.isDark ? Colors.red[300] : Colors.red),
              label: Text("Quitar imagen", style: TextStyle(color: widget.isDark ? Colors.red[300] : Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(top: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          )
      ],
    );
  }
}