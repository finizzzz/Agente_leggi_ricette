import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // I DIZIONARI UFFICIALI!
import 'screens/dashboard.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await initializeDateFormatting('it_IT', null); 
  runApp(const PanificioApp()); 
}

class PanificioApp extends StatelessWidget {
  const PanificioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panificio IA',
      debugShowCheckedModeBanner: false, 
      
      // --- LE REGOLE DI TRADUZIONE GLOBALI ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'), // Diciamo a Flutter che parliamo solo italiano
      ],
      
      theme: ThemeData(
        primarySwatch: Colors.orange,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      
      home: const DashboardHomePage(),
    );
  }
}