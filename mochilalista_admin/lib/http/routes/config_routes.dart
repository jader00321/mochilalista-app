import 'dart:convert';
import 'dart:io';

import '../../commercial_config_sync_service.dart';
import '../http_context.dart';

/// Sub-router para Centro de Personalización del Propietario, plantillas WA y fichas MLC1 (`/api/config/*`).
class ConfigRoutes {
  ConfigRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if ((path == '/api/config' || path == '/api/config/owner') &&
        method == 'GET') {
      await ctx.sendJson(ctx.configService.config);
      return true;
    }

    if ((path == '/api/config' || path == '/api/config/owner') &&
        method == 'PUT') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final updated = await ctx.configService.saveConfig(body);
      await ctx.sendJson(updated);
      return true;
    }

    if ((path == '/api/config/reset' || path == '/api/config/owner/reset') &&
        method == 'POST') {
      final bodyStr = await ctx.readBody();
      String scope = 'all';
      if (bodyStr.trim().isNotEmpty) {
        final decoded = jsonDecode(bodyStr);
        if (decoded is Map && decoded['scope'] != null) {
          scope = decoded['scope'].toString().trim().toLowerCase();
        }
      }
      const allowedScopes = {
        'all',
        'pricing',
        'templates',
        'payment',
        'preferences',
      };
      if (!allowedScopes.contains(scope)) {
        await ctx.sendJson(
          {'ok': false, 'error': 'Alcance de restauración inválido: $scope'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      final restored = await ctx.configService.resetToDefaults(scope: scope);
      const scopeMessages = {
        'all':
            'Configuración completa del propietario restablecida a los valores oficiales de fábrica.',
        'pricing':
            'Tarifario oficial y cuotas IA restablecidos a los valores de fábrica.',
        'templates':
            'Plantillas de WhatsApp restablecidas a los textos oficiales de fábrica.',
        'payment':
            'Medios de pago e identidad legal restablecidos a los valores de fábrica.',
        'preferences':
            'Preferencias de entorno, tema y densidad restablecidas (rutas APK preservadas).',
      };
      await ctx.sendJson({
        'ok': true,
        'scope': scope,
        'message': scopeMessages[scope] ?? scopeMessages['all'],
        'config': restored,
      });
      return true;
    }

    if (path == '/api/config/preview-template' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final templateKey = body['template_key'] as String?;
      final rawTemplate = body['template'] as String?;
      final context = (body['context'] as Map<String, dynamic>?) ?? {};

      final target = (rawTemplate != null && rawTemplate.isNotEmpty)
          ? rawTemplate
          : (templateKey ?? '');

      final rendered = ctx.configService.renderTemplate(target, context);
      await ctx.sendJson({'ok': true, 'rendered': rendered});
      return true;
    }

    if (path == '/api/config/generate-sync-token' && method == 'POST') {
      final syncService =
          ctx.commercialSyncService ?? CommercialConfigSyncService();
      try {
        if (!ctx.signer.isLoaded) {
          await ctx.signer.loadMasterKey();
        }
        final candidateRev = ctx.configService.commercialSyncRevision + 1;
        syncService.buildCanonicalPayload(
          ctx.configService.config,
          revision: candidateRev,
        );

        final nextRev =
            await ctx.configService.incrementCommercialSyncRevision();
        final issued = await syncService.generateSignedToken(
          ctx.configService.config,
          revision: nextRev,
          signer: ctx.signer,
        );
        final verified = await syncService.verifySignedToken(
          issued['token'] as String,
          signer: ctx.signer,
        );
        if (verified['valid'] != true) {
          await ctx.sendJson(
            {
              'ok': false,
              'error':
                  'Fallo en autoverificación Ed25519 del token generado: ${verified['error']}',
            },
            statusCode: HttpStatus.internalServerError,
          );
          return true;
        }

        final dartSnippet = syncService.generateOwnerCommercialDefaultsDartFile(
          ctx.configService.config,
          revision: nextRev,
        );

        await ctx.sendJson({
          'ok': true,
          'token': issued['token'],
          'revision': issued['revision'],
          'issued_at': issued['issued_at'],
          'issued_at_unix': issued['issued_at_unix'],
          'issued_at_lima': issued['issued_at_lima'],
          'payload_bytes': issued['payload_bytes'],
          'token_bytes': issued['token_bytes'],
          'payload': issued['payload'],
          'summary': issued['summary'],
          'dart_snippet': dartSnippet,
          'target_file_path':
              'app_movil/lib/core/config/owner_commercial_defaults.dart',
          'download_filename': 'owner_commercial_defaults.dart',
          'config': ctx.configService.config,
        });
      } on CommercialConfigSyncException catch (e) {
        await ctx.sendJson(
          {'ok': false, 'error': e.message},
          statusCode: HttpStatus.badRequest,
        );
      } catch (e) {
        await ctx.sendJson(
          {'ok': false, 'error': 'Error al emitir ficha firmada MLC1: $e'},
          statusCode: HttpStatus.internalServerError,
        );
      }
      return true;
    }

    if (path == '/api/config/dart-defaults-snippet' && method == 'GET') {
      final syncService =
          ctx.commercialSyncService ?? CommercialConfigSyncService();
      try {
        final currentRev = ctx.configService.commercialSyncRevision;
        final dartSnippet = syncService.generateOwnerCommercialDefaultsDartFile(
          ctx.configService.config,
          revision: currentRev,
        );
        final summary = syncService.buildSummaryFromConfig(
          ctx.configService.config,
          revision: currentRev < 1 ? 1 : currentRev,
        );
        await ctx.sendJson({
          'ok': true,
          'revision': currentRev,
          'dart_snippet': dartSnippet,
          'target_file_path':
              'app_movil/lib/core/config/owner_commercial_defaults.dart',
          'download_filename': 'owner_commercial_defaults.dart',
          'summary': summary,
        });
      } on CommercialConfigSyncException catch (e) {
        await ctx.sendJson(
          {'ok': false, 'error': e.message},
          statusCode: HttpStatus.badRequest,
        );
      } catch (e) {
        await ctx.sendJson(
          {'ok': false, 'error': 'Error al generar constantes Dart: $e'},
          statusCode: HttpStatus.internalServerError,
        );
      }
      return true;
    }

    return false;
  }
}
