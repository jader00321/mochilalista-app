/// Componentes numéricos extraídos de una cadena SemVer (`major.minor.patch+build`).
class SemVerParts {
  final int major;
  final int minor;
  final int patch;
  final int? buildCode;

  const SemVerParts({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildCode,
  });
}

/// Única fuente de verdad Dart en `mochilalista_admin` para parseo y comparación SemVer.
class SemVerUtils {
  SemVerUtils._();

  /// Parsea cadenas `v9.41.0+85`, `9.41.0-rc1`, `9.41` tolerando prefijo `v`/`V`.
  static SemVerParts parse(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'^[vV]'), '');
    final buildSplit = clean.split('+');
    final preSplit = buildSplit[0].split('-');
    final mainPart = preSplit[0];

    int? buildCode;
    if (buildSplit.length > 1) {
      final buildRaw = buildSplit[1].split('-').first.trim();
      buildCode = int.tryParse(buildRaw);
    }

    final segments = mainPart.split('.');
    final major = segments.isNotEmpty ? (int.tryParse(segments[0]) ?? 0) : 0;
    final minor = segments.length > 1 ? (int.tryParse(segments[1]) ?? 0) : 0;
    final patch = segments.length > 2 ? (int.tryParse(segments[2]) ?? 0) : 0;

    return SemVerParts(
      major: major,
      minor: minor,
      patch: patch,
      buildCode: buildCode,
    );
  }

  /// Compara dos cadenas SemVer numéricamente.
  ///
  /// Cuando [compareBuild] es `true` y ambas versiones declaran `+buildCode`,
  /// desempata por `buildCode`. Si una versión carece de `+buildCode`, retorna `0`.
  static int compare(
    String? a,
    String? b, {
    bool compareBuild = false,
  }) {
    final aEmpty = a == null || a.trim().isEmpty;
    final bEmpty = b == null || b.trim().isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return -1;
    if (bEmpty) return 1;

    final pa = parse(a);
    final pb = parse(b);

    if (pa.major != pb.major) return pa.major.compareTo(pb.major);
    if (pa.minor != pb.minor) return pa.minor.compareTo(pb.minor);
    if (pa.patch != pb.patch) return pa.patch.compareTo(pb.patch);

    if (compareBuild &&
        pa.buildCode != null &&
        pb.buildCode != null &&
        pa.buildCode != pb.buildCode) {
      return pa.buildCode!.compareTo(pb.buildCode!);
    }

    return 0;
  }

  /// Infiere tipo de lanzamiento sugerido desde SemVer:
  /// `patch > 0` -> `HOTFIX`, `patch == 0` -> `FEATURE_RELEASE`.
  static String inferReleaseTypeFromVersion(String? versionName) {
    if (versionName == null || versionName.trim().isEmpty) {
      return 'FEATURE_RELEASE';
    }
    final parts = parse(versionName);
    return parts.patch > 0 ? 'HOTFIX' : 'FEATURE_RELEASE';
  }

  /// Compara nombres de carpetas de SDK build-tools numéricamente (ej. `37.0.0 > 36.1.0`).
  static int compareVersionFolderNames(String a, String b) {
    final nameA = a.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final nameB = b.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final partsA = nameA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = nameB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return nameA.compareTo(nameB);
  }
}
