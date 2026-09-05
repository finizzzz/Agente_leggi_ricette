import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaginaNuovaRicettaManuale extends StatefulWidget {
  // Aggiungiamo una "scatola" opzionale che può ricevere i dati da modificare
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

// --- LA MAGIA DELL'INIZIALIZZAZIONE (PRE-COMPILAZIONE) ---
  @override
  void initState() {
    super.initState();
    
    // Quando la pagina si apre, controlliamo se ci è stata passata una ricetta
    if (widget.ricettaDaModificare != null) {
      
      // 1. Pre-compiliamo il nome
      _nomeController.text = widget.ricettaDaModificare!['nome'] ?? '';
      
      // 2. Travasiamo gli ingredienti (se esistono)
      if (widget.ricettaDaModificare!['lista_ingredienti'] != null) {
        // TRUCCO DA ESPERTO: Usiamo List.from per fare una "copia" della lista.
        // In questo modo, se cancelli un ingrediente nel modulo, non lo elimini dal database originale 
        // finché non premi il grande bottone finale "Salva Ricetta"!
        _ingredienti.addAll(List<Map<String, dynamic>>.from(widget.ricettaDaModificare!['lista_ingredienti']));
      }
      
      // 3. Travasiamo le fasi (se esistono)
      if (widget.ricettaDaModificare!['lista_fasi'] != null) {
        _fasi.addAll(List<Map<String, dynamic>>.from(widget.ricettaDaModificare!['lista_fasi']));
      }
    }
  }

  // --- AZIONI PER GLI INGREDIENTI ---
 
  // --- AZIONI PER GLI INGREDIENTI ---
  void _aggiungiIngrediente() {
    setState(() {
      _ingredienti.add({
        'nome': '',
        'quantita': '',
        'unita': 'g', 
      });
    });
  }

  void _rimuoviIngrediente(int indice) {
    setState(() {
      _ingredienti.removeAt(indice);
    });
  }

  // --- NUOVE AZIONI PER LE FASI ---
  void _aggiungiFase() {
    setState(() {
      _fasi.add({
        'nome_fase': '',
        'macchinario': 'Banco di lavoro', // Partiamo dal banco come default
        'tempo_minuti': '',
      });
    });
  }

  void _rimuoviFase(int indice) {
    setState(() {
      _fasi.removeAt(indice);
    });
  }

  // --- MODULO 1: NOME DELLA RICETTA ---
  Widget _costruisciSezioneNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dettagli Principali',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _nomeController,
          decoration: InputDecoration(
            labelText: 'Nome della Ricetta (es. Ciabatta Artigianale)',
            prefixIcon: const Icon(Icons.bakery_dining),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

 // --- MODULO 2: LA LISTA DEGLI INGREDIENTI (CON RESA) ---
  Widget _costruisciSezioneIngredienti() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredienti e Resa',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const Text(
          'Indica per quanto prodotto finito sono calcolati questi ingredienti.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 15),

        // --- NUOVO: SEZIONE RESA STIMATA ---
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
                  decoration: const InputDecoration(
                    hintText: 'Es. 10',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _resaUnita,
                items: ['Kg', 'g', 'Pz'].map((String unita) {
                  return DropdownMenuItem<String>(
                    value: unita,
                    child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (nuovoValore) {
                  setState(() {
                    _resaUnita = nuovoValore!;
                  });
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

       // La lista che si allunga da sola (Ora con initialValue!)
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
                        // NUOVO: Mostriamo il testo che c'è già in memoria!
                        initialValue: _ingredienti[index]['nome'],
                        decoration: const InputDecoration(labelText: 'Ingrediente', border: OutlineInputBorder()),
                        onChanged: (valore) => _ingredienti[index]['nome'] = valore,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        // NUOVO: Mostriamo la quantità che c'è già in memoria!
                        initialValue: _ingredienti[index]['quantita'],
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
                        return DropdownMenuItem<String>(
                          value: unita,
                          child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (nuovoValore) {
                        setState(() {
                          _ingredienti[index]['unita'] = nuovoValore!;
                        });
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade100, 
              foregroundColor: Colors.orange.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // --- MODULO 3: LE FASI (IL PROCEDIMENTO TEMPORALE) ---
  Widget _costruisciSezioneFasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Procedimento e Tempistiche',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const Text(
          'Definisci gli step. I minuti sono vitali per far calcolare i turni all\'Intelligenza Artificiale.',
          style: TextStyle(color: Colors.grey),
        ),
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
                        // Un bel numerino tondo per indicare lo Step 1, 2, 3...
                        CircleAvatar(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          radius: 14,
                          child: Text('${index + 1}'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: _fasi[index]['nome_fase'],
                            decoration: const InputDecoration(labelText: 'Azione (es. Impasto, Cottura)', border: OutlineInputBorder()),
                            onChanged: (valore) => _fasi[index]['nome_fase'] = valore,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _rimuoviFase(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Menu a tendina per scegliere la macchina
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Macchinario', border: OutlineInputBorder()),
                            value: _fasi[index]['macchinario'],
                            items: ['Banco di lavoro', 'Impastatrice a spirale', 'Forno a piani', 'Cella di lievitazione'].map((String mac) {
                              return DropdownMenuItem<String>(
                                value: mac,
                                child: Text(mac),
                              );
                            }).toList(),
                            onChanged: (nuovoValore) {
                              setState(() {
                                _fasi[index]['macchinario'] = nuovoValore!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Campo per i minuti
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: _fasi[index]['tempo_minuti'],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade100, 
              foregroundColor: Colors.orange.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // --- IMPAGINAZIONE FINALE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Componi Ricetta Manuale'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Richiamiamo in ordine tutti e 3 i nostri "mattoncini"
            _costruisciSezioneNome(),
            const SizedBox(height: 30),
            
            _costruisciSezioneIngredienti(),
            const SizedBox(height: 30),
            
            _costruisciSezioneFasi(),
            const SizedBox(height: 40),
            
            // Il bottone finale di salvataggio
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Per ora stampiamo il risultato nel terminale per assicurarci che raccolga tutto
                  print("=== RICETTA SALVATA ===");
                  print("Nome: ${_nomeController.text}");
                  print("Ingredienti: $_ingredienti");
                  print("Fasi: $_fasi");
                  
                  // In futuro qui invieremo i dati al Backend Python, per ora torniamo indietro
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Salva Ricetta', style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
