import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

// Providers Principales
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart'; 
import 'providers/inventory_provider.dart'; 
import 'providers/scanner_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/invoice_provider.dart'; 
import 'providers/team_provider.dart'; // 🔥 FASE 4: PROVIDER DE EQUIPO

// Providers de Features
import 'features/smart_quotation/providers/smart_quotation_provider.dart';
import 'features/smart_quotation/providers/matching_provider.dart';
import 'features/smart_quotation/providers/workbench_provider.dart';
import 'features/smart_quotation/providers/sale_provider.dart';
import 'features/smart_quotation/providers/tracking_provider.dart';
import 'features/smart_quotation/providers/manual_quote_provider.dart'; 
import 'features/smart_quotation/providers/quick_sale_provider.dart'; 
import 'features/smart_quotation/providers/quick_search_provider.dart';

// Screens Principales
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized(); 
  await dotenv.load(fileName: ".env"); 
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
        ChangeNotifierProvider(create: (_) => MatchingProvider()), 
        ChangeNotifierProvider(create: (_) => QuickSaleProvider()), 
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(create: (_) => NotificationProvider(), update: (_, auth, notif) => notif!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, SmartQuotationProvider>(create: (_) => SmartQuotationProvider(), update: (_, auth, provider) => provider!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, ScannerProvider>(create: (_) => ScannerProvider(), update: (_, auth, scanner) => scanner!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, InventoryProvider>(create: (_) => InventoryProvider(), update: (_, auth, inv) => inv!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, CatalogProvider>(create: (_) => CatalogProvider(), update: (_, auth, cat) => cat!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, WorkbenchProvider>(create: (_) => WorkbenchProvider(), update: (_, auth, wb) => wb!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, SaleProvider>(create: (_) => SaleProvider(), update: (_, auth, sale) => sale!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, TrackingProvider>(create: (_) => TrackingProvider(), update: (_, auth, track) => track!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, ManualQuoteProvider>(create: (_) => ManualQuoteProvider(), update: (_, auth, mq) => mq!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, QuickSearchProvider>(create: (_) => QuickSearchProvider(), update: (_, auth, qs) => qs!..updateToken(auth.token)),
        ChangeNotifierProxyProvider<AuthProvider, InvoiceProvider>(create: (_) => InvoiceProvider(), update: (_, auth, inv) => inv!..updateToken(auth.token)),
        
        // 🔥 FASE 4: INYECCIÓN DE TEAM PROVIDER CORREGIDA
        ChangeNotifierProxyProvider<AuthProvider, TeamProvider>(
          create: (_) => TeamProvider(), 
          update: (_, auth, team) => team!
            ..updateToken(auth.token)
            ..onAuthRevoked = () => auth.clearContext(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'MochilaLista',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode, 
            
            // TEMA CLARO 
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              useMaterial3: true,
              textTheme: ThemeProvider.appTextTheme.apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
            ),

            // TEMA NOCHE (Suave y Profesional)
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF42A5F5), 
                brightness: Brightness.dark,
                surface: const Color(0xFF23232F), 
              ),
              scaffoldBackgroundColor: const Color(0xFF14141C), 
              useMaterial3: true,
              cardTheme: const CardThemeData(color: Color(0xFF23232F)),
              appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF14141C), foregroundColor: Colors.white, elevation: 0),
              textTheme: ThemeProvider.appTextTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),

            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.status == AuthStatus.checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                if (auth.isAuthenticated) return const HomeScreen();
                return const LoginScreen(); 
              },
            ),
          );
        },
      ),
    );
  }
}