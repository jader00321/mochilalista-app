part of '../profile_screen.dart';

mixin _ProfilePhotoAndEditModalsMixin on _ProfileStateBase {
  @override
  void _showPhotoOptions(
    BuildContext context,
    AuthProvider auth,
    String? validLogoPath,
  ) {
    if (auth.isLoading) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return Container(
          margin: EdgeInsets.fromLTRB(16, 16, 16, effectiveBottom + 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 15),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (validLogoPath != null &&
                      !validLogoPath.startsWith('http'))
                    _buildModalOption(
                      icon: Icons.fullscreen,
                      text: "Ver foto en pantalla completa",
                      color: Colors.blue,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openFullScreenImage(validLogoPath);
                      },
                    ),

                  _buildModalOption(
                    icon: Icons.camera_alt,
                    text: "Tomar foto con la cámara",
                    color: Colors.blue,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(context, auth, source: ImageSource.camera);
                    },
                  ),

                  _buildModalOption(
                    icon: Icons.image_search,
                    text: "Elegir foto de la galería",
                    color: Colors.green,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(context, auth, source: ImageSource.gallery);
                    },
                  ),

                  if (validLogoPath != null)
                    _buildModalOption(
                      icon: Icons.delete_outline,
                      text: "Eliminar foto actual",
                      color: Colors.red,
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final biz = auth.currentBusiness!;
                        bool success = await auth.updateBusinessProfile(
                          biz.commercialName,
                          biz.ruc ?? "",
                          biz.address ?? "",
                          biz.paymentInfo ?? "",
                          biz.latitud,
                          biz.longitud,
                          true,
                          true,
                          clearLogo: true,
                        );
                        if (context.mounted) {
                          if (success) {
                            _markProfileMutated();
                            CustomSnackBar.show(
                              context,
                              message: "La foto ha sido eliminada.",
                              isError: false,
                            );
                          } else {
                            CustomSnackBar.show(
                              context,
                              message: auth.errorMessage,
                              isError: true,
                            );
                          }
                        }
                      },
                    ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? Colors.red
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      onTap: onTap,
    );
  }

  void _openFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: PhotoView(
              imageProvider: FileImage(File(imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  String _captureProfileFingerprint(AuthProvider auth) {
    final biz = auth.currentBusiness;
    return '${auth.userName}|${auth.user?.phone ?? ''}|${auth.user?.email ?? ''}|'
        '${auth.businessName}|${biz?.ruc ?? ''}|${biz?.address ?? ''}|'
        '${biz?.logoUrl ?? ''}|${biz?.paymentInfo ?? ''}|${biz?.moneda ?? ''}|'
        '${biz?.latitud ?? ''}|${biz?.longitud ?? ''}|${auth.hasPinCache}|${auth.isPinReminderSnoozed}';
  }

  Future<void> _pickImage(
    BuildContext context,
    AuthProvider auth, {
    ImageSource source = ImageSource.gallery,
  }) async {
    if (auth.isLoading) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        bool success = await auth.uploadBusinessLogo(File(image.path));
        if (context.mounted) {
          if (success) {
            _markProfileMutated();
            CustomSnackBar.show(
              context,
              message: "Foto guardada exitosamente",
              isError: false,
            );
          } else {
            CustomSnackBar.show(
              context,
              message: auth.errorMessage,
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(
          context,
          message: source == ImageSource.camera
              ? "Error al abrir la cámara"
              : "Error al abrir la galería",
          isError: true,
        );
      }
    }
  }

  @override
  Future<void> _showEditProfile(
    BuildContext context, {
    String? initialFocusField,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileModal(initialFocusField: initialFocusField),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

  @override
  Future<void> _showEditBusiness(
    BuildContext context, {
    String? initialFocusField,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditBusinessModal(initialFocusField: initialFocusField),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

  @override
  Future<void> _showChangePassword(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final before = _captureProfileFingerprint(auth);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ChangePasswordModal(),
    );
    if (context.mounted) {
      await auth.refreshActiveUser();
      if (_captureProfileFingerprint(auth) != before) {
        _markProfileMutated();
      }
    }
  }

}
