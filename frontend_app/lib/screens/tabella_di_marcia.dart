import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaginaTabellaDiMarcia extends StatefulWidget {
  const PaginaTabellaDiMarcia({super.key});

  @override
  State<PaginaTabellaDiMarcia> createState() => _PaginaTabellaDiMarciaState();
}

class _PaginaTabellaDiMarciaState extends State<PaginaTabellaDiMarcia> {
  // Memoria
  List<Map<String, dynamic>> _tabella = [];
  bool _staCaricando = true; 
  String? _messaggioIA;

  @override
  void initState() {
    super.initState();
    _calcolaTurniIA(); // Parte in automatico appena apri la pagina!
  }

  // Chiama il Python
  Future<void> _calcolaTurniIA() async {
    setState(() {
      _staCaricando = true;
      _messaggioIA = null;
      _tabella.clear();
    });

    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/calcola_turni'));
      
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        
        setState(() {
          _staCaricando = false;
          
          if (datiTradotti['successo'] == true) {
            if (datiTradotti['tabella'] != null && datiTradotti['tabella'].isNotEmpty) {
              _tabella = List<Map<String, dynamic>>.from(datiTradotti['tabella']);
              _tabella.sort((a, b) => (a['minuto_inizio'] as int).compareTo(b['minuto_inizio'] as int));
            } else {
              _messaggioIA = datiTradotti['messaggio']; 
            }
          } else {
            // Se fallisce o l'IA interviene, mostra il messaggio
            _messaggioIA = datiTradotti['messaggio'] ?? datiTradotti['errore'];
          }
        });
      }
    } catch (e) {
      setState(() {
        _staCaricando = false;
        _messaggioIA = "Errore di connessione a Python. Assicurati che api.py sia avviato nel terminale!";
      });
    }
  }

  // Trasforma i minuti in "HH:MM"
  String _formattaOrario(int minutiAssoluti) {
    int ore = (minutiAssoluti ~/ 60) % 24;
    int minuti = minutiAssoluti % 60;
    return "${ore.toString().padLeft(2, '0')}:${minuti.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabella di Marcia IA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_staCaricando)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.black87),
                      SizedBox(height: 20),
                      Text(
                        "L'IA e OR-Tools stanno calcolando gli incastri...\nPotrebbe volerci qualche secondo.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey, fontStyle: FontStyle.italic),
                      )
                    ],
                  ),
                ),
              )
            else if (_messaggioIA != null)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _messaggioIA!.contains('🤖') ? Colors.orange.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _messaggioIA!.contains('🤖') ? Colors.orange : Colors.blue, width: 2)
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _messaggioIA!.contains('🤖') ? Icons.warning_amber_rounded : Icons.info_outline, 
                          size: 60, 
                          color: _messaggioIA!.contains('🤖') ? Colors.orange : Colors.blue
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _messaggioIA!, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 25),
                        if (_messaggioIA!.contains('🤖'))
                          ElevatedButton.icon(
                            onPressed: _calcolaTurniIA,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Ricalcola Ora", style: TextStyle(fontSize: 18)),
                          )
                      ],
                    ),
                  ),
                ),
              )
            else if (_tabella.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Ottimizzazione riuscita! Ordini processati e rimossi dal DB.", 
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)
                      )
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _tabella.length,
                  itemBuilder: (context, index) {
                    final task = _tabella[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.black12, width: 1), 
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.schedule, color: Colors.white, size: 30),
                        ),
                        title: Text(task['attivita'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        subtitle: Text("Macchinario: ${task['macchinario']}", style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400)
                          ),
                          child: Text(
                            "${_formattaOrario(task['minuto_inizio'])} - ${_formattaOrario(task['minuto_fine'])}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}