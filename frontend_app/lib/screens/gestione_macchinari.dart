import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

class PaginaMacchinari extends StatefulWidget {
  const PaginaMacchinari({super.key});

  @override
  State<PaginaMacchinari> createState() => _PaginaMacchinariState();
}

class _PaginaMacchinariState extends State<PaginaMacchinari> {
  // 1. LA MEMORIA E LO STATO
  List<Map<String, dynamic>> _listaMacchinari = [];
  bool _staCaricando = true; 
  String _criterioOrdinamento = 'Nome (A-Z)';

  @override
  void initState() {
    super.initState();
    _scaricaMacchinari(); 
  }

  // --- LE 4 FUNZIONI DI COMUNICAZIONE CON PYTHON ---

  // LETTURA (GET)
  Future<void> _scaricaMacchinari() async {
    setState(() => _staCaricando = true);
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/macchinari'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          setState(() {
            _listaMacchinari = List<Map<String, dynamic>>.from(datiTradotti['dati']);
            _ordinaMacchinari(_criterioOrdinamento); 
            _staCaricando = false;
          });
        }
      }
    } catch (e) {
      print("Errore GET: $e");
      setState(() => _staCaricando = false);
    }
  }

  // ELIMINAZIONE (DELETE)
  Future<void> _eliminaMacchinario(int idMacchina) async {
    try {
      final risposta = await http.delete(Uri.parse('http://127.0.0.1:8000/macchinari/$idMacchina'));
      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Macchinario rottamato!'), backgroundColor: Colors.red));
        _scaricaMacchinari(); 
      }
    } catch (e) {
      print("Errore DELETE: $e");
    }
  }

  // SALVATAGGIO (POST se nuovo, PUT se modifica)
  Future<void> _salvaMacchinaSulServer(Map<String, dynamic> dati, {int? idEsistente}) async {
    try {
      http.Response risposta;
      String corpoJson = json.encode(dati);
      Map<String, String> intestazioni = {"Content-Type": "application/json"};

      if (idEsistente == null) {
        risposta = await http.post(
          Uri.parse('http://127.0.0.1:8000/macchinari'),
          headers: intestazioni,
          body: corpoJson,
        );
      } else {
        risposta = await http.put(
          Uri.parse('http://127.0.0.1:8000/macchinari/$idEsistente'),
          headers: intestazioni,
          body: corpoJson,
        );
      }

      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        
        if (datiTradotti['successo'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvataggio confermato!'), backgroundColor: Colors.green));
          _scaricaMacchinari(); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore DB: ${datiTradotti["errore"]}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      // ECCO IL BLOCCO CATCH CHE MANCAVA!
      print("Errore POST/PUT: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore di connessione!'), backgroundColor: Colors.red));
    }
  }


  // --- FUNZIONI DI SUPPORTO GRAFICO ---
  void _ordinaMacchinari(String nuovoCriterio) {
    setState(() {
      _criterioOrdinamento = nuovoCriterio;
      if (nuovoCriterio == 'Nome (A-Z)') {
        _listaMacchinari.sort((a, b) => a['nome'].toString().toLowerCase().compareTo(b['nome'].toString().toLowerCase()));
      } else if (nuovoCriterio == 'Tipo/Funzione') {
        _listaMacchinari.sort((a, b) => a['tipo'].toString().toLowerCase().compareTo(b['tipo'].toString().toLowerCase()));
      }
    });
  }

  Color _colorePerTipo(String tipo) {
    if (tipo == 'Forno') return Colors.red.shade600;
    if (tipo == 'Impastatrice') return Colors.blue.shade600;
    if (tipo == 'Cella di lievitazione') return Colors.teal.shade600;
    if (tipo == 'Banco di lavoro') return Colors.brown.shade600;
    return Colors.blueGrey; 
  }

  // --- LA FINESTRA A COMPARSA ---
  void _apriFinestraMacchinario({Map<String, dynamic>? macchinaEsistente}) {
    bool inModifica = macchinaEsistente != null;
    int? idMacchina = inModifica ? macchinaEsistente['id'] : null;

    String tipoSelezionato = inModifica ? macchinaEsistente!['tipo'] : 'Forno';
    final TextEditingController nomeController = TextEditingController(text: inModifica ? macchinaEsistente!['nome'] : '');
    final TextEditingController capacitaController = TextEditingController(text: inModifica ? macchinaEsistente!['capacita'].toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(inModifica ? 'Modifica Macchinario' : 'Aggiungi Macchinario', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tipoSelezionato,
                      decoration: const InputDecoration(labelText: 'Che macchina è?'),
                      items: ['Forno', 'Impastatrice', 'Cella di lievitazione', 'Banco di lavoro']
                          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                          .toList(),
                      onChanged: (nuovoTipo) => setStateDialog(() => tipoSelezionato = nuovoTipo!),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome identificativo', hintText: 'es. Impastatrice Grande'),
                    ),
                    const SizedBox(height: 15),

                    if (tipoSelezionato == 'Forno' || tipoSelezionato == 'Cella di lievitazione') 
                      _creaCampoNumerico(capacitaController, 'Quante teglie contiene?'),
                    if (tipoSelezionato == 'Impastatrice') 
                      _creaCampoNumerico(capacitaController, 'Chili massimi di impasto (Kg)'),
                    if (tipoSelezionato == 'Banco di lavoro') 
                      const Text('Il banco non ha limiti di capacità.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.isNotEmpty) {
                      final pacchettoDati = {
                        "nome": nomeController.text,
                        "tipo": tipoSelezionato,
                        "capacita": int.tryParse(capacitaController.text) ?? 0, 
                      };

                      _salvaMacchinaSulServer(pacchettoDati, idEsistente: idMacchina);
                      Navigator.pop(context); 
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  child: Text(inModifica ? 'Salva Modifiche' : 'Aggiungi al Laboratorio', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _creaCampoNumerico(TextEditingController controller, String etichetta) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Macchinari'), backgroundColor: Colors.blueGrey),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _apriFinestraMacchinario(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade100, foregroundColor: Colors.blueGrey.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 28),
                label: const Text('Nuovo Macchinario', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const Divider(height: 40, thickness: 2),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Attrezzature in Laboratorio:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueGrey)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _criterioOrdinamento,
                      icon: const Icon(Icons.sort, color: Colors.blueGrey),
                      items: <String>['Nome (A-Z)', 'Tipo/Funzione'].map((String valore) => DropdownMenuItem<String>(value: valore, child: Text('Ordina per $valore', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (String? nuovaScelta) { if (nuovaScelta != null) _ordinaMacchinari(nuovaScelta); },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            Expanded(
              child: _staCaricando
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueGrey))
                  : _listaMacchinari.isEmpty
                      ? const Center(child: Text('Nessun macchinario registrato nel database.', style: TextStyle(fontSize: 18, color: Colors.grey, fontStyle: FontStyle.italic)))
                      : ListView.builder(
                          itemCount: _listaMacchinari.length,
                          itemBuilder: (context, index) {
                            final macchina = _listaMacchinari[index];
                            final coloreMacchina = _colorePerTipo(macchina['tipo']);
                            
                            // LO SCUDO ANTI-CRASH
                            int capacitaSicura = macchina['capacita'] ?? 0;
                            
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(side: BorderSide(color: coloreMacchina, width: 2), borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: Icon(
                                  macchina['tipo'] == 'Forno' ? Icons.local_fire_department : 
                                  macchina['tipo'] == 'Impastatrice' ? Icons.sync : 
                                  macchina['tipo'] == 'Cella di lievitazione' ? Icons.ac_unit : Icons.build,
                                  color: coloreMacchina, size: 32
                                ),
                                title: Text(macchina['nome'], style: TextStyle(fontWeight: FontWeight.bold, color: coloreMacchina, fontSize: 18)),
                                subtitle: Text("${macchina['tipo']} - Capacità: ${capacitaSicura > 0 ? capacitaSicura : 'Libera'}", style: const TextStyle(fontSize: 16)),
                                
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                      onPressed: () => _apriFinestraMacchinario(macchinaEsistente: macchina),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _eliminaMacchinario(macchina['id']), 
                                    ),
                                  ],
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