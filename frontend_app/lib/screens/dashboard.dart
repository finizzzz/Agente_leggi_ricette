import 'package:flutter/material.dart';
import 'gestione_macchinari.dart';
import 'gestione_ricette.dart';
import 'gestione_dipendenti.dart';
import 'gestione_ordini.dart';

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  // Un piccolo modulo per costruire i "quadrati" del menu
  Widget _costruisciBottoneMenu(BuildContext context, String titolo, IconData icona, Color colore, Widget paginaDestinazione) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => paginaDestinazione));
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, size: 60, color: colore),
            const SizedBox(height: 15),
            Text(titolo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panificio IA - Hub Gestionale', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Benvenuto!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text('Scegli il reparto da gestire:', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 30),
            
            // Usiamo Expanded per far prendere alla griglia tutto lo spazio disponibile
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2 colonne perfette per il tablet
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _costruisciBottoneMenu(context, 'Macchinari', Icons.precision_manufacturing, Colors.blueGrey, const PaginaMacchinari()),
                  _costruisciBottoneMenu(context, 'Ricette', Icons.menu_book, Colors.teal, const PaginaRicette()),
                  _costruisciBottoneMenu(context, 'Dipendenti & Turni', Icons.people_alt, Colors.indigo, const PaginaDipendenti()),
                  _costruisciBottoneMenu(context, 'Ordini', Icons.shopping_cart_checkout, Colors.orange, const PaginaGestioneOrdini()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}