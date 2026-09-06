import 'package:flutter/material.dart';
import 'calendario_turni.dart';

class PaginaDipendenti extends StatefulWidget {
  const PaginaDipendenti({super.key});

  @override
  State<PaginaDipendenti> createState() => _PaginaDipendentiState();
}

class _PaginaDipendentiState extends State<PaginaDipendenti> {
  // --- 1. MEMORIA PULITA (Zero esempi, pronti per la produzione!) ---
  final List<Map<String, dynamic>> _listaDipendenti = [];
  final List<Map<String, dynamic>> _listaTurni = [];

  String _filtroAttuale = 'Tutti';

  Color _colorePerRuolo(String ruolo) {
    if (ruolo == 'Mastro Panettiere') return Colors.orange.shade700;
    if (ruolo == 'Addetto Forni') return Colors.red.shade600;
    if (ruolo == 'Aiuto Fornaio') return Colors.blue.shade600;
    if (ruolo == 'Addetto Consegne') return Colors.green.shade600;
    return Colors.indigo;
  }

  List<String> _ottieniOpzioniFiltro() {
    List<String> opzioni = ['Tutti', 'Solo Panificio'];
    for (var dip in _listaDipendenti) {
      opzioni.add(dip['nome']);
    }
    return opzioni;
  }

  // ==========================================
  // CRUD DIPENDENTI 
  // ==========================================
  void _apriFinestraDipendente({int? indiceDaModificare}) {
    bool inModifica = indiceDaModificare != null;
    final dipendenteEsistente = inModifica ? _listaDipendenti[indiceDaModificare] : null;

    String ruoloSelezionato = inModifica ? dipendenteEsistente!['ruolo'] : 'Aiuto Fornaio';
    final TextEditingController nomeController = TextEditingController(text: inModifica ? dipendenteEsistente!['nome'] : '');
    final TextEditingController dettagliController = TextEditingController(text: inModifica ? dipendenteEsistente!['dettagli'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(inModifica ? 'Modifica Dipendente' : 'Nuovo Dipendente'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome e Cognome')),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: ruoloSelezionato,
                      decoration: const InputDecoration(labelText: 'Mansione'),
                      items: ['Mastro Panettiere', 'Addetto Forni', 'Aiuto Fornaio', 'Addetto Consegne', 'Pasticcere']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setStateDialog(() => ruoloSelezionato = val!),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: dettagliController, decoration: const InputDecoration(labelText: 'Dettagli / Note')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.isNotEmpty) {
                      setState(() {
                        final dati = {"nome": nomeController.text, "ruolo": ruoloSelezionato, "dettagli": dettagliController.text};
                        if (inModifica) _listaDipendenti[indiceDaModificare!] = dati;
                        else _listaDipendenti.add(dati);
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(inModifica ? 'Salva' : 'Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // CRUD TURNI & APERTURE PANIFICIO
  // ==========================================
  void _apriFinestraTurno({Map<String, dynamic>? turnoDaModificare}) {
    bool inModifica = turnoDaModificare != null;
    
    // Capiamo se stiamo modificando un dipendente o il panificio
    String tipoEvento = inModifica ? turnoDaModificare!['tipo'] : 'Dipendente';
    
    DateTime dataBase = inModifica ? turnoDaModificare!['data'] : DateTime.now();
    DateTimeRange dateRange = DateTimeRange(start: dataBase, end: dataBase);
    
    String? dipendenteSelezionato = (inModifica && tipoEvento == 'Dipendente') 
        ? turnoDaModificare!['dipendente'] 
        : (_listaDipendenti.isNotEmpty ? _listaDipendenti.first['nome'] : null);
        
    final TextEditingController clienteController = TextEditingController(
      text: (inModifica && tipoEvento == 'Dipendente') ? turnoDaModificare!['cliente'] : ''
    );
    
    TimeOfDay orarioInizio = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay orarioFine = const TimeOfDay(hour: 14, minute: 0);

    if (inModifica) {
      try {
        List<String> orari = turnoDaModificare!['orario'].split(' - ');
        orarioInizio = TimeOfDay(hour: int.parse(orari[0].split(':')[0]), minute: int.parse(orari[0].split(':')[1]));
        orarioFine = TimeOfDay(hour: int.parse(orari[1].split(':')[0]), minute: int.parse(orari[1].split(':')[1]));
      } catch (e) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> selezionaDate() async {
              final DateTimeRange? rangeScelto = await showDateRangePicker(
                context: context,
                initialDateRange: dateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.indigo)),
                    child: child!,
                  );
                },
              );
              if (rangeScelto != null) setStateDialog(() => dateRange = rangeScelto);
            }

            Future<void> selezionaOrario(bool isInizio) async {
              final TimeOfDay? orarioScelto = await showTimePicker(
                context: context,
                initialTime: isInizio ? orarioInizio : orarioFine,
              );
              if (orarioScelto != null) {
                setStateDialog(() {
                  if (isInizio) orarioInizio = orarioScelto;
                  else orarioFine = orarioScelto;
                });
              }
            }

            String testoData = dateRange.start.isAtSameMomentAs(dateRange.end)
                ? "${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year}"
                : "${dateRange.start.day}/${dateRange.start.month} - ${dateRange.end.day}/${dateRange.end.month}";

            return AlertDialog(
              title: Row(
                children: [
                  Icon(tipoEvento == 'Panificio' ? Icons.storefront : Icons.event, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Text(inModifica ? 'Modifica Evento' : 'Nuovo Evento'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SCELTA TIPO EVENTO
                    DropdownButtonFormField<String>(
                      value: tipoEvento,
                      decoration: const InputDecoration(labelText: 'Cosa stai impostando?', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Dipendente', child: Text('Turno Staff')),
                        DropdownMenuItem(value: 'Panificio', child: Text('Orari Negozio')),
                      ],
                      onChanged: (val) => setStateDialog(() => tipoEvento = val!),
                    ),
                    const SizedBox(height: 15),

                    // DATA
                    InkWell(
                      onTap: selezionaDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Periodo (Tocca per scegliere)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.date_range)),
                        child: Text(testoData, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // SE E' UN DIPENDENTE, MOSTRA LA SCELTA DELLO STAFF
                    if (tipoEvento == 'Dipendente') ...[
                      DropdownButtonFormField<String>(
                        value: dipendenteSelezionato,
                        decoration: const InputDecoration(labelText: 'Dipendente', border: OutlineInputBorder()),
                        items: _listaDipendenti.map((d) => DropdownMenuItem<String>(value: d['nome'], child: Text(d['nome']))).toList(),
                        onChanged: (val) => setStateDialog(() => dipendenteSelezionato = val),
                        hint: const Text("Seleziona chi farà il turno"),
                      ),
                      const SizedBox(height: 15),
                    ],
                    
                    // ORARI
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => selezionaOrario(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Inizio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                              child: Text(orarioInizio.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("-", style: TextStyle(fontSize: 20))),
                        Expanded(
                          child: InkWell(
                            onTap: () => selezionaOrario(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Fine', border: OutlineInputBorder()),
                              child: Text(orarioFine.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // SE E' UN DIPENDENTE, MOSTRA IL CAMPO CLIENTE
                    if (tipoEvento == 'Dipendente')
                      TextField(
                        controller: clienteController, 
                        decoration: const InputDecoration(labelText: 'Cliente / Mansione', border: OutlineInputBorder(), hintText: 'es. Consegne Hotel Miramare')
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () {
                    // Controlli di sicurezza
                    if (tipoEvento == 'Dipendente' && dipendenteSelezionato == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiungi e seleziona almeno un dipendente!'), backgroundColor: Colors.red));
                      return;
                    }

                    setState(() {
                      String orarioFormattato = "${orarioInizio.hour.toString().padLeft(2,'0')}:${orarioInizio.minute.toString().padLeft(2,'0')} - ${orarioFine.hour.toString().padLeft(2,'0')}:${orarioFine.minute.toString().padLeft(2,'0')}";
                      
                      if (inModifica) _listaTurni.remove(turnoDaModificare); 

                      int giorniDiDifferenza = dateRange.end.difference(dateRange.start).inDays;
                      
                      for (int i = 0; i <= giorniDiDifferenza; i++) {
                        DateTime giornoCalcolato = dateRange.start.add(Duration(days: i));
                        
                        if (tipoEvento == 'Panificio') {
                          _listaTurni.add({
                            "data": giornoCalcolato,
                            "tipo": "Panificio",
                            "orario": orarioFormattato,
                          });
                        } else {
                          String ruoloTrovato = _listaDipendenti.firstWhere((d) => d['nome'] == dipendenteSelezionato)['ruolo'];
                          _listaTurni.add({
                            "data": giornoCalcolato,
                            "tipo": "Dipendente",
                            "dipendente": dipendenteSelezionato,
                            "ruolo_dipendente": ruoloTrovato,
                            "cliente": clienteController.text.isNotEmpty ? clienteController.text : 'Lavoro in laboratorio',
                            "orario": orarioFormattato,
                          });
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text('Salva Evento/i', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dipendenti e Turni'), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Il Tuo Staff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ElevatedButton.icon(
                  onPressed: () => _apriFinestraDipendente(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuovo'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                )
              ],
            ),
            const SizedBox(height: 10),
            
            Expanded(
              flex: 1, 
              child: _listaDipendenti.isEmpty
                ? const Center(child: Text("Il tuo team è vuoto. Aggiungi il primo dipendente!"))
                : ListView.builder(
                itemCount: _listaDipendenti.length,
                itemBuilder: (context, index) {
                  final dipendente = _listaDipendenti[index];
                  final coloreRuolo = _colorePerRuolo(dipendente['ruolo']);
                  
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(side: BorderSide(color: coloreRuolo.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: coloreRuolo, child: const Icon(Icons.person, color: Colors.white)),
                      title: Text(dipendente['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${dipendente['ruolo']} - ${dipendente['dettagli']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _apriFinestraDipendente(indiceDaModificare: index)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _listaDipendenti.removeAt(index))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const Divider(height: 30, thickness: 3),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Calendario Turni', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filtroAttuale,
                          icon: const Icon(Icons.filter_list, color: Colors.indigo),
                          items: _ottieniOpzioniFiltro().map((String v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (nuovaScelta) { if (nuovaScelta != null) setState(() => _filtroAttuale = nuovaScelta); },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _apriFinestraTurno(),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                      child: const Icon(Icons.add),
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              flex: 1,
              child: CalendarioTurniWidget(
                turni: _listaTurni,
                filtroAttuale: _filtroAttuale,
                getColoreRuolo: _colorePerRuolo,
                onModificaTurno: (turno) => _apriFinestraTurno(turnoDaModificare: turno),
                onEliminaTurno: (turno) {
                  setState(() {
                    _listaTurni.remove(turno);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}