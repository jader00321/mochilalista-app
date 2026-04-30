import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Utilidades y Seguridad
import 'utils/backup_manager.dart';

// Providers Principales
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart'; 
import 'providers/inventory_provider.dart'; 
import 'providers/scanner_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/invoice_provider.dart'; 
import 'providers/team_provider.dart';
import 'providers/backup_provider.dart'; 

// Providers de Features
import 'features/smart_quotation/providers/smart_quotation_provider.dart';
import 'features/smart_quotation/providers/matching_provider.dart';
import 'features/smart_quotation/providers/workbench_provider.dart';
import 'features/smart_quotation/providers/sale_provider.dart';
import 'features/smart_quotation/providers/tracking_provider.dart';
import 'features/smart_quotation/providers/manual_quote_provider.dart'; 
import 'features/smart_quotation/providers/quick_sale_provider.dart'; 
import 'features/smart_quotation/providers/quick_search_provider.dart';

// Screens Principales de Navegación y Seguridad
import 'screens/home_screen.dart';
import 'screens/onboarding/profile_selection_screen.dart';
import 'screens/onboarding/lock_screen.dart';

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
          
          if (location == 'Drive') {
            await BackupManager.exportToGoogleDrive();
          } else {
            await BackupManager.exportToDownloads();
          }
        }
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

  // 🔥 INICIALIZAR WORKMANAGER Y PROGRAMAR TAREA
  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: false // Cambiar a true solo para ver logs de depuración
  );

  Workmanager().registerPeriodicTask(
    "backup_periodico_app", // ID único de la tarea
    backupTask,
    frequency: const Duration(days: 30), // Por defecto, luego el provider lo sobreescribe
    initialDelay: const Duration(minutes: 10), // Empieza 10 min después del primer inicio
    constraints: Constraints(
      networkType: NetworkType.connected, // Asegura que haya internet por si es en Drive
      requiresBatteryNotLow: true, // No molestará si el dueño tiene poca batería
    ),
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
          update: (_, auth, prov) => prov!..updateContext(auth.activeBusinessId)
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
        ChangeNotifierProxyProvider<AuthProvider, QuickSearchProvider>(
          create: (_) => QuickSearchProvider(), 
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
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF42A5F5), brightness: Brightness.dark, surface: const Color(0xFF23232F)),
              scaffoldBackgroundColor: const Color(0xFF14141C), 
              useMaterial3: true,
              cardTheme: const CardThemeData(color: Color(0xFF23232F)),
              appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF14141C), foregroundColor: Colors.white, elevation: 0),
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
                  return FutureBuilder<bool>(
                    future: auth.profileHasPin(auth.user!.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      
                      final hasPin = snapshot.data!;
                      if (hasPin) {
                        return LockScreen(userId: auth.user!.id); 
                      } else {
                        return const HomeScreen(); 
                      }
                    },
                  );
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