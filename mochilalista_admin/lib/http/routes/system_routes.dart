import 'dart:convert';
import 'dart:io';

import '../http_context.dart';
import '../windows_shell_helpers.dart';

/// Sub-router para control de entorno Sandbox/Producción, navegador y apagado (`/api/system/*`, `/api/mode`).
class SystemRoutes {
  SystemRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/system/mode' || path == '/api/mode') {
      if (method == 'GET') {
        await ctx.sendJson({
          'ok': true,
          'mode': ctx.dbService.currentMode,
          'label': ctx.dbService.currentMode == 'sandbox'
              ? 'Modo Pruebas (Sandbox)'
              : 'Modo Real (Producción)',
        });
        return true;
      } else if (method == 'POST') {
        final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        final targetMode = body['mode'] as String? ?? 'sandbox';
        ctx.dbService.setMode(targetMode);
        await ctx.sendJson({
          'ok': true,
          'mode': ctx.dbService.currentMode,
          'label': ctx.dbService.currentMode == 'sandbox'
              ? 'Modo Pruebas (Sandbox)'
              : 'Modo Real (Producción)',
        });
        return true;
      }
    }

    if (path == '/api/system/reset-sandbox' && method == 'POST') {
      await ctx.dbService.resetSandbox();
      await ctx.sendJson({
        'ok': true,
        'message':
            'Entorno de pruebas Sandbox restablecido exitosamente a los datos de demostración.',
      });
      return true;
    }

    if (path == '/api/system/open-browser' && method == 'POST') {
      const targetUrl = 'http://localhost:8080';
      if (ctx.onOpenBrowserOverride != null) {
        await ctx.onOpenBrowserOverride!(targetUrl);
      } else {
        await WindowsShellHelpers.launchBrowserDetached(targetUrl);
      }
      ctx.request.response.headers.contentType = ContentType.json;
      await ctx.sendJson({
        'ok': true,
        'url': targetUrl,
        'message': 'Navegador iniciado exitosamente.',
      });
      return true;
    }

    if (path == '/api/system/shutdown' && method == 'POST') {
      ctx.request.response.headers.contentType = ContentType.json;
      await ctx.sendJson({
        'ok': true,
        'message': 'Servidor administrativo apagado correctamente.',
      });

      Future.delayed(const Duration(milliseconds: 250), () {
        if (ctx.onExitOverride != null) {
          ctx.onExitOverride!(0);
        } else {
          exit(0);
        }
      });
      return true;
    }

    return false;
  }
}
