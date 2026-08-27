import 'package:flutter/material.dart';
// Importiamo le schermate per poterci "viaggiare"
import 'nuovo_ordine.dart';
import 'tabella_marcia.dart';

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Panificio IA'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaginaNuovoOrdine()),
                );
              },
              child: const Text('Inserisci Nuovo Ordine', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaginaTabellaDiMarcia()),
                );
              },
              child: const Text('Calcola Turni (IA)', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}