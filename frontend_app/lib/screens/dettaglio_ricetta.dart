import 'package:flutter/material.dart';
import 'nuova_ricetta_manuale.dart';

class PaginaDettaglioRicetta extends StatelessWidget {
  // Questa variabile è la "scatola" che riceverà i dati della ricetta cliccata
  final Map<String, dynamic> ricetta;

  const PaginaDettaglioRicetta({super.key, required this.ricetta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Ricetta'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- INTESTAZIONE ---
            Row(
              children: [
                const Icon(Icons.menu_book, size: 40, color: Colors.teal),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    ricetta['nome'] ?? 'Nome non disponibile',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Inserita tramite: ${ricetta['metodo']}', 
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic)
            ),
            
            const Divider(height: 40, thickness: 2),

            // --- SEZIONE INFO (Per ora mostriamo i dati fittizi del nostro mock database) ---
            const Text(
              'Ingredienti Registrati', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.scale, color: Colors.orange),
                title: Text('Numero di ingredienti: ${ricetta['ingredienti']}'),
                subtitle: const Text('I dettagli specifici appariranno qui quando collegheremo il database.'),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Procedimento e Fasi', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.orange),
                title: Text('Fasi (step) previste: ${ricetta['fasi']}'),
                subtitle: const Text('I tempi e i macchinari appariranno qui quando collegheremo il database.'),
              ),
            ),
          ],
        ),
      ),
      
// --- IL BOTTONE DI MODIFICA ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Usiamo il Navigatore per aprire il modulo manuale, 
          // passandogli la "ricetta" corrente come pacchetto!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaNuovaRicettaManuale(ricettaDaModificare: ricetta),
            ),
          );
        },
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('Modifica', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}