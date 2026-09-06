import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaginaMacchinari extends StatefulWidget {
  const PaginaMacchinari({super.key});

  @override
  State<PaginaMacchinari> createState() => _PaginaMacchinariState();
}

class _PaginaMacchinariState extends State<PaginaMacchinari> {
  // Il nostro riepilogo visivo (Aggiornato per ricordare anche i numeri grezzi della capacità e temperatura)
  final List<Map<String, dynamic>> _listaMacchinari = [
    {"nome": "Impastatrice a spirale", "tipo": "Impastatrice", "capacita": "50", "temperatura": "", "dettagli": "Capacità: 50 kg"},
    {"nome": "Forno a piani", "tipo": "Forno", "capacita": "8", "temperatura": "250", "dettagli": "Capacità: 8 teglie | Temp Max: 250°C"},
  ];

  String _criterioOrdinamento = 'Nome (A-Z)';

  // Funzione per ordinare la lista
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

  // Funzione per i colori semantici
  Color _colorePerTipo(String tipo) {
    if (tipo == 'Forno') return Colors.red.shade600;
    if (tipo == 'Impastatrice') return Colors.blue.shade600;
    if (tipo == 'Cella di lievitazione') return Colors.teal.shade600;
    if (tipo == 'Banco di lavoro') return Colors.brown.shade600;
    return Colors.blueGrey; 
  }

  // --- LA MAGIA: LA FINESTRA INTELLIGENTE (AGGIUNGI O MODIFICA) ---
  void _apriFinestraMacchinario({int? indiceDaModificare}) {
    // 1. Capiamo se stiamo modificando o creando da zero
    bool inModifica = indiceDaModificare != null;
    final macchinaEsistente = inModifica ? _listaMacchinari[indiceDaModificare] : null;

    // 2. Pre-compiliamo i campi se stiamo modificando!
    String tipoSelezionato = inModifica ? macchinaEsistente!['tipo'] : 'Forno';
    final TextEditingController nomeController = TextEditingController(text: inModifica ? macchinaEsistente!['nome'] : '');
    final TextEditingController capacitaController = TextEditingController(text: inModifica ? macchinaEsistente!['capacita'] : '');
    final TextEditingController temperaturaController = TextEditingController(text: inModifica ? macchinaEsistente!['temperatura'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                inModifica ? 'Modifica Macchinario' : 'Aggiungi Macchinario', 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
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
                      onChanged: (nuovoTipo) {
                        setStateDialog(() {
                          tipoSelezionato = nuovoTipo!;
                        });
                      },
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome identificativo', 
                        hintText: 'es. Impastatrice Grande'
                      ),
                    ),
                    const SizedBox(height: 15),

                    // CAMPI DINAMICI
                    if (tipoSelezionato == 'Forno') ...[
                      _creaCampoNumerico(capacitaController, 'Quante teglie contiene?'),
                      const SizedBox(height: 10),
                      _creaCampoNumerico(temperaturaController, 'Temperatura Max (°C)'),
                    ] 
                    else if (tipoSelezionato == 'Impastatrice') ...[
                      _creaCampoNumerico(capacitaController, 'Chili massimi di impasto (Kg)'),
                    ] 
                    else if (tipoSelezionato == 'Cella di lievitazione') ...[
                      _creaCampoNumerico(capacitaController, 'Quante teglie contiene?'),
                    ]
                    else if (tipoSelezionato == 'Banco di lavoro') ...[
                      const Text('Il banco non ha limiti specifici di teglie.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Annulla', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.isNotEmpty) {
                      String dettagli = "";
                      if (tipoSelezionato == 'Forno') {
                        dettagli = "Capacità: ${capacitaController.text} teglie | Temp Max: ${temperaturaController.text}°C";
                      } else if (tipoSelezionato == 'Impastatrice') {
                        dettagli = "Capacità: ${capacitaController.text} kg";
                      } else if (tipoSelezionato == 'Cella di lievitazione') {
                        dettagli = "Capacità: ${capacitaController.text} teglie";
                      } else {
                        dettagli = "Manuale";
                      }

                      setState(() {
                        // Creiamo il pacchetto dati
                        final pacchettoDati = {
                          "nome": nomeController.text,
                          "tipo": tipoSelezionato,
                          "dettagli": dettagli,
                          "capacita": capacitaController.text,
                          "temperatura": temperaturaController.text,
                        };

                        if (inModifica) {
                          // Se in modifica, sostituiamo i vecchi dati con quelli aggiornati
                          _listaMacchinari[indiceDaModificare!] = pacchettoDati;
                        } else {
                          // Altrimenti aggiungiamo una nuova macchina
                          _listaMacchinari.add(pacchettoDati);
                        }
                        
                        // Riapplichiamo il filtro corrente
                        _ordinaMacchinari(_criterioOrdinamento);
                      });
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
      decoration: InputDecoration(
        labelText: etichetta,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Macchinari'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ElevatedButton.icon(
                // Qui passiamo NESSUN INDICE: quindi la finestra si aprirà VUOTA per CREARE
                onPressed: () => _apriFinestraMacchinario(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade100,
                  foregroundColor: Colors.blueGrey.shade900,
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
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueGrey)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _criterioOrdinamento,
                      icon: const Icon(Icons.sort, color: Colors.blueGrey),
                      items: <String>['Nome (A-Z)', 'Tipo/Funzione'].map((String valore) {
                        return DropdownMenuItem<String>(
                          value: valore,
                          child: Text('Ordina per $valore', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (String? nuovaScelta) {
                        if (nuovaScelta != null) {
                          _ordinaMacchinari(nuovaScelta);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            Expanded(
              child: _listaMacchinari.isEmpty
                  ? const Center(
                      child: Text('Nessun macchinario registrato.', 
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  : ListView.builder(
                      itemCount: _listaMacchinari.length,
                      itemBuilder: (context, index) {
                        final macchina = _listaMacchinari[index];
                        final coloreMacchina = _colorePerTipo(macchina['tipo']);
                        
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: coloreMacchina, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Icon(
                              macchina['tipo'] == 'Forno' ? Icons.local_fire_department : 
                              macchina['tipo'] == 'Impastatrice' ? Icons.sync : 
                              macchina['tipo'] == 'Cella di lievitazione' ? Icons.ac_unit : Icons.build,
                              color: coloreMacchina, size: 32
                            ),
                            title: Text(macchina['nome'], 
                              style: TextStyle(fontWeight: FontWeight.bold, color: coloreMacchina, fontSize: 18)
                            ),
                            subtitle: Text("${macchina['tipo']} - ${macchina['dettagli']}", style: const TextStyle(fontSize: 16)),
                            
                            // ECCO LA NOVITÀ: IL DOPPIO BOTTONE!
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min, // Impedisce che la Row occupi troppo spazio causando errori visivi
                              children: [
                                // Bottone Modifica (Matita Arancione)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _apriFinestraMacchinario(indiceDaModificare: index),
                                ),
                                // Bottone Elimina (Cestino Rosso)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _listaMacchinari.removeAt(index);
                                    });
                                  },
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