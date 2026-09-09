import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'nuova_ricetta_manuale.dart';
import 'dettaglio_ricetta.dart';

class PaginaRicette extends StatefulWidget {
  const PaginaRicette({super.key});

  @override
  State<PaginaRicette> createState() => _PaginaRicetteState();
}

class _PaginaRicetteState extends State<PaginaRicette> {
  // MEMORIA VUOTA: Niente più esempi finti! Li scaricheremo da MySQL
  List<Map<String, dynamic>> _listaRicette = [];
  bool _staCaricando = true;

  @override
  void initState() {
    super.initState();
    _scaricaRicette(); 
  }

  // --- API: SCARICA LE RICETTE DAL DATABASE (GET) ---
  Future<void> _scaricaRicette() async {
    setState(() => _staCaricando = true);
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/ricette'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          setState(() {
            _listaRicette.clear();
            for (var r in datiTradotti['dati']) {
              // Estraiamo il pacchetto JSON completo salvato nel DB
              var datiJson = r['dati_json'] ?? {};
              
              _listaRicette.add({
                'id': r['id'],
                'nome': r['nome_ricetta'] ?? datiJson['nome'] ?? 'Senza Nome',
                'resa_kg': r['resa_kg'],
                'metodo': datiJson['metodo'] ?? 'Salvata nel DB',
                'ingredienti': (datiJson['lista_ingredienti'] as List?)?.length ?? 0,
                'fasi': (datiJson['lista_fasi'] as List?)?.length ?? 0,
                'lista_ingredienti': datiJson['lista_ingredienti'] ?? [],
                'lista_fasi': datiJson['lista_fasi'] ?? [],
                'resa_quantita': datiJson['resa_quantita']?.toString() ?? r['resa_kg'].toString(),
                'resa_unita': datiJson['resa_unita'] ?? 'Kg',
              });
            }
            _staCaricando = false;
          });
        }
      }
    } catch (e) {
      print("Errore GET Ricette: $e");
      setState(() => _staCaricando = false);
    }
  }

  // --- API: ELIMINA RICETTA (DELETE) ---
  Future<void> _eliminaRicetta(int idRicetta) async {
    setState(() => _staCaricando = true);
    try {
      final risposta = await http.delete(Uri.parse('http://127.0.0.1:8000/ricette/$idRicetta'));
      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ricetta eliminata dal database!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Errore DELETE Ricetta: $e");
    }
    await _scaricaRicette(); // Ricarichiamo la lista pulita
  }

  // --- API: SALVA/AGGIORNA RICETTA (POST / PUT) ---
  Future<void> _salvaRicettaSulServer(Map<String, dynamic> pacchettoDart, {int? idEsistente}) async {
    setState(() => _staCaricando = true);
    try {
      // Adattiamo i dati per il vigilante in Python (RicettaDati)
      Map<String, dynamic> payloadPerPython = {
        "nome_ricetta": pacchettoDart['nome'] ?? 'Nuova Ricetta',
        "resa_kg": double.tryParse(pacchettoDart['resa_quantita'].toString()) ?? 0.0,
        "dati_json": pacchettoDart 
      };

      http.Response risposta;
      String corpoJson = json.encode(payloadPerPython);
      Map<String, String> intestazioni = {"Content-Type": "application/json"};

      if (idEsistente == null) {
        // Nuova ricetta
        risposta = await http.post(Uri.parse('http://127.0.0.1:8000/ricette'), headers: intestazioni, body: corpoJson);
      } else {
        // Modifica ricetta esistente
        risposta = await http.put(Uri.parse('http://127.0.0.1:8000/ricette/$idEsistente'), headers: intestazioni, body: corpoJson);
      }

      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ricetta salvata nel Database!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("Errore Salvataggio Ricetta: $e");
    }
    await _scaricaRicette();
  }

  // --- LETTURA PDF E IA ---
  Future<void> _caricaDocumento() async {
    var risultato = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc'],
      withData: true, 
    );

    if (risultato != null && risultato.files.isNotEmpty) {
      var fileSelezionato = risultato.files.single;
      String nomeFile = fileSelezionato.name;
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invio di "$nomeFile" all\'IA in corso...'), backgroundColor: Colors.blue, duration: const Duration(seconds: 4)),
      );

      try {
        var uri = Uri.parse('http://127.0.0.1:8000/analizza_documento');
        var request = http.MultipartRequest('POST', uri);
        if (fileSelezionato.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', fileSelezionato.bytes!, filename: nomeFile));
        }

        var rispostaStream = await request.send();
        var risposta = await http.Response.fromStream(rispostaStream);

        if (risposta.statusCode == 200) {
          var datiTradotti = json.decode(risposta.body);
          if (datiTradotti['successo'] == true) {
            Map<String, dynamic> ricettaIA = datiTradotti['dati_ia'];
            
            if (!mounted) return;

            // L'IA ha finito! Apriamo il modulo manuale per la conferma
            final ricettaConfermata = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PaginaNuovaRicettaManuale(ricettaDaModificare: ricettaIA)),
            );

            // SE CONFERMATA, SALVIAMO NEL DB (POST)
            if (ricettaConfermata != null) {
              await _salvaRicettaSulServer(ricettaConfermata);
            }
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore IA: ${datiTradotti["errore"]}'), backgroundColor: Colors.red));
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore di connessione col server.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Ricette'), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ricettario del Panificio', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Modulo per una ricetta vuota
                      final ricettaRestituita = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PaginaNuovaRicettaManuale()));
                      if (ricettaRestituita != null) {
                        await _salvaRicettaSulServer(ricettaRestituita);
                      }
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Manuale'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _caricaDocumento, 
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Da PDF/DOCX'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade200, foregroundColor: Colors.orange.shade900, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            const Text('Ricette Salvate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: _staCaricando 
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _listaRicette.isEmpty
                  ? const Center(child: Text("Il tuo ricettario è vuoto. Inserisci la prima ricetta!", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)))
                  : ListView.builder(
                  itemCount: _listaRicette.length,
                  itemBuilder: (context, index) {
                    final ricetta = _listaRicette[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () async {
                          // APRIAMO IL DETTAGLIO. Se l'utente preme "Modifica" dentro al dettaglio e salva, ci ritornerà i dati aggiornati
                          final ricettaAggiornata = await Navigator.push(context, MaterialPageRoute(builder: (context) => PaginaDettaglioRicetta(ricetta: ricetta)));
                          
                          if (ricettaAggiornata != null) {
                            // Aggiorniamo la ricetta esistente passando l'ID (PUT)
                            await _salvaRicettaSulServer(ricettaAggiornata, idEsistente: ricetta['id']);
                          }
                        },
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: const Icon(Icons.bakery_dining, color: Colors.orange)),
                          title: Text(ricetta['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Ingredienti: ${ricetta['ingredienti']} | Fasi: ${ricetta['fasi']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminaRicetta(ricetta['id']), // ELIMINAZIONE REALE DA MYSQL
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