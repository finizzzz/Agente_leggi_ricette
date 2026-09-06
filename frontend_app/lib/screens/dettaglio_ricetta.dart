import 'package:flutter/material.dart';
import 'nuova_ricetta_manuale.dart'; // Aggiunto per far viaggiare i dati!

class PaginaDettaglioRicetta extends StatelessWidget {
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

            // --- SEZIONE INFO ---
            if (ricetta['resa_quantita'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text(
                      'Resa Stimata: ${ricetta['resa_quantita']} ${ricetta['resa_unita']}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ],
                ),
              ),

            const Text(
              'Ingredienti nel dettaglio', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)
            ),
            const SizedBox(height: 10),
            
            if (ricetta['lista_ingredienti'] != null && (ricetta['lista_ingredienti'] as List).isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (ricetta['lista_ingredienti'] as List).length,
                itemBuilder: (context, index) {
                  final ing = ricetta['lista_ingredienti'][index];
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.scale, color: Colors.orange, size: 20),
                      title: Text(ing['nome'] ?? 'Sconosciuto', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('${ing['quantita']} ${ing['unita']}', style: const TextStyle(fontSize: 16)),
                    ),
                  );
                },
              )
            else
              const Text('Nessun dettaglio ingredienti disponibile.', style: TextStyle(fontStyle: FontStyle.italic)),

            const SizedBox(height: 30),
            
            const Text(
              'Procedimento e Fasi', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)
            ),
            const SizedBox(height: 10),
            
            if (ricetta['lista_fasi'] != null && (ricetta['lista_fasi'] as List).isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (ricetta['lista_fasi'] as List).length,
                itemBuilder: (context, index) {
                  final fase = ricetta['lista_fasi'][index];
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.teal,
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text(fase['nome_fase'] ?? 'Fase Sconosciuta', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Macchina: ${fase['macchinario'] ?? 'Non definita'}'),
                      trailing: Text('${fase['tempo_minuti'] ?? 0} min', style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              )
            else
              const Text('Nessun dettaglio fasi disponibile.', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
      
      // --- IL BOTTONE DI MODIFICA CHE ORA "SPEDISCE" I DATI ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Apre il modulo passandogli i dati della ricetta corrente!
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