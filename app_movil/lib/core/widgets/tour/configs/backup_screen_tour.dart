import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Respaldos y Seguridad
class BackupScreenTourKeys {
  final GlobalKey cloudBackupKey;
  final GlobalKey localAutoBackupKey;
  final GlobalKey localExportKey;
  final GlobalKey localImportKey;

  BackupScreenTourKeys({
    GlobalKey? cloudBackupKey,
    GlobalKey? localAutoBackupKey,
    GlobalKey? localExportKey,
    GlobalKey? localImportKey,
  })  : cloudBackupKey = cloudBackupKey ?? GlobalKey(debugLabel: 'backup_tour_cloud'),
        localAutoBackupKey = localAutoBackupKey ?? GlobalKey(debugLabel: 'backup_tour_local_auto'),
        localExportKey = localExportKey ?? GlobalKey(debugLabel: 'backup_tour_local_export'),
        localImportKey = localImportKey ?? GlobalKey(debugLabel: 'backup_tour_local_import');
}

/// Configuración de la Guía Turística para Respaldos y Seguridad en la Nube
class BackupScreenTour {
  static final BackupScreenTourKeys defaultKeys = BackupScreenTourKeys();

  static ScreenTourConfig buildConfig({BackupScreenTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'backup_screen',
      screenTitle: 'Respaldos y Seguridad',
      welcomeSummary:
          'Protege toda tu información comercial con copias automáticas en Google Drive y archivos locales seguros para que nunca pierdas tus datos.',
      icon: Icons.shield_rounded,
      steps: [
        TourStep(
          id: 'step_cloud_backup',
          targetKey: k.cloudBackupKey,
          title: 'Respaldo Seguro en Google Drive',
          description:
              'Tus negocios se respaldan con cifrado AES-256-GCM en tu cuenta de Google Drive. Mantén hasta 5 copias rotativas automáticas en la nube.',
          tip: 'Verifica el indicador "Al día" para asegurarte de que tu información está protegida.',
          icon: Icons.cloud_done_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_local_auto_backup',
          targetKey: k.localAutoBackupKey,
          title: 'Respaldo Local en el Celular',
          description:
              'Activa la generación periódica en segundo plano de copias en el almacenamiento de tu teléfono para trabajar sin internet.',
          tip: 'Puedes configurar copias diarias o semanales en la memoria interna.',
          icon: Icons.schedule_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_local_export',
          targetKey: k.localExportKey,
          title: 'Exportar Copia Local (.mlbg)',
          description:
              'Genera un archivo cifrado con todos tus negocios para enviarlo por WhatsApp personal, guardarlo en una memoria USB o transferirlo a tu computadora.',
          tip: 'Los archivos .mlbg son livianos y están 100% protegidos con clave criptográfica.',
          icon: Icons.upload_file_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_local_import',
          targetKey: k.localImportKey,
          title: 'Restaurar Copia Local',
          description:
              'Recupera tus negocios desde un archivo .mlbg si cambias de celular o necesitas restaurar una versión anterior con protección contra reemplazo accidental.',
          tip: 'La app verifica la integridad criptográfica del archivo antes de restaurar.',
          icon: Icons.settings_backup_restore_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
