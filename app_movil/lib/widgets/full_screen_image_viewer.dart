import 'package:flutter/material.dart';
import '../../../widgets/universal_image.dart'; 

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key, 
    required this.imageUrl, 
    required this.tag
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: true,
              clipBehavior: Clip.none,
              child: UniversalImage(
                path: imageUrl,
                fit: BoxFit.contain, 
              ),
            ),
          ),
        ),
      ),
    );
  }
}