import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../database/local_db.dart'; // 🔥 Importamos SQLite para guardar el historial

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Icono por defecto de Android (mipmap/ic_launcher)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Aquí puedes manejar el Deep Linking (ej. al tocar la notificación de backup, abrir la pantalla de backups)
        if (response.payload != null) {
          debugPrint("Notificación tocada con payload: ${response.payload}");
        }
      },
    );
  }

  // ===========================================================================
  // 🔥 NUEVA LÓGICA OFFLINE: Muestra la alerta EN PANTALLA y la GUARDA en BD
  // ===========================================================================
  Future<void> showAndSaveNotification({
    required int negocioId,
    required int userId,
    required String title,
    required String body,
    String type = 'info', // info, exito, advertencia, error
    String prioridad = 'Media', // Alta, Media, Baja
    String? objetoRelacionadoTipo, // Ej: 'producto', 'venta', 'backup'
    int? objetoRelacionadoId, // Ej: el ID de la venta
    String? payload,
  }) async {
    
    // 1. Mostrar Alerta Nativa de Android (Pop-up en la parte superior)
    int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000); // ID único
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'mochilalista_channel_1', 
      'Alertas de Negocio', 
      channelDescription: 'Notificaciones sobre inventario, ventas y backups.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFF1E88E5), // Color azul principal
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      notifId, 
      title, 
      body, 
      platformChannelSpecifics, 
      payload: payload ?? objetoRelacionadoTipo, // Usamos el tipo como payload por defecto
    );

    // 2. Guardar el registro en SQLite para el historial en la App
    try {
      final db = await LocalDatabase.instance.database;
      await db.insert('notificaciones', {
        'user_id': userId,
        'negocio_id': negocioId,
        'titulo': title,
        'mensaje': body,
        'tipo': type,
        'leida': 0, // 0 = No leída (boolTypeFalse en SQLite)
        'fecha_creacion': DateTime.now().toIso8601String(),
        'prioridad': prioridad,
        'objeto_relacionado_tipo': objetoRelacionadoTipo,
        'objeto_relacionado_id': objetoRelacionadoId
      });
      debugPrint("Notificación guardada en el historial local.");
    } catch (e) {
      debugPrint("Error guardando notificación en DB: $e");
    }
  }

  // Método clásico (solo muestra la alerta, no guarda historial)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'mochilalista_channel_1', 
      'Alertas de Negocio', 
      channelDescription: 'Notificaciones generales.',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF1E88E5),
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id, title, body, platformChannelSpecifics, payload: payload);
  }
}