part of 'database_service.dart';

/// Repositorio del catálogo de versiones APK, variantes Universal/ARM64 y matriz de adopción.
mixin _ReleasesRepositoryMixin on _DatabaseServiceBase {
  @override
  Future<List<Map<String, dynamic>>> getReleases() async {
    if (!await _releasesFile.exists()) return [];
    final content = await _releasesFile.readAsString();
    final list = jsonDecode(content) as List;
    final releases = list.cast<Map<String, dynamic>>();

    for (final r in releases) {
      final p = (r['apk_file_path'] as String?)?.trim();
      final u = r['universal_apk'] as Map<String, dynamic>?;
      final a = r['arm64_apk'] as Map<String, dynamic>?;

      final mainExists =
          p != null && p.isNotEmpty && await File(p).exists();
      bool univExists = false;
      bool armExists = false;

      if (u != null) {
        final up = (u['file_path'] as String? ?? '').trim();
        univExists = up.isNotEmpty && await File(up).exists();
        u['file_exists'] = univExists;
      }
      if (a != null) {
        final ap = (a['file_path'] as String? ?? '').trim();
        armExists = ap.isNotEmpty && await File(ap).exists();
        a['file_exists'] = armExists;
      }

      r['file_exists'] = mainExists || univExists || armExists;
    }

    return releases;
  }

  @override
  Future<void> saveReleases(
    List<Map<String, dynamic>> releases, {
    String reason = 'update_releases',
  }) async {
    await _releasesFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(releases));
    await _createSnapshot(reason);
    if (_mode == 'prod' && onProductionDataChanged != null) {
      try {
        await onProductionDataChanged!();
      } catch (e) {
        stderr.writeln(
            'Warning: Error al ejecutar onProductionDataChanged tras saveReleases: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getReleaseByVersion(String versionName) async {
    final releases = await getReleases();
    try {
      return releases.firstWhere((r) => r['version_name'] == versionName);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createRelease(
      Map<String, dynamic> releaseData) async {
    final releases = await getReleases();
    final versionName = releaseData['version_name'] ?? '9.24.0';

    releases.removeWhere((r) => r['version_name'] == versionName);

    final apkFilePath = (releaseData['apk_file_path'] ?? '').toString().trim();
    final rawAbi =
        (releaseData['abi_variant'] as String? ?? '').trim().toUpperCase();
    final abiVariant = rawAbi == 'ARM64' ? 'ARM64' : 'UNIVERSAL';
    final sha256Str =
        (releaseData['apk_sha256'] ?? '').toString().toLowerCase();
    final sizeMbStr = (releaseData['file_size_mb'] ?? '').toString();
    final sigStatus = releaseData['signature_status'] ?? 'UNVERIFIED';
    final sigVerified = releaseData['signature_verified'];

    Map<String, dynamic>? universalApk = releaseData['universal_apk'] is Map
        ? Map<String, dynamic>.from(releaseData['universal_apk'] as Map)
        : null;
    Map<String, dynamic>? arm64Apk = releaseData['arm64_apk'] is Map
        ? Map<String, dynamic>.from(releaseData['arm64_apk'] as Map)
        : null;

    if (apkFilePath.isNotEmpty) {
      final fileExistsNow = await File(apkFilePath).exists();
      final initialVariantMap = <String, dynamic>{
        'file_path': apkFilePath,
        'file_size_mb': sizeMbStr,
        'sha256': sha256Str,
        'signature_status': sigStatus,
        'signature_verified': sigVerified,
        if (releaseData['signer_sha256'] != null)
          'signer_sha256': releaseData['signer_sha256'],
        if (releaseData['signer_dn'] != null)
          'signer_dn': releaseData['signer_dn'],
        'file_exists': fileExistsNow,
      };
      if (abiVariant == 'ARM64') {
        arm64Apk ??= initialVariantMap;
      } else {
        universalApk ??= initialVariantMap;
      }
    }

    final newRelease = {
      'version_name': versionName,
      'version_code': (releaseData['version_code'] as num?)?.toInt() ?? 82,
      'db_schema_version':
          (releaseData['db_schema_version'] as num?)?.toInt() ?? 36,
      'release_date': releaseData['release_date'] ??
          DateTime.now().toUtc().toIso8601String(),
      'type': releaseData['type'] == 'HOTFIX' ? 'HOTFIX' : 'FEATURE_RELEASE',
      'abi_variant': abiVariant,
      'apk_file_path': apkFilePath,
      'apk_download_url': releaseData['apk_download_url'] ?? '',
      'apk_sha256': sha256Str,
      'file_size_mb': sizeMbStr,
      'changelog': releaseData['changelog'] ?? '',
      'internal_notes': releaseData['internal_notes'] ?? '',
      'min_required_version': releaseData['min_required_version'] ?? '9.0.0',
      'signature_verified': sigVerified,
      'signature_status': sigStatus,
      'signer_sha256': releaseData['signer_sha256'],
      'signer_dn': releaseData['signer_dn'],
      if (universalApk != null) 'universal_apk': universalApk,
      if (arm64Apk != null) 'arm64_apk': arm64Apk,
    };

    releases.insert(0, newRelease);
    await saveReleases(releases,
        reason: 'create_release_${newRelease['version_name']}');
    return newRelease;
  }

  /// Aplica actualizaciones de metadatos/variantes sobre un registro de release en memoria
  /// reconciliando campos raíz al desvincular variantes opcionales.
  @override
  void applyReleaseUpdatesToMap(
    Map<String, dynamic> release,
    Map<String, dynamic> updates,
  ) {
    updates.forEach((key, value) {
      if (key == 'version_name') return;
      if ((key == 'arm64_apk' || key == 'universal_apk') && value == null) {
        release.remove(key);
        return;
      }
      if (key == 'version_code' || key == 'db_schema_version') {
        if (value is num) {
          release[key] = value.toInt();
        } else if (value is String) {
          release[key] = int.tryParse(value) ?? release[key];
        } else {
          release[key] = value;
        }
      } else {
        release[key] = value;
      }
    });

    final unlinkedUniv = updates.containsKey('universal_apk') &&
        updates['universal_apk'] == null;
    final unlinkedArm =
        updates.containsKey('arm64_apk') && updates['arm64_apk'] == null;
    if (unlinkedUniv || unlinkedArm) {
      final remainingUniv = release['universal_apk'] as Map<String, dynamic>?;
      final remainingArm = release['arm64_apk'] as Map<String, dynamic>?;
      final promoted = remainingUniv ?? remainingArm;

      if (promoted != null) {
        final promotedPath = (promoted['file_path'] as String? ?? '').trim();
        release['abi_variant'] = remainingUniv != null ? 'UNIVERSAL' : 'ARM64';
        release['apk_file_path'] = promotedPath;
        release['file_size_mb'] = promoted['file_size_mb'] ?? '';
        release['apk_sha256'] =
            (promoted['sha256'] ?? '').toString().toLowerCase();
        release['signature_status'] =
            promoted['signature_status'] ?? 'UNVERIFIED';
        release['signature_verified'] = promoted['signature_verified'];
        release['signer_sha256'] = promoted['signer_sha256'];
        release['signer_dn'] = promoted['signer_dn'];
        release['file_exists'] =
            promotedPath.isNotEmpty && File(promotedPath).existsSync();
      } else {
        release['apk_file_path'] = '';
        release['file_size_mb'] = '';
        release['apk_sha256'] = '';
        release['signature_status'] = 'UNVERIFIED';
        release['signature_verified'] = null;
        release['signer_sha256'] = null;
        release['signer_dn'] = null;
        release['file_exists'] = false;
      }
    }
  }

  Future<Map<String, dynamic>?> updateRelease(
      String versionName, Map<String, dynamic> updates) async {
    final releases = await getReleases();
    final index = releases.indexWhere((r) => r['version_name'] == versionName);
    if (index == -1) return null;

    final release = releases[index];
    applyReleaseUpdatesToMap(release, updates);
    releases[index] = release;
    await saveReleases(releases, reason: 'update_release_$versionName');
    return release;
  }

  /// Aplica actualizaciones en lote sobre el catálogo y guarda un único snapshot consolidado
  /// en disco solo si los datos persistidos cambiaron realmente.
  Future<List<Map<String, dynamic>>> applyBatchReleaseUpdates(
    Map<String, Map<String, dynamic>> updatesByVersion, {
    String reason = 'verify_all_releases',
  }) async {
    if (!await _releasesFile.exists()) return [];
    final rawBeforeContent = await _releasesFile.readAsString();
    final decoded = jsonDecode(rawBeforeContent) as List;
    final releases = decoded.cast<Map<String, dynamic>>();

    bool anyDiskChange = false;
    const encoder = JsonEncoder.withIndent('  ');
    for (int i = 0; i < releases.length; i++) {
      final ver = releases[i]['version_name'] as String?;
      if (ver == null) continue;
      final patch = updatesByVersion[ver];
      if (patch == null || patch.isEmpty) continue;
      final beforeItemJson = jsonEncode(releases[i]);
      applyReleaseUpdatesToMap(releases[i], patch);
      if (jsonEncode(releases[i]) != beforeItemJson) {
        anyDiskChange = true;
      }
    }

    if (anyDiskChange || encoder.convert(releases) != rawBeforeContent) {
      await saveReleases(releases, reason: reason);
    }

    return await getReleases();
  }

  Future<bool> deleteRelease(String versionName) async {
    final releases = await getReleases();
    final index = releases.indexWhere((r) => r['version_name'] == versionName);
    if (index == -1) return false;

    final rel = releases.removeAt(index);

    final pathsToDelete = [
      rel['apk_file_path'] as String?,
      (rel['universal_apk'] as Map<String, dynamic>?)?['file_path'] as String?,
      (rel['arm64_apk'] as Map<String, dynamic>?)?['file_path'] as String?,
    ];

    for (final p in pathsToDelete) {
      if (p != null && p.isNotEmpty) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }

    await saveReleases(releases, reason: 'delete_release_$versionName');
    return true;
  }

  /// Matriz Inteligente de Distribución de Versiones con SemVer real.
  Future<List<Map<String, dynamic>>> getUpdateDistributionMatrix() async {
    final releases = await getReleases();
    if (releases.isEmpty) return [];

    final latestRelease = releases.first;
    final latestVersion = latestRelease['version_name'] as String? ?? '9.0.0';
    final clients = await getClients();
    final now = DateTime.now();

    final List<Map<String, dynamic>> matrix = [];

    for (final client in clients) {
      final installedVersion =
          (client['installed_version'] as String? ?? '9.0.0');
      final cmp =
          DatabaseService.compareSemVer(installedVersion, latestVersion);
      final lastSentVersion = client['last_apk_sent_version'] as String?;
      final isSentForLatest =
          lastSentVersion != null && lastSentVersion == latestVersion;

      final licenseType =
          (client['license_type'] as String? ?? 'MENSUAL').toUpperCase();
      final situation = (client['situation'] as String? ?? '').toUpperCase();
      final isProspect = situation == 'PROSPECTO' || licenseType == 'PROSPECTO';
      final isPerpetual =
          licenseType == 'PERPETUO_LIBERADO' || licenseType == 'PERPETUO';

      final expiresStr = client['license_expires'] as String?;
      final expires = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
      final isSubscriptionActive = expires != null && expires.isAfter(now);

      final updatesUntilStr = client['updates_until'] as String?;
      final updatesUntil =
          updatesUntilStr != null ? DateTime.tryParse(updatesUntilStr) : null;
      final hasActiveUpdatePass =
          updatesUntil != null && updatesUntil.isAfter(now);

      String updateStatus;
      bool isUpToDate;
      bool canDowngrade = false;
      bool isEligibleForFree = false;
      String eligibilityReason = '';
      String requiredAction = 'Ninguna (Al día)';

      if (isProspect) {
        updateStatus = 'PROSPECT';
        isUpToDate = false;
        isEligibleForFree = false;
        eligibilityReason = 'Prospecto comercial sin app vinculada todavía.';
        requiredAction = 'Vincular y Activar App';
      } else if (cmp > 0) {
        updateStatus = 'AHEAD';
        isUpToDate = true;
        isEligibleForFree = true;
        eligibilityReason =
            'Tiene instalada una versión superior a la publicada en este catálogo.';
        requiredAction = 'Versión Superior (Al día)';
        canDowngrade = false;
      } else if (cmp == 0) {
        updateStatus = 'UP_TO_DATE';
        isUpToDate = true;
        isEligibleForFree = true;
        eligibilityReason = 'Ya tiene instalada la última versión.';
        requiredAction = 'Al día';
      } else {
        if (isSentForLatest) {
          updateStatus = 'SENT';
          isUpToDate = false;
          isEligibleForFree = isSubscriptionActive ||
              hasActiveUpdatePass ||
              latestRelease['type'] == 'HOTFIX';
          final sentDate = client['last_apk_sent_at'] != null
              ? client['last_apk_sent_at'].toString().substring(0, 10)
              : '';
          eligibilityReason =
              'APK ya enviado${sentDate.isNotEmpty ? " el $sentDate" : ""}. Pendiente de instalación por el cliente.';
          requiredAction = 'APK Enviado (Esperando instalación)';
        } else {
          updateStatus = 'OUTDATED';
          isUpToDate = false;
          if (latestRelease['type'] == 'HOTFIX') {
            isEligibleForFree = true;
            eligibilityReason =
                'Hotfix / Parche de estabilidad (Gratuito vitalicio).';
            requiredAction = 'Enviar Actualización Gratuita';
          } else if (isPerpetual) {
            if (hasActiveUpdatePass) {
              isEligibleForFree = true;
              eligibilityReason =
                  'Licencia Perpetua con Pase de Actualizaciones vigente.';
              requiredAction = 'Enviar Nueva Versión';
            } else {
              isEligibleForFree = false;
              eligibilityReason =
                  'Licencia Perpetua: Periodo de 1 año de updates vencido.';
              requiredAction = 'Ofrecer Pase Anual de Updates (S/ 150.00)';
            }
          } else if (isSubscriptionActive) {
            isEligibleForFree = true;
            eligibilityReason =
                'Suscripción activa incluye todas las actualizaciones.';
            requiredAction = 'Enviar Nueva Versión';
          } else {
            isEligibleForFree = false;
            eligibilityReason =
                'Suscripción vencida. Requiere renovar el plan.';
            requiredAction = 'Renovar Suscripción para Actualizar';
          }
        }
      }

      matrix.add({
        'client_id': client['id'],
        'business_name': client['business_name'],
        'owner_name': client['owner_name'],
        'phone': client['phone'],
        'device_id': client['current_device_id'],
        'installed_version': installedVersion,
        'latest_version': latestVersion,
        'release_type': latestRelease['type'],
        'update_status': updateStatus,
        'can_downgrade': canDowngrade,
        'is_up_to_date': isUpToDate,
        'is_eligible_for_free': isEligibleForFree,
        'eligibility_reason': eligibilityReason,
        'required_action': requiredAction,
        'download_url': latestRelease['apk_download_url'],
        'changelog': latestRelease['changelog'],
        'has_local_apk':
            (latestRelease['apk_file_path'] as String? ?? '').isNotEmpty ||
                latestRelease['universal_apk'] != null ||
                latestRelease['arm64_apk'] != null,
        'last_apk_sent_version': client['last_apk_sent_version'],
        'last_apk_sent_at': client['last_apk_sent_at'],
        'universal_apk': latestRelease['universal_apk'],
        'arm64_apk': latestRelease['arm64_apk'],
        'has_universal_apk': latestRelease['universal_apk'] != null,
        'has_arm64_apk': latestRelease['arm64_apk'] != null,
      });
    }

    return matrix;
  }
}
