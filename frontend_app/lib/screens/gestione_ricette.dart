import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // BENTORNATO FILE PICKER!
import 'nuova_ricetta_manuale.dart';
import 'dettaglio_ricetta.dart';

class PaginaRicette extends StatefulWidget {
  const PaginaRicette({super.key});

  @override
  State<PaginaRicette> createState() => _PaginaRicetteState();
}

class _PaginaRicetteState extends State<PaginaRicette> {
  // Le nostre 3 ricette di prova, con la Ciabatta pronta per la Modalità Modifica!
  final List<Map<String, dynamic>> _listaRicette = [
    {
      'nome': 'Ciabatta Artigianale con Biga', 
      'metodo': 'Manuale', 
      'ingredienti': 2, 
      'fasi': 1,
      // --- AGGIUNTO: I DATI DELLA RESA ---
      'resa_quantita': '15',
      'resa_unita': 'Kg',
      // -----------------------------------
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

// --- FUNZIONE 1: CARICA FILE E COLLEGAMENTO (SIMULATO) ALL'IA ---
  Future<void> _caricaDocumento() async {
    // 1. Scegliamo il file
    var risultato = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc'],
    );

    if (risultato != null && risultato.files.isNotEmpty) {
      String nomeFile = risultato.files.single.name;
      
      if (!mounted) return;

      // 2. Avvisiamo che l'IA sta lavorando
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lettura di "$nomeFile"... L\'Agente IA sta estraendo i dati!'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      // 3. Simuliamo il tempo di calcolo dello script Python (Gemini)
      await Future.delayed(const Duration(seconds: 2));

      // 4. TRADUZIONE: Ecco il pacchetto formattato esattamente come lo 
      // restituirà la nostra IA in Python, convertito nello standard manuale!
      Map<String, dynamic> ricettaEstrattaDallIA = {
        'nome': nomeFile.replaceAll(".pdf", "").replaceAll(".docx", ""),
        'metodo': 'IA da PDF',
        'resa_quantita': '8.2', // L'IA stima la resa calcolando il calo peso!
        'resa_unita': 'Kg',
        'lista_ingredienti': [
          {'nome': 'Farina Tipo 1', 'quantita': '5', 'unita': 'Kg'},
          {'nome': 'Acqua', 'quantita': '3.5', 'unita': 'L'},
          {'nome': 'Lievito Fresco', 'quantita': '50', 'unita': 'g'}
        ],
        'lista_fasi': [
          {'nome_fase': 'Impasto Biga', 'macchinario': 'Impastatrice a spirale', 'tempo_minuti': '15'},
          {'nome_fase': 'Lievitazione', 'macchinario': 'Cella di lievitazione', 'tempo_minuti': '960'},
          {'nome_fase': 'Cottura', 'macchinario': 'Forno a piani', 'tempo_minuti': '35'}
        ]
      };

      if (!mounted) return;

      // 5. LA MAGIA: Invece di salvare ciecamente, apriamo il modulo manuale 
      // passandogli i dati dell'IA per farli controllare al Panettiere!
      final ricettaConfermata = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaNuovaRicettaManuale(ricettaDaModificare: ricettaEstrattaDallIA),
        ),
      );

      // 6. Se hai controllato e premuto "Aggiorna/Salva Ricetta"
      if (ricettaConfermata != null) {
        setState(() {
          _listaRicette.add(ricettaConfermata);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ricetta dell\'IA verificata e salvata nel Ricettario!'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

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
                    // Aggiungiamo 'async' perché dovremo 'aspettare' un risultato
                    onPressed: () async {
                      
                      // Usiamo 'await' per aspettare che la pagina si chiuda e ci restituisca il pacchetto
                      final ricettaRestituita = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PaginaNuovaRicettaManuale()),
                      );

                      // Se il pacchetto NON è vuoto (cioè se non sei tornato indietro senza salvare)...
                      if (ricettaRestituita != null) {
                        setState(() {
                          // ...Aggiungiamo la nuova ricetta alla nostra lista!
                          _listaRicette.add(ricettaRestituita);
                        });
                      }
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
                    // ABBIAMO RICOLLEGATO IL BOTTONE ALLA FUNZIONE!
                    onPressed: _caricaDocumento, 
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