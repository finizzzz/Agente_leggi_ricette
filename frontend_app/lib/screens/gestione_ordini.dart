import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'nuovo_ordine.dart';
import 'tabella_marcia.dart';

class PaginaGestioneOrdini extends StatefulWidget {
  const PaginaGestioneOrdini({super.key});

  @override
  State<PaginaGestioneOrdini> createState() => _PaginaGestioneOrdiniState();
}

class _PaginaGestioneOrdiniState extends State<PaginaGestioneOrdini> {
  List<Map<String, dynamic>> _tuttiGliOrdini = [];
  bool _staCaricando = true; 
  String _criterioOrdinamento = 'Orario';

  @override
  void initState() {
    super.initState();
    _scaricaOrdini(); 
  }

  // --- 1. CHIAMATA AL DATABASE (GET) ---
  Future<void> _scaricaOrdini() async {
    setState(() => _staCaricando = true);
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/ordini'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          setState(() {
            _tuttiGliOrdini = List<Map<String, dynamic>>.from(datiTradotti['dati']);
            _ordinaLista(_criterioOrdinamento); 
            _staCaricando = false;
          });
        }
      }
    } catch (e) {
      print("Errore GET ordini: $e");
      setState(() => _staCaricando = false);
    }
  }

  // --- 2. ELIMINA ORDINE (DELETE) ---
  Future<void> _eliminaOrdine(int idOrdine) async {
    try {
      final risposta = await http.delete(Uri.parse('http://127.0.0.1:8000/ordini/$idOrdine'));
      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordine annullato ed eliminato!'), backgroundColor: Colors.red)
        );
        _scaricaOrdini(); // Ricarichiamo la lista
      }
    } catch (e) {
      print("Errore DELETE: $e");
    }
  }

  // --- 3. FINESTRA MODIFICA ORDINE (PUT) ---
  Future<void> _apriDialogModifica(Map<String, dynamic> ordine) async {
    // Prima scarichiamo le ricette disponibili per il menu a tendina
    List<Map<String, dynamic>> ricette = [];
    try {
      final risp = await http.get(Uri.parse('http://127.0.0.1:8000/ricette'));
      if (risp.statusCode == 200) {
        final dati = json.decode(risp.body);
        if (dati['successo'] == true) {
          ricette = List<Map<String, dynamic>>.from(dati['dati']);
        }
      }
    } catch (e) {
      print(e);
    }

    if (ricette.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessuna ricetta nel DB!'), backgroundColor: Colors.red));
      return;
    }

    // Troviamo l'ID della ricetta attualmente selezionata
    int ricettaSelezionataId = ricette.first['id'];
    for (var r in ricette) {
      if (r['nome_ricetta'] == ordine['prodotto']) {
        ricettaSelezionataId = r['id'];
        break;
      }
    }

    // Pre-compiliamo i campi con i vecchi dati dell'ordine
    final TextEditingController clienteController = TextEditingController(text: ordine['cliente']);
    final TextEditingController kgController = TextEditingController(text: ordine['kg'].toString());
    TimeOfDay orarioSelezionato = TimeOfDay(
      hour: int.parse(ordine['orario'].split(':')[0]), 
      minute: int.parse(ordine['orario'].split(':')[1])
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Modifica Ordine', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: clienteController,
                      decoration: const InputDecoration(labelText: 'Cliente', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final TimeOfDay? scelto = await showTimePicker(
                              context: context,
                              initialTime: orarioSelezionato,
                            );
                            if (scelto != null) {
                              setStateDialog(() => orarioSelezionato = scelto);
                            }
                          },
                          icon: const Icon(Icons.access_time),
                          label: const Text('Orario'),
                        ),
                        const SizedBox(width: 15),
                        Text('${orarioSelezionato.hour.toString().padLeft(2, '0')}:${orarioSelezionato.minute.toString().padLeft(2, '0')}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      value: ricettaSelezionataId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Prodotto'),
                      items: ricette.map((r) {
                        return DropdownMenuItem<int>(
                          value: r['id'],
                          child: Text(r['nome_ricetta']),
                        );
                      }).toList(),
                      onChanged: (nuovoValore) {
                        setStateDialog(() => ricettaSelezionataId = nuovoValore!);
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: kgController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Quantità Kg', suffixText: 'Kg'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Annulla', style: TextStyle(color: Colors.red))
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (clienteController.text.isEmpty || kgController.text.isEmpty) return;

                    // Formattiamo orario e data per il database
                    DateTime domani = DateTime.now().add(const Duration(days: 1));
                    String dataSql = "${domani.year}-${domani.month.toString().padLeft(2, '0')}-${domani.day.toString().padLeft(2, '0')}";
                    String orarioSql = "${orarioSelezionato.hour.toString().padLeft(2, '0')}:${orarioSelezionato.minute.toString().padLeft(2, '0')}:00";

                    var payload = {
                      "cliente": clienteController.text,
                      "ricetta_id": ricettaSelezionataId,
                      "quantita_kg": double.parse(kgController.text.replaceAll(',', '.')),
                      "data_consegna": dataSql,
                      "orario_consegna": orarioSql
                    };

                    try {
                      final risp = await http.put(
                        Uri.parse('http://127.0.0.1:8000/ordini/${ordine['id']}'),
                        headers: {"Content-Type": "application/json"},
                        body: json.encode(payload)
                      );
                      if (risp.statusCode == 200) {
                        if (mounted) Navigator.pop(context); // Chiude la finestrella
                        _scaricaOrdini(); // Ricarica la lista aggiornata
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ordine modificato con successo!'), backgroundColor: Colors.green)
                        );
                      }
                    } catch (e) {
                      print(e);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Salva Modifiche', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 4. FUNZIONI LOGICHE DI SUPPORTO ---
  void _ordinaLista(String nuovoCriterio) {
    setState(() {
      _criterioOrdinamento = nuovoCriterio;
      if (nuovoCriterio == 'Orario') {
        _tuttiGliOrdini.sort((a, b) => a['orario'].toString().compareTo(b['orario'].toString()));
      } else if (nuovoCriterio == 'Cliente') {
        _tuttiGliOrdini.sort((a, b) => a['cliente'].toString().toLowerCase().compareTo(b['cliente'].toString().toLowerCase()));
      } else if (nuovoCriterio == 'Prodotto') {
        _tuttiGliOrdini.sort((a, b) => (a['prodotto'] ?? '').toString().toLowerCase().compareTo((b['prodotto'] ?? '').toString().toLowerCase()));
      }
    });
  }

  Color _colorePerCliente(String nomeCliente) {
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
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaginaNuovoOrdine()),
                  );
                  _scaricaOrdini(); 
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Riepilogo Consegne:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _criterioOrdinamento,
                      icon: const Icon(Icons.sort, color: Colors.orange),
                      items: <String>['Orario', 'Cliente', 'Prodotto'].map((String valore) {
                        return DropdownMenuItem<String>(value: valore, child: Text('Ordina per $valore', style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (String? nuovaScelta) {
                        if (nuovaScelta != null) _ordinaLista(nuovaScelta);
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            Expanded(
              child: _staCaricando
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _tuttiGliOrdini.isEmpty
                      ? const Center(child: Text('Nessun ordine inserito per oggi.', style: TextStyle(fontSize: 18, color: Colors.grey, fontStyle: FontStyle.italic)))
                      : ListView.builder(
                          itemCount: _tuttiGliOrdini.length,
                          itemBuilder: (context, index) {
                            final ordine = _tuttiGliOrdini[index];
                            final coloreCliente = _colorePerCliente(ordine['cliente']);
                            
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(side: BorderSide(color: coloreCliente, width: 2), borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: Icon(Icons.shopping_bag, color: coloreCliente, size: 32),
                                title: Text('${ordine['cliente']} - Ore ${ordine['orario']}', style: TextStyle(fontWeight: FontWeight.bold, color: coloreCliente, fontSize: 18)),
                                subtitle: Text(ordine['prodotto'] ?? 'Ricetta Eliminata', style: const TextStyle(fontSize: 16)),
                                
                                // ECCO IL NUOVO MENU CON MATITA E CESTINO
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${ordine['kg']} Kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                    const SizedBox(width: 15),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _apriDialogModifica(ordine),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _eliminaOrdine(ordine['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_tuttiGliOrdini.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci almeno un ordine prima di calcolare i turni!'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PaginaTabellaDiMarcia()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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