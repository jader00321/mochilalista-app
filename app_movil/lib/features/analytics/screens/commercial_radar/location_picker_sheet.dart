import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'location_picker_district_step.dart';

/// Selector geográfico interactivo con buscador en tiempo real y catálogo oficial del Perú
class LocationPickerSheet extends StatefulWidget {
  final bool isDark;
  final Color sheetBg;
  final RadarLocation currentLocation;
  final ValueChanged<RadarLocation> onLocationSelected;

  final ProvinceInfo? initialStagedProvince;
  final DepartmentInfo? initialStagedDepartment;

  const LocationPickerSheet({
    super.key,
    required this.isDark,
    required this.sheetBg,
    required this.currentLocation,
    required this.onLocationSelected,
    this.initialStagedProvince,
    this.initialStagedDepartment,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

abstract class _LocationPickerSheetStateBase
    extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  String _filter = '';

  DepartmentInfo? _stagedDept;
  ProvinceInfo? _stagedProv;

  @override
  void initState() {
    super.initState();
    _stagedProv = widget.initialStagedProvince;
    _stagedDept = widget.initialStagedDepartment;
    if (_stagedProv != null &&
        widget.currentLocation.province == _stagedProv!.name) {
      _districtController.text = widget.currentLocation.district ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _districtController.dispose();
    super.dispose();
  }
}

class _LocationPickerSheetState extends _LocationPickerSheetStateBase
    with _LocationPickerDistrictStepMixin {
  static const List<RadarLocation> _quickLocations = [
    RadarLocation(
      department: 'Todo el Perú',
      province: 'Nacional',
      corridor: 'Red Vial Nacional',
    ),
    RadarLocation(
      department: 'Lima',
      province: 'Lima',
      corridor: 'Panamericana / Eje Central',
    ),
    RadarLocation(
      department: 'La Libertad',
      province: 'Trujillo',
      corridor: 'Panamericana Norte',
    ),
    RadarLocation(
      department: 'Arequipa',
      province: 'Arequipa',
      corridor: 'Panamericana Sur',
    ),
    RadarLocation(
      department: 'Lambayeque',
      province: 'Chiclayo',
      corridor: 'Panamericana Norte',
    ),
    RadarLocation(
      department: 'Piura',
      province: 'Talara',
      corridor: 'Panamericana Norte',
    ),
    RadarLocation(
      department: 'Cusco',
      province: 'Cusco',
      corridor: 'Corredor Sur / Eje Andino',
    ),
    RadarLocation(
      department: 'Junín',
      province: 'Huancayo',
      corridor: 'Carretera Central',
    ),
    RadarLocation(
      department: 'Loreto',
      province: 'Maynas',
      corridor: 'Eje Fluvial Amazónico',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    if (_stagedProv != null && _stagedDept != null) {
      return _buildDistrictPrecisionView(
        isDark,
        primaryTextColor,
        secondaryTextColor,
      );
    }

    return _buildProvinceSelectionView(
      isDark,
      primaryTextColor,
      secondaryTextColor,
    );
  }

  Widget _buildProvinceSelectionView(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final query = _filter.trim().toLowerCase();
    final List<DepartmentInfo> filteredDepts;
    if (query.isEmpty) {
      filteredDepts = PeruUbigeoCatalog.departments;
    } else {
      filteredDepts = PeruUbigeoCatalog.departments.where((d) {
        final matchDept = d.name.toLowerCase().contains(query);
        final matchProv = d.provinces.any(
          (p) => p.name.toLowerCase().contains(query),
        );
        return matchDept || matchProv;
      }).toList();
    }

    return InteractiveSheetWrapper(
      backgroundColor: widget.sheetBg,
      maxHeightFactor: 0.90,
      applyEffectiveBottomPadding: true,
      showHandle: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enfoque Geográfico del Radar",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        "Sintoniza noticias, rutas y fletes de tu provincia o región",
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Buscador en tiempo real
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _filter = val;
                });
              },
              style: TextStyle(fontSize: 13.5, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: "Buscar departamento, provincia o ciudad...",
                hintStyle: TextStyle(fontSize: 12.5, color: secondaryTextColor),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _filter = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Accesos Rápidos
            if (_filter.isEmpty) ...[
              Text(
                "Accesos Rápidos",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _quickLocations.map((loc) {
                    final isSelected = loc == widget.currentLocation;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: Icon(
                          loc.isNational ? Icons.public : Icons.location_on,
                          size: 14,
                          color: isSelected ? Colors.white : Colors.blueAccent,
                        ),
                        label: Text(loc.displayName),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : primaryTextColor,
                        ),
                        backgroundColor: isSelected
                            ? Colors.blueAccent
                            : (isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () => widget.onLocationSelected(loc),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
            ],

            // Lista desplegable jerárquica
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: InteractiveSheetWrapper.kModalScrollBottomClearance,
                ),
                itemCount: filteredDepts.length,
                itemBuilder: (context, index) {
                  final dept = filteredDepts[index];
                  final List<ProvinceInfo> provincesToShow;
                  if (query.isEmpty) {
                    provincesToShow = dept.provinces;
                  } else {
                    provincesToShow = dept.provinces
                        .where(
                          (p) =>
                              p.name.toLowerCase().contains(query) ||
                              dept.name.toLowerCase().contains(query),
                        )
                        .toList();
                  }

                  return Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: PageStorageKey<String>('dept_${dept.name}'),
                      initiallyExpanded: query.isNotEmpty,
                      leading: Icon(
                        Icons.map_rounded,
                        size: 20,
                        color: widget.currentLocation.department == dept.name
                            ? Colors.blueAccent
                            : Colors.grey,
                      ),
                      title: Text(
                        dept.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.currentLocation.department == dept.name
                              ? Colors.blueAccent
                              : primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        dept.mainCorridor,
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: provincesToShow.map((prov) {
                        final isProvSelected =
                            widget.currentLocation.department == dept.name &&
                            widget.currentLocation.province == prov.name;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 36,
                            right: 16,
                          ),
                          leading: Icon(
                            Icons.location_city_rounded,
                            size: 16,
                            color: isProvSelected
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                          title: Text(
                            prov.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isProvSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isProvSelected
                                  ? Colors.blueAccent
                                  : primaryTextColor,
                            ),
                          ),
                          trailing: isProvSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.blueAccent,
                                  size: 18,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                          onTap: () {
                            setState(() {
                              _stagedDept = dept;
                              _stagedProv = prov;
                              _districtController.text =
                                  (widget.currentLocation.province == prov.name
                                  ? widget.currentLocation.district ?? ''
                                  : '');
                            });
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
