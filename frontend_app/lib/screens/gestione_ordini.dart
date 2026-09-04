import 'package:flutter/material.dart';
import 'nuovo_ordine.dart';
import 'tabella_marcia.dart';

class PaginaGestioneOrdini extends StatefulWidget {
  const PaginaGestioneOrdini({super.key});

  @override
  State<PaginaGestioneOrdini> createState() => _PaginaGestioneOrdiniState();
}

class _PaginaGestioneOrdiniState extends State<PaginaGestioneOrdini> {
  // Questa è la "Grande Memoria" che raccoglierà tutti gli ordini della giornata
  List<Map<String, dynamic>> _tuttiGliOrdini = [];

  // --- NUOVE FUNZIONI PER ORDINAMENTO E COLORI ---
  
  // Variabile per ricordare il filtro attuale
  String _criterioOrdinamento = 'Orario';

// 1. Funzione per ordinare la lista (Versione Potenziata)
  void _ordinaLista(String nuovoCriterio) {
    setState(() {
      _criterioOrdinamento = nuovoCriterio;
      
      if (nuovoCriterio == 'Orario') {
        _tuttiGliOrdini.sort((a, b) => a['orario'].toString().compareTo(b['orario'].toString()));
      } else if (nuovoCriterio == 'Cliente') {
        // Aggiungiamo toLowerCase() così ignora le maiuscole/minuscole e ordina perfettamente!
        _tuttiGliOrdini.sort((a, b) => a['cliente'].toString().toLowerCase().compareTo(b['cliente'].toString().toLowerCase()));
      } else if (nuovoCriterio == 'Prodotto') {
        _tuttiGliOrdini.sort((a, b) => a['prodotto'].toString().toLowerCase().compareTo(b['prodotto'].toString().toLowerCase()));
      }
    });
  }

  // 2. Funzione magica per generare un colore fisso per ogni cliente
  Color _colorePerCliente(String nomeCliente) {
    // Usiamo il 'hashCode' (un numero univoco generato dalle lettere del nome) 
    // per scegliere un colore dalla tavolozza predefinita di Flutter.
    // In questo modo "Mario" sarà sempre blu, "Ristorante Bella Italia" sempre rosso, ecc.
    final int indiceColore = nomeCliente.hashCode.abs() % Colors.primaries.length;
    return Colors.primaries[indiceColore];
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Ordini'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. PULSANTE IN ALTO: NUOVO ORDINE ---
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ordiniInseriti = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaginaNuovoOrdine()),
                  );

                  if (ordiniInseriti != null) {
                    setState(() {
                      _tuttiGliOrdini.addAll(ordiniInseriti);
                      // Riapplichiamo l'ordinamento attuale ogni volta che arriva un nuovo ordine!
                      _ordinaLista(_criterioOrdinamento);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 28),
                label: const Text('Nuovo Ordine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const Divider(height: 40, thickness: 2),

            // --- 2. RIEPILOGO CONSEGNE CON FILTRO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Riepilogo Consegne:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                
                // IL NUOVO MENU A TENDINA PER ORDINARE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _criterioOrdinamento,
                      icon: const Icon(Icons.sort, color: Colors.orange),
                      items: <String>['Orario', 'Cliente', 'Prodotto'].map((String valore) {
                        return DropdownMenuItem<String>(
                          value: valore,
                          child: Text('Ordina per $valore', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (String? nuovaScelta) {
                        if (nuovaScelta != null) {
                          _ordinaLista(nuovaScelta);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // --- LISTA COLORATA ---
            Expanded(
              child: _tuttiGliOrdini.isEmpty
                  ? const Center(
                      child: Text('Nessun ordine inserito per oggi.', 
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  : ListView.builder(
                      itemCount: _tuttiGliOrdini.length,
                      itemBuilder: (context, index) {
                        final ordine = _tuttiGliOrdini[index];
                        
                        // CHIAMIAMO LA FUNZIONE MAGICA DEI COLORI
                        final coloreCliente = _colorePerCliente(ordine['cliente']);
                        
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 10),
                          // Diamo alla carta un bordo spesso 2 pixel con il colore del cliente
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: coloreCliente, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.shopping_bag, color: coloreCliente, size: 32),
                            title: Text('${ordine['cliente']} - Ore ${ordine['orario']}', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: coloreCliente, fontSize: 18)
                            ),
                            subtitle: Text(ordine['prodotto'], style: const TextStyle(fontSize: 16)),
                            trailing: Text('${ordine['kg']} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // --- 3. PULSANTE IN FONDO: AVVIA IA ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_tuttiGliOrdini.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inserisci almeno un ordine prima di calcolare i turni!'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaginaTabellaDiMarcia()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.smart_toy, size: 28),
                label: const Text('Inizia Turno (Calcola IA)', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}