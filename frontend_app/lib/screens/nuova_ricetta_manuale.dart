import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaginaNuovaRicettaManuale extends StatefulWidget {
  final Map<String, dynamic>? ricettaDaModificare;

  const PaginaNuovaRicettaManuale({super.key, this.ricettaDaModificare});

  @override
  State<PaginaNuovaRicettaManuale> createState() => _PaginaNuovaRicettaManualeState();
}

class _PaginaNuovaRicettaManualeState extends State<PaginaNuovaRicettaManuale> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _resaQuantitaController = TextEditingController();
  String _resaUnita = 'Kg'; 
  
  final List<Map<String, dynamic>> _ingredienti = [];
  final List<Map<String, dynamic>> _fasi = [];
  
  final List<String> _opzioniMacchinari = ['Banco di lavoro', 'Impastatrice a spirale', 'Forno a piani', 'Cella di lievitazione'];

  @override
  void initState() {
    super.initState();
    if (widget.ricettaDaModificare != null) {
      _nomeController.text = widget.ricettaDaModificare!['nome'] ?? '';
      
      if (widget.ricettaDaModificare!['resa_quantita'] != null) {
        _resaQuantitaController.text = widget.ricettaDaModificare!['resa_quantita'].toString();
      }
      if (widget.ricettaDaModificare!['resa_unita'] != null) {
        _resaUnita = widget.ricettaDaModificare!['resa_unita'];
      }

      if (widget.ricettaDaModificare!['lista_ingredienti'] != null) {
        for (var ing in widget.ricettaDaModificare!['lista_ingredienti']) {
          _ingredienti.add({
            'nome': ing['nome']?.toString() ?? '',
            'quantita': ing['quantita']?.toString() ?? '', 
            'unita': ing['unita']?.toString() ?? 'g',
          });
        }
      }
      
      if (widget.ricettaDaModificare!['lista_fasi'] != null) {
        for (var fase in widget.ricettaDaModificare!['lista_fasi']) {
          String macchinarioTrovato = fase['macchinario']?.toString() ?? 'Banco di lavoro';
          if (!_opzioniMacchinari.contains(macchinarioTrovato)) {
            _opzioniMacchinari.add(macchinarioTrovato);
          }
          _fasi.add({
            'nome_fase': fase['nome_fase']?.toString() ?? '',
            'macchinario': macchinarioTrovato,
            'tempo_minuti': fase['tempo_minuti']?.toString() ?? '',
            'gradi': fase['gradi']?.toString() ?? '', // CARICHIAMO I GRADI SE ESISTONO!
          });
        }
      }
    }
  }

  void _aggiungiIngrediente() {
    setState(() => _ingredienti.add({'nome': '', 'quantita': '', 'unita': 'g'}));
  }

  void _rimuoviIngrediente(int indice) {
    setState(() => _ingredienti.removeAt(indice));
  }

  void _aggiungiFase() {
    setState(() => _fasi.add({'nome_fase': '', 'macchinario': 'Banco di lavoro', 'tempo_minuti': '', 'gradi': ''}));
  }

  void _rimuoviFase(int indice) {
    setState(() => _fasi.removeAt(indice));
  }

  Widget _costruisciSezioneNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dettagli Principali', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 15),
        TextField(controller: _nomeController, decoration: InputDecoration(labelText: 'Nome della Ricetta (es. Ciabatta)', prefixIcon: const Icon(Icons.bakery_dining), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ],
    );
  }

  Widget _costruisciSezioneIngredienti() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingredienti e Resa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const Text('Indica per quanto prodotto finito sono calcolati questi ingredienti.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
          child: Row(
            children: [
              const Text('Resa totale:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _resaQuantitaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Es. 10', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _resaUnita,
                items: ['Kg', 'g', 'Pz'].map((String unita) => DropdownMenuItem<String>(value: unita, child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                onChanged: (nuovoValore) => setState(() => _resaUnita = nuovoValore!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _ingredienti.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: TextFormField(initialValue: _ingredienti[index]['nome'], decoration: const InputDecoration(labelText: 'Ingrediente', border: OutlineInputBorder()), onChanged: (valore) => _ingredienti[index]['nome'] = valore)),
                    const SizedBox(width: 10),
                    Expanded(flex: 1, child: TextFormField(initialValue: _ingredienti[index]['quantita'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Q.tà', border: OutlineInputBorder()), onChanged: (valore) => _ingredienti[index]['quantita'] = valore)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _ingredienti[index]['unita'],
                      items: ['g', 'Kg', 'ml', 'L', 'Pz'].map((String unita) => DropdownMenuItem<String>(value: unita, child: Text(unita, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (nuovoValore) => setState(() => _ingredienti[index]['unita'] = nuovoValore!),
                    ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _rimuoviIngrediente(index)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Center(child: ElevatedButton.icon(onPressed: _aggiungiIngrediente, icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Ingrediente'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900))),
      ],
    );
  }

  Widget _costruisciSezioneFasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Procedimento e Tempistiche', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
        const Text('Definisci gli step. Se scegli "Forno a piani", apparirà la temperatura!', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 15),

        ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _fasi.length,
          itemBuilder: (context, index) {
            
            // CONTROLLIAMO SE LA MACCHINA È IL FORNO
            bool isForno = _fasi[index]['macchinario'] == 'Forno a piani';

            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.orange, foregroundColor: Colors.white, radius: 14, child: Text('${index + 1}')),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(initialValue: _fasi[index]['nome_fase'], decoration: const InputDecoration(labelText: 'Azione (es. Cottura)', border: OutlineInputBorder()), onChanged: (valore) => _fasi[index]['nome_fase'] = valore)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _rimuoviFase(index)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Macchinario', border: OutlineInputBorder()),
                            value: _fasi[index]['macchinario'],
                            items: _opzioniMacchinari.map((String mac) => DropdownMenuItem<String>(value: mac, child: Text(mac, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (nuovoValore) => setState(() => _fasi[index]['macchinario'] = nuovoValore!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(initialValue: _fasi[index]['tempo_minuti'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Minuti', border: OutlineInputBorder(), suffixText: 'min'), onChanged: (valore) => _fasi[index]['tempo_minuti'] = valore),
                        ),
                        
                        // LA MAGIA DEI GRADI: Appare solo se selezioni il Forno!
                        if (isForno) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: _fasi[index]['gradi'], 
                              keyboardType: TextInputType.number, 
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
                              decoration: const InputDecoration(labelText: 'Gradi', border: OutlineInputBorder(), suffixText: '°C'), 
                              onChanged: (valore) => _fasi[index]['gradi'] = valore
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Center(child: ElevatedButton.icon(onPressed: _aggiungiFase, icon: const Icon(Icons.add_task), label: const Text('Aggiungi Fase (Step)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ricettaDaModificare != null ? 'Modifica Ricetta' : 'Componi Ricetta Manuale'), backgroundColor: Colors.orange),
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
                    'metodo': widget.ricettaDaModificare != null ? widget.ricettaDaModificare!['metodo'] : 'Manuale',
                    'resa_quantita': _resaQuantitaController.text,
                    'resa_unita': _resaUnita,
                    'ingredienti': _ingredienti.length,
                    'fasi': _fasi.length,
                    'lista_ingredienti': _ingredienti,
                    'lista_fasi': _fasi,
                  };
                  
                  // RESTITUIAMO IL PACCHETTO PULITO A MYSQL!
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