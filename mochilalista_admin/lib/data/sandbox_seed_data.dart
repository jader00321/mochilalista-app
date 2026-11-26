part of 'database_service.dart';

/// Semilla inicial de datos demostrativos para el entorno Sandbox.
mixin _SandboxSeedDataMixin {
  List<Map<String, dynamic>> _getInitialSandboxClients() {
    return [
      {
        'id': 'CLI-001',
        'business_name': 'Comercial & Librería El Estudiante',
        'owner_name': 'Carlos Mendoza Quispe',
        'document_id': '10458796321',
        'phone': '+51987654321',
        'current_device_id': 'ML-9K4B',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'MENSUAL',
        'license_status': 'ACTIVA',
        'license_expires': '2027-01-13T23:59:59.000Z',
        'next_nonce': 2,
        'updates_until': '2026-12-14T23:59:59.000Z',
        'ai_extra_credits': 50,
        'ai_accumulated_credits': 50,
        'notes': 'Cliente puntual en Piura. Usa Yape.',
        'created_at': '2026-11-01T10:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-101',
            'date': '2026-11-14T10:00:00.000Z',
            'amount': 35.0,
            'plan': 'MENSUAL',
            'method': 'Yape',
            'reference': 'Op. 948102',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-002',
        'business_name': 'Bazar Escolar Las Palmeras',
        'owner_name': 'Rosa María Benites',
        'document_id': '20601234567',
        'phone': '+51976543210',
        'current_device_id': 'ML-3X8P',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'TRIMESTRAL',
        'license_status': 'POR_VENCER',
        'license_expires': DateTime.now()
            .add(const Duration(days: 4))
            .toUtc()
            .toIso8601String(),
        'next_nonce': 2,
        'updates_until': '2027-02-14T23:59:59.000Z',
        'ai_extra_credits': 230,
        'ai_accumulated_credits': 230,
        'notes': 'Recordar cobranza preventiva antes del vencimiento.',
        'created_at': '2026-10-15T09:30:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-102',
            'date': '2026-10-15T09:30:00.000Z',
            'amount': 90.0,
            'plan': 'TRIMESTRAL',
            'method': 'Plin',
            'reference': 'Op. 551294',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-003',
        'business_name': 'Distribuidora & Útiles San Martín',
        'owner_name': 'Jorge Luis Ramos',
        'document_id': '10789456123',
        'phone': '+51954321098',
        'current_device_id': 'ML-7W2R',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'PERPETUO_LIBERADO',
        'license_status': 'PERPETUA',
        'license_expires': '2299-12-31T23:59:59.000Z',
        'next_nonce': 2,
        'updates_until': DateTime.now()
            .add(const Duration(days: 280))
            .toUtc()
            .toIso8601String(),
        'ai_extra_credits': 350,
        'ai_accumulated_credits': 350,
        'notes': 'Licencia Perpetua de por vida con updates vigentes.',
        'created_at': '2026-09-01T11:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-103',
            'date': '2026-09-01T11:00:00.000Z',
            'amount': 850.0,
            'plan': 'PERPETUO_LIBERADO',
            'method': 'BCP',
            'reference': 'Op. 112233',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-004',
        'business_name': 'Papelería & Novedades Huascarán',
        'owner_name': 'Carmen Luz Huamán',
        'document_id': '10321654987',
        'phone': '+51965432187',
        'current_device_id': 'ML-2V5M',
        'device_history': [],
        'installed_version': '9.29.0',
        'license_type': 'MENSUAL',
        'license_status': 'BLOQUEO_ESTRICTO',
        'license_expires': DateTime.now()
            .subtract(const Duration(days: 12))
            .toUtc()
            .toIso8601String(),
        'next_nonce': 2,
        'updates_until': '2026-10-01T23:59:59.000Z',
        'ai_extra_credits': 50,
        'ai_accumulated_credits': 50,
        'notes':
            'Licencia vencida hace 12 días. Enviar oferta de reactivación.',
        'created_at': '2026-08-10T14:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-104',
            'date': '2026-08-10T14:00:00.000Z',
            'amount': 35.0,
            'plan': 'MENSUAL',
            'method': 'Yape',
            'reference': 'Op. 887766',
          }
        ],
        'generated_codes_history': [],
      },
    ];
  }

  List<Map<String, dynamic>> _getInitialSandboxReleases() {
    return [
      {
        'version_name': '9.34.0',
        'version_code': 78,
        'db_schema_version': 36,
        'release_date': '2026-11-20T10:00:00.000Z',
        'type': 'FEATURE_RELEASE',
        'apk_file_path': '',
        'apk_download_url':
            'https://drive.google.com/file/d/mochilalista-v9.34.0/view',
        'apk_sha256':
            '4a5b6c7d8e9f0123456789abcdef0123456789abcdef0123456789abcdef0123',
        'file_size_mb': '28.40 MB',
        'changelog':
            '• Activación 100% Offline con Hardware ID (Settings.Secure.ANDROID_ID) y EULA oficial.\n• Cuota IA 100% Acumulativa sin reseteo mensual y arquitectura Multi-Perfil con bolsa compartida.\n• Bóveda de Claves BYOK (Google Gemini) y Respaldo Blindado en Google Drive (.mlbg).\n• Esquema SQLite v36 con sincronización de perfiles y trazabilidad de inventario.',
        'min_required_version': '9.0.0',
      },
      {
        'version_name': '9.29.0',
        'version_code': 73,
        'db_schema_version': 35,
        'release_date': '2026-11-01T15:00:00.000Z',
        'type': 'HOTFIX',
        'apk_file_path': '',
        'apk_download_url':
            'https://drive.google.com/file/d/mochilalista-v9.29.0/view',
        'apk_sha256':
            '1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890',
        'file_size_mb': '26.85 MB',
        'changelog':
            '• Parche correctivo: Optimización de impresión Bluetooth térmica de 80mm.\n• Corrección menor en cálculo de vuelto en ventas mixtas.',
        'min_required_version': '9.0.0',
      },
    ];
  }
}
