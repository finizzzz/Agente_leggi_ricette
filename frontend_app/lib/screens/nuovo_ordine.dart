import 'package:flutter/material.dart';

class PaginaNuovoOrdine extends StatefulWidget {
  const PaginaNuovoOrdine({super.key});

  @override
  State<PaginaNuovoOrdine> createState() => _PaginaNuovoOrdineState();
}

class _PaginaNuovoOrdineState extends State<PaginaNuovoOrdine> {
  final TextEditingController _kgController = TextEditingController();
  String _tipoPane = 'Ciabatta Artigianale con Biga'; 
  final List<Map<String, String>> _vociOrdine = [];
  TimeOfDay? _orarioConsegna;

  void _aggiungiVoce() {
    if (_kgController.text.isNotEmpty) {
      setState(() {
        _vociOrdine.add({
          'prodotto': _tipoPane,
          'kg': _kgController.text,
        });
        _kgController.clear(); 
      });
    } else {
      // NUOVO: Avviso visivo se non hai messo i Kg!
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attenzione: Inserisci i Kg prima di aggiungere!'), 
          backgroundColor: Colors.red
        ),
      );
    }
  }

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
            const Text('Orario di Consegna:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _scegliOrario,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Scegli Orario'),
                ),
                const SizedBox(width: 15),
                Text(
                  _orarioConsegna == null 
                      ? 'Nessun orario selezionato' 
                      : '${_orarioConsegna!.hour.toString().padLeft(2, '0')}:${_orarioConsegna!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const Divider(height: 40, thickness: 2),

            const Text('Aggiungi Prodotti:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _tipoPane,
              isExpanded: true,
              items: <String>['Ciabatta Artigianale con Biga', 'Filone Classico']
                  .map((String valore) {
                return DropdownMenuItem<String>(
                  value: valore,
                  child: Text(valore, style: const TextStyle(fontSize: 18)),
                );
              }).toList(),
              onChanged: (String? nuovaScelta) {
                setState(() {
                  _tipoPane = nuovaScelta!;
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Kg (es. 15)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _aggiungiVoce,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                  ),
                  child: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
            
            const Divider(height: 40, thickness: 2),

            const Text('Riepilogo Ordine Corrente:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _vociOrdine.length,
              itemBuilder: (context, index) {
                final voce = _vociOrdine[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.bakery_dining, color: Colors.orange),
                    title: Text(voce['prodotto']!),
                    trailing: Text('${voce['kg']} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // NUOVO: Controllo con avviso visivo
                  if (_vociOrdine.isEmpty || _orarioConsegna == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Errore: Inserisci almeno un orario e un prodotto!'), 
                        backgroundColor: Colors.red
                      ),
                    );
                    return;
                  }
                  
                  // NUOVO: Messaggio di successo visivo
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ordine salvato con successo!'), 
                      backgroundColor: Colors.green
                    ),
                  );

                  print("=== ORDINE DA INVIARE ===");
                  print("Consegna: ${_orarioConsegna!.hour}:${_orarioConsegna!.minute}");
                  print("Comande: $_vociOrdine");
                  
                  // Aspettiamo un secondo per farti leggere il messaggio verde prima di cambiare pagina
                  Future.delayed(const Duration(seconds: 1), () {
                    if (context.mounted) Navigator.pop(context);
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Salva e Invia Ordine', style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}