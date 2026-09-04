import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tabella_marcia.dart';

class PaginaNuovoOrdine extends StatefulWidget {
  const PaginaNuovoOrdine({super.key});

  @override
  State<PaginaNuovoOrdine> createState() => _PaginaNuovoOrdineState();
}

class _PaginaNuovoOrdineState extends State<PaginaNuovoOrdine> {
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController(); 
  
  String _tipoPane = 'Ciabatta Artigianale con Biga'; 
  TimeOfDay? _orarioConsegna;
  
  // L'unico carrello ufficiale
  final List<Map<String, dynamic>> _ordiniMultipli = [];

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
    if (_kgController.text.isNotEmpty && _clienteController.text.isNotEmpty && _orarioConsegna != null) {
      setState(() {
        _ordiniMultipli.add({
          'cliente': _clienteController.text,
          'orario': '${_orarioConsegna!.hour.toString().padLeft(2, '0')}:${_orarioConsegna!.minute.toString().padLeft(2, '0')}',
          'prodotto': _tipoPane,
          'kg': _kgController.text,
        });
        _kgController.clear(); 
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attenzione: Compila Cliente, Orario e Kg!'),
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
        DropdownButton<String>(
          value: _tipoPane,
          isExpanded: true,
          items: <String>['Ciabatta Artigianale con Biga', 'Filone Classico', 'Panini all\'Olio']
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
                // NUOVA RIGA: Accetta ESCLUSIVAMENTE numeri da 0 a 9 e il punto decimale 
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
                      subtitle: Text(voce['prodotto']),
                      trailing: Text('${voce['kg']} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              ),
      ],
    );
  }

  // --- IL BUILD FINALE (Cortissimo grazie ai moduli!) ---
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
                onPressed: () {
                  if (_ordiniMultipli.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore: Inserisci almeno un ordine!'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tutti gli ordini salvati con successo!'), backgroundColor: Colors.green),
                  );

                  print("=== ORDINI COMPLESSIVI DA INVIARE ===");
                  print(_ordiniMultipli);
                  
                  Future.delayed(const Duration(seconds: 1), () {
                    if (context.mounted) Navigator.pop(context, _ordiniMultipli);
                  });
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