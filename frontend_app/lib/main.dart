import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // Il dizionario per il calendario in italiano!

// Importiamo la nostra Home Page centrale (Hub Gestionale)
import 'screens/dashboard.dart'; 

void main() async {
  // 1. Assicura che il motore di Flutter sia pronto prima di fare caricamenti esterni
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 2. Carica i formati delle date in italiano per risolvere l'errore del Calendario
  await initializeDateFormatting('it_IT', null); 
  
  // 3. Avvia l'applicazione
  runApp(const PanificioApp()); 
}

class PanificioApp extends StatelessWidget {
  const PanificioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panificio IA',
      // Nasconde la fascetta rossa "DEBUG" in alto a destra
      debugShowCheckedModeBanner: false, 
      
      theme: ThemeData(
        // Il colore tema del nostro gestionale
        primarySwatch: Colors.orange,
        
        // Impostiamo un design moderno per i bottoni e i menu di tutta l'app
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      
      // La pagina di partenza è la nostra Dashboard a griglia!
      home: const DashboardHomePage(),
    );
  }
}