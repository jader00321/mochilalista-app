part of '../onboarding_screen.dart';

mixin _OnboardingCategoriesMixin on _OnboardingStateBase {
  @override
  Future<void> _showInitialCategoriesDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    if (auth.activeBusinessId != null) {
      inventory.updateContext(auth.activeBusinessId);
    }

    final Set<int> selectedIndices = {0, 1, 2, 3};
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_rounded, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tu negocio está listo",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Categorías sugeridas",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Elige las categorías con las que deseas comenzar para tener tu catálogo organizado:",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _initialSuggestedCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final cat = _initialSuggestedCategories[index];
                            final isSelected = selectedIndices.contains(index);

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          selectedIndices.remove(index);
                                        } else {
                                          selectedIndices.add(index);
                                        }
                                      });
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.blue.withValues(alpha: 0.15) : const Color(0xFFEBF3FF))
                                      : (isDark ? const Color(0xFF1B1B26) : Colors.grey[50]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.2)
                                            : (isDark ? Colors.white10 : Colors.grey[200]),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        cat.icon,
                                        size: 18,
                                        color: isSelected
                                            ? Colors.blue
                                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            cat.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      color: isSelected ? Colors.blue : (isDark ? Colors.grey[600] : Colors.grey[400]),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        child: Text(
                          "Omitir por ahora",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (selectedIndices.isEmpty) {
                                  Navigator.pop(dialogCtx);
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                int createdCount = 0;
                                for (final idx in selectedIndices) {
                                  final cat = _initialSuggestedCategories[idx];
                                  final res = await inventory.createCategory(
                                    cat.name,
                                    descripcion: cat.description,
                                  );
                                  if (res != null) createdCount++;
                                }
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                if (context.mounted && createdCount > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Se crearon $createdCount categorías iniciales con éxito.'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          selectedIndices.isEmpty
                              ? "Continuar"
                              : "Guardar (${selectedIndices.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CircularLogoPicker extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onChanged;

  const _CircularLogoPicker({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 75);
      if (image != null) {
        controller.text = image.path;
        onChanged();
      }
    } catch (e) {
      debugPrint("Error seleccionando logo: $e");
    }
  }

  void _showModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
        return SafeArea(
          top: false,
          bottom: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(top: 16, bottom: effectiveBottom + 12),
              child: Wrap(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.photo_library, color: Colors.blue),
                    ),
                    title: Text('Galería', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    onTap: () {
                      Navigator.pop(context);
                      _pick(context, ImageSource.gallery);
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.orange),
                    ),
                    title: Text('Cámara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    onTap: () {
                      Navigator.pop(context);
                      _pick(context, ImageSource.camera);
                    },
                  ),
                  if (controller.text.isNotEmpty && controller.text != 'null') ...[
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      title: const Text('Eliminar logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        controller.text = '';
                        onChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = controller.text.isNotEmpty && controller.text != 'null';
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showModal(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1B1B26) : Colors.grey[100],
                    border: Border.all(
                      color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasLogo
                        ? UniversalImage(path: controller.text)
                        : Icon(
                            Icons.storefront_rounded,
                            size: 46,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E88E5) : const Color(0xFF1565C0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasLogo ? "Toca para cambiar el logo" : "Logo del Negocio (Opcional)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted += ' ';
      }
      formatted += digits[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _InitialCategorySuggestion {
  final IconData icon;
  final String name;
  final String description;
  const _InitialCategorySuggestion(this.icon, this.name, this.description);
}

const List<_InitialCategorySuggestion> _initialSuggestedCategories = [
  _InitialCategorySuggestion(Icons.shopping_bag_outlined, 'Abarrotes', 'Arroz, azúcar, fideos, aceites y menestras'),
  _InitialCategorySuggestion(Icons.local_drink_outlined, 'Bebidas', 'Gaseosas, aguas, jugos e hidratantes'),
  _InitialCategorySuggestion(Icons.cookie_outlined, 'Golosinas', 'Galletas, chocolates, caramelos y snacks'),
  _InitialCategorySuggestion(Icons.cleaning_services_outlined, 'Limpieza', 'Detergentes, lejías, jabones y desinfectantes'),
  _InitialCategorySuggestion(Icons.breakfast_dining_outlined, 'Lácteos', 'Leches, yogures, quesos y mantequillas'),
  _InitialCategorySuggestion(Icons.spa_outlined, 'Cuidado Personal', 'Shampoos, desodorantes y cremas'),
  _InitialCategorySuggestion(Icons.edit_note_rounded, 'Útiles Escolares', 'Cuadernos, lápices, lapiceros y borradores'),
  _InitialCategorySuggestion(Icons.inventory_2_outlined, 'Conservas', 'Atunes y conservas de verduras'),
  _InitialCategorySuggestion(Icons.bakery_dining_outlined, 'Panadería', 'Panes, tostadas y queques'),
];
