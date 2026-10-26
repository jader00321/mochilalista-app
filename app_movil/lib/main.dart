import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Utilidades y Seguridad
import 'package:app_movil/core/utils/backup_manager.dart';

// Providers Principales
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart'; 
import 'package:app_movil/features/catalog/providers/inventory_provider.dart'; 
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/providers/printer_provider.dart';
import 'package:app_movil/features/scanner/providers/invoice_provider.dart'; 
import 'package:app_movil/features/profile/providers/team_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart'; 

// Providers de Features
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/manual_quote_provider.dart'; 
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart'; 
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';

// Screens Principales de Navegación y Seguridad
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';

import 'package:app_movil/features/profile/services/business_backup_service.dart';

// =========================================================================
// 🔥 TAREA EN SEGUNDO PLANO (WORKMANAGER) PARA BACKUPS AUTOMÁTICOS
// Esta función debe estar obligatoriamente fuera de cualquier clase.
// =========================================================================
const String backupTask = "monthlyBackupTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backupTask) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final bool isEnabled = prefs.getBool('auto_backup_enabled') ?? false;
        
        if (isEnabled) {
          final String location = prefs.getString('auto_backup_location') ?? 'Local';
          final String type = prefs.getString('auto_backup_type') ?? 'global';
          final String? customPath = prefs.getString('auto_backup_custom_path');
          
          bool doGlobal = type == 'global' || type == 'ambos';
          bool doPerfil = type == 'perfil' || type == 'ambos';
          
          if (doGlobal) {
            if (location == 'custom' && customPath != null) {
              await BackupManager.exportToDirectory(customPath);
            } else {
              await BackupManager.exportToDownloads();
            }
          }
          
          if (doPerfil) {
             final int? negocioId = prefs.getInt('auto_backup_negocio_id');
             final String? negocioNombre = prefs.getString('auto_backup_negocio_nombre');
             if (negocioId != null && negocioNombre != null) {
                String? targetDir = (location == 'custom') ? customPath : null;
                await BusinessBackupService.exportBusinessToFile(negocioId, negocioNombre, targetDirectory: targetDir);
             }
          }
        }
        
        // Registrar éxito
        await prefs.setInt('last_auto_backup_run_time', DateTime.now().millisecondsSinceEpoch);
        
      } catch (e) {
        debugPrint("Error en tarea de backup automático: $e");
      }
    }
    return Future.value(true);
  });
}

void main() async { 
  WidgetsFlutterBinding.ensureInitialized(); 
  await dotenv.load(fileName: ".env"); 
  await initializeDateFormatting('es', null);

  // 🔥 INICIALIZAR WORKMANAGER
  // La tarea solo se registra mediante el BackupProvider cuando el usuario activa la opción
  Workmanager().initialize(
    callbackDispatcher
  );

  runApp(const MochilaListaApp());
}

class MochilaListaApp extends StatelessWidget {
  const MochilaListaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => BackupProvider()), 
        
        ChangeNotifierProxyProvider<AuthProvider, MatchingProvider>(
          create: (_) => MatchingProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId, auth.token)
        ), 
        ChangeNotifierProxyProvider<AuthProvider, QuickSaleProvider>(
          create: (_) => QuickSaleProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId)
        ), 
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, usuarioId: auth.activeUserId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, SmartQuotationProvider>(
          create: (_) => SmartQuotationProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId, auth.token)
        ),
        ChangeNotifierProxyProvider<AuthProvider, ScannerProvider>(
          create: (_) => ScannerProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId, auth.token)
        ),
        ChangeNotifierProxyProvider<AuthProvider, InventoryProvider>(
          create: (_) => InventoryProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, CatalogProvider>(
          create: (_) => CatalogProvider(), 
          // 🔥 AQUÍ ESTABA EL ERROR QUE AHORA ESTÁ CORREGIDO
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, WorkbenchProvider>(
          create: (_) => WorkbenchProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, SaleProvider>(
          create: (_) => SaleProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, TrackingProvider>(
          create: (_) => TrackingProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId, auth.activeUserId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, ManualQuoteProvider>(
          create: (_) => ManualQuoteProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
        ),

        ChangeNotifierProxyProvider<AuthProvider, PromotionProvider>(
          create: (_) => PromotionProvider(),
          update: (context, auth, prov) {
             final p = prov ?? PromotionProvider();
             final inventory = Provider.of<InventoryProvider>(context, listen: false);
             p.updateContext(auth.activeBusinessId ?? 0, inventory);
             return p;
          }
        ),
        ChangeNotifierProxyProvider<AuthProvider, QuickSearchProvider>(
          create: (_) => QuickSearchProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, AnalyticsProvider>(
          create: (_) => AnalyticsProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, InvoiceProvider>(
          create: (_) => InvoiceProvider(), 
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
        ),
        ChangeNotifierProxyProvider<AuthProvider, TeamProvider>(
          create: (_) => TeamProvider(), 
          update: (_, auth, team) => team!..updateContext(auth.activeBusinessId)
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'MochilaLista',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode, 
            locale: const Locale('es', 'ES'),
            supportedLocales: const [
              Locale('es', 'ES'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ], 
            
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              useMaterial3: true,
              textTheme: ThemeProvider.appTextTheme.apply(bodyColor: Colors.black87, displayColor: Colors.black87),
            ),

            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF42A5F5), 
                brightness: Brightness.dark, 
                surface: const Color(0xFF1E1E28),
              ),
              scaffoldBackgroundColor: const Color(0xFF12121A), 
              useMaterial3: true,
              cardTheme: CardThemeData(
                color: const Color(0xFF1E1E28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10, width: 1),
                ),
                elevation: 0,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF12121A), 
                foregroundColor: Colors.white, 
                elevation: 0
              ),
              textTheme: ThemeProvider.appTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
            ),

            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.status == AuthStatus.checking) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                
                if (auth.status == AuthStatus.profileSelection) {
                  return const ProfileSelectionScreen();
                }
                
                if (auth.status == AuthStatus.authenticated && auth.user != null) {
                  if (auth.hasPinCache) {
                    return LockScreen(userId: auth.user!.id); 
                  } else {
                    return const HomeScreen(); 
                  }
                }
                
                return const ProfileSelectionScreen();
              },
            ),
          );
        },
      ),
    );
  }
}