import 'dart:convert';
import 'dart:io';

import '../../core/time_utils.dart';
import '../../database_service.dart';
import '../http_context.dart';

/// Sub-router para Finanzas, Exportación CSV/Excel y Centro de Respaldos (`/api/finances/*`, `/api/export/*`, `/api/backups/*`).
class FinancesBackupsRoutes {
  FinancesBackupsRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/finances' && method == 'GET') {
      await ctx.sendJson(await ctx.dbService.getConsolidatedFinances());
      return true;
    }

    if ((path == '/api/finances/export-csv' || path == '/api/finances/export') &&
        method == 'GET') {
      final csvData = await ctx.dbService.exportFinancesToCsv();
      final dateStr = PeruTimeHelper.formatLimaDate(DateTime.now());
      ctx.request.response.headers.contentType =
          ContentType('text', 'csv', charset: 'utf-8');
      ctx.request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="libro_contable_${ctx.dbService.currentMode}_$dateStr.csv"',
      );
      ctx.request.response.write(csvData);
      await ctx.request.response.close();
      return true;
    }

    if ((path == '/api/export/excel-master' || path == '/api/export/excel') &&
        method == 'GET') {
      final bytes = await ctx.excelService.generateMasterWorkbook();
      final dateStr = PeruTimeHelper.formatLimaDate(DateTime.now());
      ctx.request.response.headers.contentType = ContentType(
          'application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ctx.request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="MochilaLista_Reporte_Maestro_${ctx.dbService.currentMode}_$dateStr.xlsx"',
      );
      ctx.request.response.add(bytes);
      await ctx.request.response.close();
      return true;
    }

    if ((path == '/api/export/excel-finances' ||
            path == '/api/finances/export-excel') &&
        method == 'GET') {
      final fromDate = ctx.request.uri.queryParameters['from'];
      final toDate = ctx.request.uri.queryParameters['to'];
      final bytes = await ctx.excelService.generateFinancesReport(
        fromDate: fromDate,
        toDate: toDate,
      );
      final dateStr = PeruTimeHelper.formatLimaDate(DateTime.now());
      ctx.request.response.headers.contentType = ContentType(
          'application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ctx.request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="MochilaLista_Reporte_Financiero_${ctx.dbService.currentMode}_$dateStr.xlsx"',
      );
      ctx.request.response.add(bytes);
      await ctx.request.response.close();
      return true;
    }

    if (path == '/api/backups' && method == 'GET') {
      await ctx.sendJson(await ctx.dbService.listBackups());
      return true;
    }

    if (path == '/api/backups/create' && method == 'POST') {
      await ctx.sendJson(await ctx.dbService.createManualBackup());
      return true;
    }

    if (path == '/api/backups/open-folder' && method == 'POST') {
      final dirPath = Directory(ctx.dbService.backupDir).absolute.path;
      if (Platform.isWindows) {
        try {
          Process.run('explorer.exe', [dirPath]);
        } catch (_) {}
      }
      await ctx.sendJson({'ok': true, 'path': dirPath});
      return true;
    }

    if (path == '/api/backups/purge-sandbox' && method == 'POST') {
      int keepRecent = 10;
      try {
        final bodyStr = await ctx.readBody();
        if (bodyStr.trim().isNotEmpty) {
          final body = jsonDecode(bodyStr);
          if (body is Map && body['keep_recent'] is num) {
            keepRecent = (body['keep_recent'] as num).toInt();
          }
        }
      } catch (_) {}
      await ctx.sendJson(
          await ctx.dbService.purgeSandboxBackups(keepRecent: keepRecent));
      return true;
    }

    if (path.startsWith('/api/backups/preview/') && method == 'GET') {
      final rawName = path.replaceFirst('/api/backups/preview/', '');
      final filename = Uri.decodeComponent(rawName).trim();
      if (!DatabaseService.isSafeBackupFilename(filename)) {
        await ctx.sendJson(
          {'error': 'Nombre de archivo de respaldo inválido o inseguro.'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      try {
        final preview = await ctx.dbService.previewBackup(
          filename,
          configService: ctx.configService,
        );
        if (preview == null) {
          await ctx.sendJson(
            {'error': 'Archivo de backup no encontrado.'},
            statusCode: HttpStatus.notFound,
          );
        } else {
          await ctx.sendJson(preview);
        }
      } catch (e) {
        await ctx.sendJson({'error': e.toString()},
            statusCode: HttpStatus.badRequest);
      }
      return true;
    }

    if (path.startsWith('/api/backups/download/') && method == 'GET') {
      final rawName = path.replaceFirst('/api/backups/download/', '');
      final filename = Uri.decodeComponent(rawName).trim();
      if (!DatabaseService.isSafeBackupFilename(filename)) {
        await ctx.sendJson(
          {'error': 'Nombre de archivo de respaldo inválido o inseguro.'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      final file = File('${ctx.dbService.backupDir}/$filename');
      if (!await file.exists()) {
        await ctx.sendJson(
          {'error': 'Archivo de backup no encontrado'},
          statusCode: HttpStatus.notFound,
        );
        return true;
      }
      ctx.request.response.headers.contentType = ContentType.json;
      ctx.request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="$filename"',
      );
      await file.openRead().pipe(ctx.request.response);
      return true;
    }

    if (path == '/api/backups/restore' && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final filename = (body['filename'] as String? ?? '').trim();
      if (!DatabaseService.isSafeBackupFilename(filename)) {
        await ctx.sendJson(
          {'error': 'Nombre de archivo de respaldo inválido o inseguro.'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      try {
        final res = await ctx.dbService.restoreFromBackupWithDetails(
          filename,
          configService: ctx.configService,
        );
        if (res['ok'] == true) {
          await ctx.sendJson(res);
        } else {
          await ctx.sendJson(
            {
              'error': res['error'] ??
                  'No se pudo restaurar desde $filename. Verifique que el archivo exista en backups/.',
            },
            statusCode: HttpStatus.badRequest,
          );
        }
      } catch (e) {
        await ctx.sendJson({'error': e.toString()},
            statusCode: HttpStatus.badRequest);
      }
      return true;
    }

    return false;
  }
}
