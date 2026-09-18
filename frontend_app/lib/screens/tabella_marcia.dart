import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaginaTabellaDiMarcia extends StatefulWidget {
  const PaginaTabellaDiMarcia({super.key});

  @override
  State<PaginaTabellaDiMarcia> createState() => _PaginaTabellaDiMarciaState();
}

class _PaginaTabellaDiMarciaState extends State<PaginaTabellaDiMarcia> {
  List<Map<String, dynamic>> _taskTotali = [];
  bool _staCaricando = true;
  String? _messaggioIA;

  @override
  void initState() {
    super.initState();
    _calcolaTurniIA();
  }

  Future<void> _calcolaTurniIA() async {
    setState(() {
      _staCaricando = true;
      _messaggioIA = null;
      _taskTotali.clear();
    });

try {
      // ORA USIAMO HTTP.POST! Chrome non oserà mai più bloccare la richiesta!
      final risposta = await http.post(
        Uri.parse('http://127.0.0.1:8000/calcola_turni'),
      );

      setState(() {
        _staCaricando = false; 
        // ... (il resto del codice rimane identico)
        if (risposta.statusCode == 200) {
          final datiTradotti = json.decode(risposta.body);
          
          if (datiTradotti['successo'] == true) {
            if (datiTradotti['tabella'] != null && datiTradotti['tabella'].isNotEmpty) {
              _taskTotali = List<Map<String, dynamic>>.from(datiTradotti['tabella']).map((task) {
                
                // Leggiamo il VERO DIPENDENTE calcolato da OR-Tools!
                String dipendenteReale = task['dipendente'] ?? "Dipendente Generico";
                
                return {
                  ...task,
                  'dipendente': dipendenteReale,
                  'completato': false,
                };
              }).toList();
              
              _taskTotali.sort((a, b) => (a['minuto_inizio'] as int).compareTo(b['minuto_inizio'] as int));
            } else {
              _messaggioIA = datiTradotti['messaggio']; 
            }
          } else {
            _messaggioIA = datiTradotti['messaggio'] ?? datiTradotti['errore'];
          }
        } else {
          _messaggioIA = "Errore del server Python (Codice: ${risposta.statusCode}). Controlla il terminale nero!";
        }
      });
    } catch (e) {
      setState(() {
        _staCaricando = false;
        _messaggioIA = "Errore di connessione a Python. Assicurati che api.py sia avviato!";
      });
    }
  }

  String _formattaOrario(int minutiAssoluti) {
    int ore = (minutiAssoluti ~/ 60) % 24;
    int minuti = minutiAssoluti % 60;
    return "${ore.toString().padLeft(2, '0')}:${minuti.toString().padLeft(2, '0')}";
  }

  // --- LA FUNZIONE DOVE C'ERA L'ERRORE (Ora corretta in _taskTotali) ---
  double get _percentualeCompletamento {
    if (_taskTotali.isEmpty) return 0.0;
    int completati = _taskTotali.where((t) => t['completato'] == true).length;
    return completati / _taskTotali.length;
  }

  List<String> get _dipendentiUnici {
    return _taskTotali.map((t) => t['dipendente'] as String).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Live KDS - Monitor Produzione', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: _staCaricando 
        ? const Center(child: CircularProgressIndicator(color: Colors.brown))
        : _messaggioIA != null
          ? _buildMessaggioIA()
          : _buildKDSInterface(),
    );
  }

  Widget _buildKDSInterface() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                "Avanzamento Turno: ${(_percentualeCompletamento * 100).toInt()}%", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              const SizedBox(width: 20),
              Expanded(
                child: LinearProgressIndicator(
                  value: _percentualeCompletamento,
                  minHeight: 15,
                  backgroundColor: Colors.orange.shade100,
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                "${_taskTotali.where((t) => t['completato']).length} / ${_taskTotali.length} Task",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey),
              )
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _dipendentiUnici.map((dipendente) {
                final taskDipendente = _taskTotali.where((t) => t['dipendente'] == dipendente).toList();
                
                return Container(
                  width: 360,
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange.shade200, width: 2)
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(13))
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              child: Text(dipendente.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(dipendente, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: taskDipendente.length,
                          itemBuilder: (context, index) {
                            final task = taskDipendente[index];
                            final bool isCompletato = task['completato'];
                            
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: isCompletato ? Colors.green : Colors.transparent, width: 2)
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(5)),
                                      child: Text(
                                        "${_formattaOrario(task['minuto_inizio'])} ➔ ${_formattaOrario(task['minuto_fine'])}",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      task['attivita'], 
                                      style: TextStyle(
                                        fontSize: 20, 
                                        fontWeight: FontWeight.bold,
                                        decoration: isCompletato ? TextDecoration.lineThrough : null,
                                        color: isCompletato ? Colors.grey : Colors.black
                                      )
                                    ),
                                    Text("Macchinario: ${task['macchinario']}", style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 15),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            task['completato'] = !isCompletato;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCompletato ? Colors.white : Colors.teal,
                                          foregroundColor: isCompletato ? Colors.teal : Colors.white,
                                          side: BorderSide(color: Colors.teal, width: isCompletato ? 2 : 0),
                                          padding: const EdgeInsets.symmetric(vertical: 15)
                                        ),
                                        icon: Icon(isCompletato ? Icons.undo : Icons.check_circle),
                                        label: Text(isCompletato ? "ANNULLA" : "COMPLETA FASE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessaggioIA() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange, width: 2)
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
            const SizedBox(height: 15),
            Text(_messaggioIA!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _calcolaTurniIA,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              icon: const Icon(Icons.refresh),
              label: const Text("Ricalcola Ora", style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}