import 'dart:convert';
import 'dart:io';

import '../http_context.dart';
import 'release_apk_helper.dart';

/// Sub-router para catálogo de releases, verificación individual/masiva (`verify`, `verify-all`),
/// notas compañeras, matriz de adopción y trazabilidad de envío (`/api/releases/*`).
class ReleasesRoutes {
  ReleasesRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/releases/verify-all' && method == 'POST') {
      await _handleVerifyAll(ctx);
      return true;
    }

    final verifyReleaseMatch =
        RegExp(r'^/api/releases/([^/]+)/verify$').firstMatch(path);
    if (verifyReleaseMatch != null && method == 'POST') {
      await _handleVerifySingle(
        ctx,
        Uri.decodeComponent(verifyReleaseMatch.group(1)!),
      );
      return true;
    }

    final companionNotesMatch =
        RegExp(r'^/api/releases/([^/]+)/companion-notes$').firstMatch(path);
    if (companionNotesMatch != null && method == 'GET') {
      await _handleCompanionNotes(
        ctx,
        Uri.decodeComponent(companionNotesMatch.group(1)!),
      );
      return true;
    }

    if (path == '/api/releases/mark-sent' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final clientId = body['client_id'] as String? ?? '';
      final version = body['version'] as String? ?? '';
      final variant = body['variant'] as String?;

      if (clientId.isEmpty || version.isEmpty) {
        await ctx.sendJson(
          {'error': 'client_id y version son requeridos'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      final updated = await ctx.dbService
          .recordApkDispatched(clientId, version, variant: variant);
      if (updated == null) {
        await ctx.sendJson({'error': 'Cliente no encontrado'},
            statusCode: HttpStatus.notFound);
      } else {
        await ctx.sendJson({
          'ok': true,
          'client_id': clientId,
          'version': version,
          'variant': variant,
          'marked_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return true;
    }

    if ((path == '/api/releases/matrix' ||
            path == '/api/releases/distribution-matrix') &&
        method == 'GET') {
      await ctx.sendJson(await ctx.dbService.getUpdateDistributionMatrix());
      return true;
    }

    if (path == '/api/releases') {
      if (method == 'GET') {
        await ctx.sendJson(await ctx.dbService.getReleases());
        return true;
      } else if (method == 'POST') {
        final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        final newRelease = await ctx.dbService.createRelease(body);
        await ctx.sendJson(newRelease, statusCode: HttpStatus.created);
        return true;
      }
    }

    final releaseSingleMatch =
        RegExp(r'^/api/releases/([^/]+)$').firstMatch(path);
    if (releaseSingleMatch != null) {
      final ver = Uri.decodeComponent(releaseSingleMatch.group(1)!);
      if (method == 'PUT') {
        final rawDecoded =
            jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        final body = <String, dynamic>{
          for (final entry in rawDecoded.entries) entry.key: entry.value,
        };
        final updated = await ctx.dbService.updateRelease(ver, body);
        if (updated == null) {
          await ctx.sendJson({'error': 'Versión no encontrada'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(updated);
        }
        return true;
      } else if (method == 'DELETE') {
        final ok = await ctx.dbService.deleteRelease(ver);
        if (!ok) {
          await ctx.sendJson({'error': 'Versión no encontrada'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(
              {'ok': true, 'message': 'Versión eliminada con éxito.'});
        }
        return true;
      }
    }

    return false;
  }

  static Future<void> _handleVerifyAll(AdminHttpContext ctx) async {
    final sw = Stopwatch()..start();
    bool forceRefresh = (ctx.request.uri.queryParameters['force'] ?? '')
            .trim()
            .toLowerCase() ==
        'true';
    try {
      final bodyStr = await ctx.readBody();
      if (bodyStr.trim().isNotEmpty) {
        final decoded = jsonDecode(bodyStr);
        if (decoded is Map && decoded['force'] == true) {
          forceRefresh = true;
        }
      }
    } catch (_) {}

    final releases = await ctx.dbService.getReleases();
    final updatesByVersion = <String, Map<String, dynamic>>{};
    final items = <Map<String, dynamic>>[];

    int officialCount = 0;
    int unofficialCount = 0;
    int unverifiedCount = 0;
    int missingCount = 0;
    int updatedCount = 0;

    for (final release in releases) {
      final ver = release['version_name'] as String? ?? '';
      if (ver.isEmpty) continue;

      final verification =
          await ReleaseApkHelper.inspectAndComputeReleaseVerification(
        release,
        inspector: ctx.inspector,
        configService: ctx.configService,
        forceRefresh: forceRefresh,
        readCompanionNotes: false,
      );
      final updates = verification['updates'] as Map<String, dynamic>;
      final anyFileExists = verification['file_exists'] == true;
      final verifiedVariants =
          (verification['verified_variants'] as List).cast<String>();

      final previewRel = Map<String, dynamic>.from(release);
      final beforeComparable = jsonEncode(previewRel);
      ctx.dbService.applyReleaseUpdatesToMap(previewRel, updates);
      final releaseChanged = jsonEncode(previewRel) != beforeComparable;

      if (releaseChanged) {
        updatedCount++;
      }
      updatesByVersion[ver] = updates;

      final sigStatus = previewRel['signature_status'] as String? ?? 'UNVERIFIED';
      final sigVerified = previewRel['signature_verified'];
      if (!anyFileExists) {
        missingCount++;
      } else if (sigStatus == 'OFFICIAL_RELEASE' || sigVerified == true) {
        officialCount++;
      } else if (sigStatus == 'UNOFFICIAL_SIGNATURE' ||
          (sigVerified == false && sigStatus != 'UNVERIFIED')) {
        unofficialCount++;
      } else {
        unverifiedCount++;
      }

      items.add({
        'version_name': ver,
        'version_code': previewRel['version_code'],
        'file_exists': anyFileExists,
        'signature_status': sigStatus,
        'signature_verified': sigVerified,
        'signature_detail': previewRel['signature_detail'],
        'verified_variants': verifiedVariants,
        'updated': releaseChanged,
      });
    }

    final finalReleases = releases.isEmpty
        ? releases
        : await ctx.dbService.applyBatchReleaseUpdates(
            updatesByVersion,
            reason: 'verify_all_releases',
          );
    sw.stop();

    await ctx.sendJson({
      'ok': true,
      'total': releases.length,
      'official_count': officialCount,
      'unofficial_count': unofficialCount,
      'unverified_count': unverifiedCount,
      'missing_count': missingCount,
      'updated_count': updatedCount,
      'duration_ms': sw.elapsedMilliseconds,
      'items': items,
      'releases': finalReleases,
    });
  }

  static Future<void> _handleVerifySingle(
    AdminHttpContext ctx,
    String versionName,
  ) async {
    final release = await ctx.dbService.getReleaseByVersion(versionName);
    if (release == null) {
      await ctx.sendJson({'error': 'Versión no encontrada'},
          statusCode: HttpStatus.notFound);
      return;
    }

    final forceRefresh = (ctx.request.uri.queryParameters['force'] ?? '')
            .trim()
            .toLowerCase() ==
        'true';
    final verification =
        await ReleaseApkHelper.inspectAndComputeReleaseVerification(
      release,
      inspector: ctx.inspector,
      configService: ctx.configService,
      forceRefresh: forceRefresh,
      readCompanionNotes: true,
    );
    final updates = verification['updates'] as Map<String, dynamic>;
    final anyFileExists = verification['file_exists'] == true;
    final verifiedVariants =
        (verification['verified_variants'] as List).cast<String>();
    final companionNotes =
        (verification['companion_notes'] as Map<String, dynamic>?) ?? const {};

    final updatedRelease =
        await ctx.dbService.updateRelease(versionName, updates);

    await ctx.sendJson({
      'ok': true,
      'release': updatedRelease ?? release,
      'file_exists': anyFileExists,
      'verified_variants': verifiedVariants,
      'suggested_changelog': companionNotes['suggested_changelog'],
      'suggested_internal_notes': companionNotes['suggested_internal_notes'],
      if (companionNotes['changelog_source'] != null)
        'changelog_source': companionNotes['changelog_source'],
      if (companionNotes['internal_notes_source'] != null)
        'internal_notes_source': companionNotes['internal_notes_source'],
    });
  }

  static Future<void> _handleCompanionNotes(
    AdminHttpContext ctx,
    String versionName,
  ) async {
    final release = await ctx.dbService.getReleaseByVersion(versionName);
    final apkPath = (release?['apk_file_path'] as String?) ??
        ((release?['universal_apk'] as Map<String, dynamic>?)?['file_path']
            as String?) ??
        ((release?['arm64_apk'] as Map<String, dynamic>?)?['file_path']
            as String?);
    final searchDirPaths = ctx.configService.getEffectiveApkSearchDirPaths(
      defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
    );

    final notes = await ctx.inspector.readCompanionNotesForVersion(
      versionName,
      apkPath: apkPath,
      apkLibraryDir: ctx.configService.apkLibraryDir,
      extraSearchDirs: searchDirPaths,
    );
    await ctx.sendJson(notes);
  }
}
