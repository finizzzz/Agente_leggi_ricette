import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaginaNuovaRicettaManuale extends StatefulWidget {
  // 1. La scatola che riceve la ricetta da modificare (può essere nulla se stiamo creando da zero)
  final Map<String, dynamic>? ricettaDaModificare;

  const PaginaNuovaRicettaManuale({super.key, this.ricettaDaModificare});

  @override
  State<PaginaNuovaRicettaManuale> createState() => _PaginaNuovaRicettaManualeState();
}

class _PaginaNuovaRicettaManualeState extends State<PaginaNuovaRicettaManuale> {
  // --- LA MEMORIA DELLA PAGINA ---
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _resaQuantitaController = TextEditingController();
  String _resaUnita = 'Kg'; 
  
  final List<Map<String, dynamic>> _ingredienti = [];
  final List<Map<String, dynamic>> _fasi = [];

  // --- LA MAGIA: PRE-COMPILIAMO I CAMPI ALL'AVVIO ---
  @override
  void initState() {
    super.initState();
    
    // Controlliamo se ci è stata passata una ricetta
    if (widget.ricettaDaModificare != null) {
      
      _nomeController.text = widget.ricettaDaModificare!['nome'] ?? '';
      
      if (widget.ricettaDaModificare!['resa_quantita'] != null) {
        _resaQuantitaController.text = widget.ricettaDaModificare!['resa_quantita'].toString();
      }
      if (widget.ricettaDaModificare!['resa_unita'] != null) {
        _resaUnita = widget.ricettaDaModificare!['resa_unita'];
      }

      if (widget.ricettaDaModificare!['lista_ingredienti'] != null) {
        _ingredienti.addAll(List<Map<String, dynamic>>.from(
          widget.ricettaDaModificare!['lista_ingredienti'].map((e) => Map<String, dynamic>.from(e))
        ));
      }
      
      if (widget.ricettaDaModificare!['lista_fasi'] != null) {
        _fasi.addAll(List<Map<String, dynamic>>.from(
          widget.ricettaDaModificare!['lista_fasi'].map((e) => Map<String, dynamic>.from(e))
        ));
      }
    }
  }

  // --- AZIONI PER GLI INGREDIENTI ---
  void _aggiungiIngrediente() {
    setState(() {
      _ingredienti.add({'nome': '', 'quantita': '', 'unita': 'g'});
    });
  }

  void _rimuoviIngrediente(int indice) {
    setState(() {
      _ingredienti.removeAt(indice);
    });
  }

  // --- AZIONI PER LE FASI ---
  void _aggiungiFase() {
    setState(() {
      _fasi.add({'nome_fase': '', 'macchinario': 'Banco di lavoro', 'tempo_minuti': ''});
    });
  }

  void _rimuoviFase(int indice) {
    setState(() {
      _fasi.removeAt(indice);
    });
  }

  // --- MODULI GRAFICI ---
  Widget _costruisciSezioneNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dettagli Principali', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 15),
        TextField(
          controller: _nomeController,
          decoration: InputDecoration(
            labelText: 'Nome della Ricetta',
            prefixIcon: const Icon(Icons.bakery_dining),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _costruisciSezioneIngredienti() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingredienti e Resa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Text('Resa totale:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _resaQuantitaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Es. 10', isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _resaUnita,
                items: ['Kg', 'g', 'Pz'].map((String unita) {
                  return DropdownMenuItem<String>(value: unita, child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)));
                }).toList(),
                onChanged: (nuovoValore) {
                  setState(() { _resaUnita = nuovoValore!; });
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        ListView.builder(
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          itemCount: _ingredienti.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        // LA MAGIA DEI CAMPI PRE-COMPILATI!
                        initialValue: _ingredienti[index]['nome']?.toString(),
                        decoration: const InputDecoration(labelText: 'Ingrediente', border: OutlineInputBorder()),
                        onChanged: (valore) => _ingredienti[index]['nome'] = valore,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: _ingredienti[index]['quantita']?.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Q.tà', border: OutlineInputBorder()),
                        onChanged: (valore) => _ingredienti[index]['quantita'] = valore,
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _ingredienti[index]['unita'],
                      items: ['g', 'Kg', 'ml', 'L', 'Pz'].map((String unita) {
                        return DropdownMenuItem<String>(value: unita, child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (nuovoValore) {
                        setState(() { _ingredienti[index]['unita'] = nuovoValore!; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _rimuoviIngrediente(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 10),
        
        Center(
          child: ElevatedButton.icon(
            onPressed: _aggiungiIngrediente,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Aggiungi Ingrediente'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900),
          ),
        ),
      ],
    );
  }

  Widget _costruisciSezioneFasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Procedimento e Tempistiche', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 15),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fasi.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.orange, foregroundColor: Colors.white, radius: 14, child: Text('${index + 1}')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            // LA MAGIA PRE-COMPILATA PER LE FASI
                            initialValue: _fasi[index]['nome_fase']?.toString(),
                            decoration: const InputDecoration(labelText: 'Azione (es. Impasto)', border: OutlineInputBorder()),
                            onChanged: (valore) => _fasi[index]['nome_fase'] = valore,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _rimuoviFase(index)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Macchinario', border: OutlineInputBorder()),
                            value: _fasi[index]['macchinario'],
                            items: ['Banco di lavoro', 'Impastatrice a spirale', 'Forno a piani', 'Cella di lievitazione'].map((String mac) {
                              return DropdownMenuItem<String>(value: mac, child: Text(mac));
                            }).toList(),
                            onChanged: (nuovoValore) {
                              setState(() { _fasi[index]['macchinario'] = nuovoValore!; });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: _fasi[index]['tempo_minuti']?.toString(),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Minuti', border: OutlineInputBorder(), suffixText: 'min'),
                            onChanged: (valore) => _fasi[index]['tempo_minuti'] = valore,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 10),
        
        Center(
          child: ElevatedButton.icon(
            onPressed: _aggiungiFase,
            icon: const Icon(Icons.add_task),
            label: const Text('Aggiungi Fase (Step)'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Cambiamo il titolo in base a cosa stiamo facendo!
        title: Text(widget.ricettaDaModificare != null ? 'Modifica Ricetta' : 'Nuova Ricetta Manuale'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _costruisciSezioneNome(),
            const SizedBox(height: 30),
            _costruisciSezioneIngredienti(),
            const SizedBox(height: 30),
            _costruisciSezioneFasi(),
            const SizedBox(height: 40),
            
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Map<String, dynamic> ricettaAggiornata = {
                    'nome': _nomeController.text,
                    'metodo': widget.ricettaDaModificare != null ? 'Modificata Manualmente' : 'Manuale',
                    'ingredienti': _ingredienti.length,
                    'fasi': _fasi.length,
                    'lista_ingredienti': _ingredienti,
                    'lista_fasi': _fasi,
                    'resa_quantita': _resaQuantitaController.text,
                    'resa_unita': _resaUnita,
                  };
                  
                  // Stampiamo a terminale per confermare
                  print("=== SALVATAGGIO EFFETTUATO ===");
                  print(ricettaAggiornata);

                  // Torniamo indietro inviando la ricetta aggiornata!
                  Navigator.pop(context, ricettaAggiornata);
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), backgroundColor: Colors.orange),
                child: Text(widget.ricettaDaModificare != null ? 'Aggiorna Ricetta' : 'Salva Ricetta', style: const TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}