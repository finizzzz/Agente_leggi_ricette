import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaginaNuovoOrdine extends StatefulWidget {
  const PaginaNuovoOrdine({super.key});

  @override
  State<PaginaNuovoOrdine> createState() => _PaginaNuovoOrdineState();
}

class _PaginaNuovoOrdineState extends State<PaginaNuovoOrdine> {
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController(); 
  
  TimeOfDay? _orarioConsegna;
  
  // --- NUOVE VARIABILI PER IL DATABASE DELLE RICETTE ---
  List<Map<String, dynamic>> _ricetteDisponibili = [];
  bool _staCaricandoRicette = true;
  Map<String, dynamic>? _ricettaSelezionata; // Ora salviamo l'intero "pacchetto" della ricetta
  
  // L'unico carrello ufficiale
  final List<Map<String, dynamic>> _ordiniMultipli = [];

  // All'avvio della pagina, scarichiamo le ricette vere!
  @override
  void initState() {
    super.initState();
    _scaricaRicette();
  }

  Future<void> _scaricaRicette() async {
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/ricette'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          setState(() {
            _ricetteDisponibili = List<Map<String, dynamic>>.from(datiTradotti['dati']);
            // Se c'è almeno una ricetta, selezioniamo la prima di default
            if (_ricetteDisponibili.isNotEmpty) {
              _ricettaSelezionata = _ricetteDisponibili[0];
            }
            _staCaricandoRicette = false;
          });
        }
      }
    } catch (e) {
      print("Errore scaricamento ricette: $e");
      setState(() => _staCaricandoRicette = false);
    }
  }

  // --- FUNZIONI LOGICHE ---
  Future<void> _scegliOrario() async {
    final TimeOfDay? orarioScelto = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
    );
    if (orarioScelto != null) {
      setState(() {
        _orarioConsegna = orarioScelto;
      });
    }
  }

  void _aggiungiVoce() {
    // Controlliamo anche che la ricetta sia stata effettivamente selezionata dal DB
    if (_kgController.text.isNotEmpty && _clienteController.text.isNotEmpty && _orarioConsegna != null && _ricettaSelezionata != null) {
      setState(() {
        _ordiniMultipli.add({
          'cliente': _clienteController.text,
          'orario': '${_orarioConsegna!.hour.toString().padLeft(2, '0')}:${_orarioConsegna!.minute.toString().padLeft(2, '0')}',
          'prodotto': _ricettaSelezionata!['nome_ricetta'], // Il nome ci serve per vederlo a schermo
          'ricetta_id': _ricettaSelezionata!['id'], // Questo è il vero ID che manderemo a MySQL!
          'kg': _kgController.text,
        });
        _kgController.clear(); 
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attenzione: Compila Cliente, Orario, Prodotto e Kg!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- MODULI GRAFICI ---
  Widget _costruisciSezioneCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chi è il cliente e a che ora consegniamo?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _clienteController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Es. Ristorante Bella Italia',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _scegliOrario,
              icon: const Icon(Icons.access_time),
              label: const Text('Imposta Orario'),
            ),
            const SizedBox(width: 15),
            Text(
              _orarioConsegna == null 
                  ? 'Nessun orario scelto' 
                  : '${_orarioConsegna!.hour.toString().padLeft(2, '0')}:${_orarioConsegna!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _costruisciSezioneProdotto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cosa dobbiamo preparare?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        // SE STIAMO ANCORA CARICANDO DAL DB, MOSTRIAMO LA ROTELLINA
        _staCaricandoRicette
            ? const CircularProgressIndicator(color: Colors.orange)
            : _ricetteDisponibili.isEmpty
                // SE IL DATABASE È VUOTO:
                ? const Text('Nessuna ricetta nel Database! Vai ad aggiungerne una.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                // ALTRIMENTI MOSTRIAMO IL MENU A TENDINA DINAMICO:
                : DropdownButton<Map<String, dynamic>>(
                    value: _ricettaSelezionata,
                    isExpanded: true,
                    items: _ricetteDisponibili.map((ricetta) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: ricetta,
                        child: Text(ricetta['nome_ricetta'], style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                    onChanged: (Map<String, dynamic>? nuovaScelta) {
                      setState(() {
                        _ricettaSelezionata = nuovaScelta!;
                      });
                    },
                  ),
                  
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kgController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Kg (es. 15)',
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _aggiungiVoce,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              child: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _costruisciRiepilogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Riepilogo Ordini Inseriti:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _ordiniMultipli.isEmpty 
            ? const Text('Ancora nessun prodotto aggiunto.', style: TextStyle(fontStyle: FontStyle.italic))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ordiniMultipli.length,
                itemBuilder: (context, index) {
                  final voce = _ordiniMultipli[index];
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(Icons.bakery_dining, color: Colors.orange),
                      title: Text('${voce['cliente']} - Ore ${voce['orario']}'),
                      subtitle: Text(voce['prodotto']), // Mostriamo il nome
                      trailing: Text('${voce['kg']} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inserisci Nuovo Ordine'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _costruisciSezioneCliente(),
            const Divider(height: 40, thickness: 2),
            
            _costruisciSezioneProdotto(),
            const Divider(height: 40, thickness: 2),
            
            _costruisciRiepilogo(),
            const SizedBox(height: 40),
            
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  if (_ordiniMultipli.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore: Inserisci almeno un ordine!'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invio ordini al database in corso...'), backgroundColor: Colors.orange),
                  );

                  DateTime domani = DateTime.now().add(const Duration(days: 1));
                  String dataConsegnaSql = "${domani.year}-${domani.month.toString().padLeft(2, '0')}-${domani.day.toString().padLeft(2, '0')}";

                  try {
                    bool erroreTrovato = false;
                    String messaggioErrore = "";
                    
                    for (var voce in _ordiniMultipli) {
                      var payload = {
                        "cliente": voce['cliente'],
                        // ECCO IL CAMBIAMENTO! Usiamo l'ID salvato nel carrello.
                        "ricetta_id": voce['ricetta_id'], 
                        "quantita_kg": double.parse(voce['kg'].toString().replaceAll(',', '.')),
                        "data_consegna": dataConsegnaSql,
                        "orario_consegna": "${voce['orario']}:00" 
                      };

                      final risposta = await http.post(
                        Uri.parse('http://127.0.0.1:8000/ordini'),
                        headers: {"Content-Type": "application/json"},
                        body: json.encode(payload)
                      );
                      
                      final datiDecodificati = json.decode(risposta.body);
                      if (datiDecodificati['successo'] == false) {
                        erroreTrovato = true;
                        messaggioErrore = datiDecodificati['errore'];
                        break; 
                      }
                    }

                    if (context.mounted) {
                      if (erroreTrovato) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(messaggioErrore), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tutti gli ordini salvati nel database MySQL!'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context, _ordiniMultipli);
                      }
                    }
                    
                  } catch (e) {
                    print("Errore invio ordini: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore di connessione al server!'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Salva e Invia Tutto', style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}