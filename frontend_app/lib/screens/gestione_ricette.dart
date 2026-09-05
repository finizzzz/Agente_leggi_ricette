import 'package:flutter/material.dart';
import 'nuova_ricetta_manuale.dart';
import 'dettaglio_ricetta.dart';

class PaginaRicette extends StatefulWidget {
  const PaginaRicette({super.key});

  @override
  State<PaginaRicette> createState() => _PaginaRicetteState();
}

class _PaginaRicetteState extends State<PaginaRicette> {
  // Il nostro database fittizio aggiornato! Ora la Ciabatta ha ingredienti e fasi REALI al suo interno.
  final List<Map<String, dynamic>> _listaRicette = [
    {
      'nome': 'Ciabatta Artigianale con Biga', 
      'metodo': 'Manuale', 
      'ingredienti': 2, 
      'fasi': 1,
      // Questi sono i dati veri che la Modalità Modifica andrà a pescare!
      'lista_ingredienti': [
        {'nome': 'Farina Tipo 1', 'quantita': '5', 'unita': 'Kg'},
        {'nome': 'Acqua', 'quantita': '3.5', 'unita': 'L'}
      ],
      'lista_fasi': [
        {'nome_fase': 'Impasto Biga', 'macchinario': 'Impastatrice a spirale', 'tempo_minuti': '15'}
      ]
    },
    {'nome': 'Pane di Segale', 'metodo': 'PDF', 'ingredienti': 4, 'fasi': 3},
    {'nome': 'Filone Integrale', 'metodo': 'Manuale', 'ingredienti': 6, 'fasi': 5},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Ricette'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ricettario del Panificio',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            
            // --- I BOTTONI PER AGGIUNGERE RICETTE ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PaginaNuovaRicettaManuale()),
                      );
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Manuale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print("Caricamento PDF avviato...");
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Da PDF/DOCX'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade200,
                      foregroundColor: Colors.orange.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            const Text(
              'Ricette Salvate',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // --- LA LISTA DELLE RICETTE CLICCABILI (CON CESTINO) ---
            Expanded(
              child: ListView.builder(
                itemCount: _listaRicette.length,
                itemBuilder: (context, index) {
                  final ricetta = _listaRicette[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 15),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaginaDettaglioRicetta(ricetta: ricetta),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.bakery_dining, color: Colors.orange),
                        ),
                        title: Text(ricetta['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Inserita via: ${ricetta['metodo']}'),
                        
                        // IL NOSTRO NUOVO CESTINO ELIMINA RICETTA!
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _listaRicette.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}