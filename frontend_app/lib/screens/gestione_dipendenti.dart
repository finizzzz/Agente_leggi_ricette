import 'package:flutter/material.dart';
import 'calendario_turni.dart';
import 'package:table_calendar/table_calendar.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class PaginaDipendenti extends StatefulWidget {
  const PaginaDipendenti({super.key});

  @override
  State<PaginaDipendenti> createState() => _PaginaDipendentiState();
}

class _PaginaDipendentiState extends State<PaginaDipendenti> {
  final List<Map<String, dynamic>> _listaDipendenti = [];
  final List<Map<String, dynamic>> _listaTurni = [];

  String _filtroAttuale = 'Tutti';
  bool _staCaricando = true;
  
  CalendarFormat _formatoCalendario = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _caricaDatiIniziali(); 
  }

  Future<void> _caricaDatiIniziali() async {
    setState(() => _staCaricando = true);
    await Future.wait([_scaricaDipendenti(), _scaricaTurni()]);
    setState(() => _staCaricando = false);
  }

  Future<void> _scaricaDipendenti() async {
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/dipendenti'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          _listaDipendenti.clear();
          for (var dip in datiTradotti['dati']) {
            _listaDipendenti.add({
              "id": dip['id'],
              "nome": dip['nome'],
              "ruolo": dip['ruolo'],
              "turno_inizio": dip['turno_inizio'],
              "turno_fine": dip['turno_fine'],
              "dettagli": "Turno base: ${dip['turno_inizio']} - ${dip['turno_fine']}"
            });
          }
        }
      }
    } catch (e) { print("Errore GET Dipendenti: $e"); }
  }

  Future<void> _salvaDipendenteSulServer(Map<String, dynamic> dati, {int? idEsistente}) async {
    setState(() => _staCaricando = true);
    try {
      http.Response risposta;
      String corpoJson = json.encode(dati);
      if (idEsistente == null) {
        risposta = await http.post(Uri.parse('http://127.0.0.1:8000/dipendenti'), headers: {"Content-Type": "application/json"}, body: corpoJson);
      } else {
        risposta = await http.put(Uri.parse('http://127.0.0.1:8000/dipendenti/$idEsistente'), headers: {"Content-Type": "application/json"}, body: corpoJson);
      }
      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff aggiornato!'), backgroundColor: Colors.green));
      }
    } catch (e) { print("Errore Salva Dipendente: $e"); }
    await _scaricaDipendenti();
    setState(() => _staCaricando = false);
  }

  Future<void> _eliminaDipendente(int idDipendente) async {
    setState(() => _staCaricando = true);
    try {
      final risposta = await http.delete(Uri.parse('http://127.0.0.1:8000/dipendenti/$idDipendente'));
      if (risposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dipendente rimosso dal sistema!'), backgroundColor: Colors.red));
      }
    } catch (e) { print("Errore DELETE: $e"); }
    await _scaricaDipendenti();
    setState(() => _staCaricando = false);
  }

  Future<void> _scaricaTurni() async {
    try {
      final risposta = await http.get(Uri.parse('http://127.0.0.1:8000/turni'));
      if (risposta.statusCode == 200) {
        final datiTradotti = json.decode(risposta.body);
        if (datiTradotti['successo'] == true) {
          _listaTurni.clear();
          for (var t in datiTradotti['dati']) {
            _listaTurni.add({
              "id": t['id'],
              "data": DateTime.parse(t['data_turno']), 
              "tipo": t['tipo'],
              "dipendente": t['dipendente'],
              "ruolo_dipendente": t['ruolo_dipendente'],
              "cliente": t['cliente'],
              "orario": t['orario']
            });
          }
        }
      }
    } catch (e) { print("Errore GET Turni: $e"); }
  }

  void _chiediConfermaEliminazioneTurno(Map<String, dynamic> turnoBase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text('Elimina Evento/i')]),
        content: const Text('Vuoi eliminare solo questo turno o anche tutti i turni programmati successivi per questo dipendente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eseguiEliminazioneTurni(turnoBase, false); 
            },
            child: const Text('Solo questo'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eseguiEliminazioneTurni(turnoBase, true); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Questo e successivi', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  Future<void> _eseguiEliminazioneTurni(Map<String, dynamic> turnoBase, bool eliminaSuccessivi) async {
    setState(() => _staCaricando = true);
    List<Future> chiamateApi = [];

    if (!eliminaSuccessivi) {
      chiamateApi.add(http.delete(Uri.parse('http://127.0.0.1:8000/turni/${turnoBase['id']}')));
    } else {
      for (var t in _listaTurni) {
        if (t['dipendente'] == turnoBase['dipendente'] && t['tipo'] == turnoBase['tipo']) {
          if (!t['data'].isBefore(turnoBase['data'])) {
            chiamateApi.add(http.delete(Uri.parse('http://127.0.0.1:8000/turni/${t['id']}')));
          }
        }
      }
    }

    try {
      await Future.wait(chiamateApi);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operazione completata!'), backgroundColor: Colors.red));
    } catch (e) { print("Errore Multi-Delete: $e"); }
    
    await _scaricaTurni();
    setState(() => _staCaricando = false);
  }

  Color _colorePerRuolo(String ruolo) {
    if (ruolo == 'Mastro Panettiere') return Colors.orange.shade700;
    if (ruolo == 'Addetto Forni') return Colors.red.shade600;
    if (ruolo == 'Aiuto Fornaio') return Colors.blue.shade600;
    if (ruolo == 'Addetto Consegne') return Colors.green.shade600;
    return Colors.indigo;
  }

  List<String> _ottieniOpzioniFiltro() {
    List<String> opzioni = ['Tutti', 'Solo Panificio'];
    for (var dip in _listaDipendenti) opzioni.add(dip['nome']);
    return opzioni;
  }

  void _apriFinestraDipendente({Map<String, dynamic>? dipendenteEsistente}) {
    bool inModifica = dipendenteEsistente != null;
    int? idDipendente = inModifica ? dipendenteEsistente['id'] : null;

    String ruoloSelezionato = inModifica ? dipendenteEsistente['ruolo'] : 'Aiuto Fornaio';
    final TextEditingController nomeController = TextEditingController(text: inModifica ? dipendenteEsistente['nome'] : '');
    TimeOfDay orarioInizio = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay orarioFine = const TimeOfDay(hour: 14, minute: 0);

    if (inModifica && dipendenteEsistente['turno_inizio'] != null) {
      try {
         List<String> inizioSplit = dipendenteEsistente['turno_inizio'].toString().split(':');
         List<String> fineSplit = dipendenteEsistente['turno_fine'].toString().split(':');
         orarioInizio = TimeOfDay(hour: int.parse(inizioSplit[0]), minute: int.parse(inizioSplit[1]));
         orarioFine = TimeOfDay(hour: int.parse(fineSplit[0]), minute: int.parse(fineSplit[1]));
      } catch (e) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> selezionaOrario(bool isInizio) async {
              final TimeOfDay? orarioScelto = await showTimePicker(context: context, initialTime: isInizio ? orarioInizio : orarioFine);
              if (orarioScelto != null) setStateDialog(() => isInizio ? orarioInizio = orarioScelto : orarioFine = orarioScelto);
            }

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
                      items: ['Mastro Panettiere', 'Addetto Forni', 'Aiuto Fornaio', 'Addetto Consegne', 'Pasticcere'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setStateDialog(() => ruoloSelezionato = val!),
                    ),
                    const SizedBox(height: 15),
                    const Text('Turno Base:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Expanded(child: InkWell(onTap: () => selezionaOrario(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Inizio'), child: Text(orarioInizio.format(context))))),
                        const SizedBox(width: 10),
                        Expanded(child: InkWell(onTap: () => selezionaOrario(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Fine'), child: Text(orarioFine.format(context))))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () {
                    if (nomeController.text.isNotEmpty) {
                        String oraInizioStr = "${orarioInizio.hour.toString().padLeft(2, '0')}:${orarioInizio.minute.toString().padLeft(2, '0')}:00";
                        String oraFineStr = "${orarioFine.hour.toString().padLeft(2, '0')}:${orarioFine.minute.toString().padLeft(2, '0')}:00";
                        final pacchetto = {"nome": nomeController.text, "ruolo": ruoloSelezionato, "turno_inizio": oraInizioStr, "turno_fine": oraFineStr};
                        _salvaDipendenteSulServer(pacchetto, idEsistente: idDipendente);
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

  void _apriFinestraTurno({Map<String, dynamic>? turnoDaModificare}) {
    if (_listaDipendenti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiungi prima un dipendente!'), backgroundColor: Colors.red));
      return;
    }

    bool inModifica = turnoDaModificare != null;
    String tipoEvento = inModifica ? turnoDaModificare['tipo'] : 'Dipendente';
    DateTime dataBase = inModifica ? turnoDaModificare['data'] : DateTime.now();
    DateTimeRange dateRange = DateTimeRange(start: dataBase, end: dataBase);
    
    String modalitaModifica = 'Solo questo turno';
    String tipoRipetizione = 'Nessuna (Solo i giorni scelti)';
    DateTime dataFineRipetizione = dataBase.add(const Duration(days: 30));
    
    String? dipendenteSelezionato = (inModifica && tipoEvento == 'Dipendente') ? turnoDaModificare['dipendente'] : _listaDipendenti.first['nome'];
    final TextEditingController clienteController = TextEditingController(text: (inModifica && tipoEvento == 'Dipendente') ? turnoDaModificare['cliente'] : '');
    
    TimeOfDay orarioInizio = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay orarioFine = const TimeOfDay(hour: 14, minute: 0);

    if (inModifica) {
      try {
        List<String> orari = turnoDaModificare['orario'].split(' - ');
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
                context: context, initialDateRange: dateRange, firstDate: DateTime(2020), lastDate: DateTime(2030),
                initialEntryMode: DatePickerEntryMode.calendarOnly, locale: const Locale('it', 'IT'),
                cancelText: 'ANNULLA', confirmText: 'CONFERMA', helpText: 'SELEZIONA PERIODO (INIZIO E FINE)',
              );
              if (rangeScelto != null) setStateDialog(() => dateRange = rangeScelto);
            }

            Future<void> selezionaDataFineRipetizione() async {
              final DateTime? dataScelta = await showDatePicker(
                context: context, initialDate: dataFineRipetizione, firstDate: dateRange.start, lastDate: DateTime(2030),
                initialEntryMode: DatePickerEntryMode.calendarOnly, locale: const Locale('it', 'IT'),
                cancelText: 'ANNULLA', confirmText: 'CONFERMA', helpText: 'SELEZIONA DATA FINE RIPETIZIONE',
              );
              if (dataScelta != null) setStateDialog(() => dataFineRipetizione = dataScelta);
            }

            Future<void> selezionaOrario(bool isInizio) async {
              final TimeOfDay? orarioScelto = await showTimePicker(context: context, initialTime: isInizio ? orarioInizio : orarioFine);
              if (orarioScelto != null) setStateDialog(() => isInizio ? orarioInizio = orarioScelto : orarioFine = orarioScelto);
            }

            String testoData = dateRange.start.isAtSameMomentAs(dateRange.end) 
                ? DateFormat('dd/MM/yyyy').format(dateRange.start) 
                : "${DateFormat('dd/MM').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}";

            return AlertDialog(
              title: Text(inModifica ? 'Modifica Evento' : 'Nuovo Evento Multiplo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    if (inModifica) ...[
                      DropdownButtonFormField<String>(
                        value: modalitaModifica,
                        decoration: const InputDecoration(labelText: 'Applica le modifiche a:', filled: true, fillColor: Color(0xFFFFF3E0)),
                        items: ['Solo questo turno', 'Questo e i turni successivi'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)))).toList(),
                        onChanged: (val) => setStateDialog(() => modalitaModifica = val!),
                      ),
                      const SizedBox(height: 15),
                    ],

                    DropdownButtonFormField<String>(
                      value: tipoEvento,
                      decoration: const InputDecoration(labelText: 'Tipo Evento'),
                      items: const [DropdownMenuItem(value: 'Dipendente', child: Text('Turno Staff')), DropdownMenuItem(value: 'Panificio', child: Text('Orari Negozio'))],
                      onChanged: (val) => setStateDialog(() => tipoEvento = val!),
                    ),
                    const SizedBox(height: 15),
                    
                    if (!inModifica) ...[
                      InkWell(onTap: selezionaDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Giorno Base o Periodo Iniziale'), child: Text(testoData, style: const TextStyle(fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: tipoRipetizione,
                        decoration: const InputDecoration(labelText: 'Ripetizione Automatica', filled: true, fillColor: Color(0xFFF3E5F5)), 
                        items: ['Nessuna (Solo i giorni scelti)', 'Tutti i giorni', 'Ogni settimana (Stesso giorno)'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)))).toList(),
                        onChanged: (val) => setStateDialog(() => tipoRipetizione = val!),
                      ),
                      const SizedBox(height: 10),
                      if (tipoRipetizione != 'Nessuna (Solo i giorni scelti)')
                        InkWell(
                          onTap: selezionaDataFineRipetizione, 
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Fino alla data:'), 
                            child: Text(DateFormat('dd/MM/yyyy').format(dataFineRipetizione), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
                          )
                        ),
                      const SizedBox(height: 15),
                    ],

                    if (inModifica)
                       InputDecorator(decoration: const InputDecoration(labelText: 'Data del Turno Originale'), child: Text(DateFormat('dd/MM/yyyy').format(dataBase), style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 15),

                    if (tipoEvento == 'Dipendente')
                      DropdownButtonFormField<String>(
                        value: dipendenteSelezionato,
                        decoration: const InputDecoration(labelText: 'Dipendente'),
                        items: _listaDipendenti.map((d) => DropdownMenuItem<String>(value: d['nome'], child: Text(d['nome']))).toList(),
                        onChanged: (val) => setStateDialog(() => dipendenteSelezionato = val),
                      ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: InkWell(onTap: () => selezionaOrario(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Inizio'), child: Text(orarioInizio.format(context))))),
                        const SizedBox(width: 10),
                        Expanded(child: InkWell(onTap: () => selezionaOrario(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Fine'), child: Text(orarioFine.format(context))))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (tipoEvento == 'Dipendente')
                      TextField(controller: clienteController, decoration: const InputDecoration(labelText: 'Cliente / Mansione')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () async {
                    String orarioFormattato = "${orarioInizio.hour.toString().padLeft(2,'0')}:${orarioInizio.minute.toString().padLeft(2,'0')} - ${orarioFine.hour.toString().padLeft(2,'0')}:${orarioFine.minute.toString().padLeft(2,'0')}";
                    List<Future> chiamateApi = [];

                    if (inModifica) {
                      if (modalitaModifica == 'Solo questo turno') {
                        String dipDef = tipoEvento == 'Panificio' ? "" : (dipendenteSelezionato ?? "");
                        String ruoloDef = tipoEvento == 'Panificio' ? "" : _listaDipendenti.firstWhere((d) => d['nome'] == dipendenteSelezionato, orElse: () => {"ruolo": ""})['ruolo'];
                        String cliDef = tipoEvento == 'Panificio' ? "" : (clienteController.text.isNotEmpty ? clienteController.text : 'Lavoro interno');
                        String dataSql = "${turnoDaModificare['data'].year}-${turnoDaModificare['data'].month.toString().padLeft(2,'0')}-${turnoDaModificare['data'].day.toString().padLeft(2,'0')}";
                        
                        var payload = {"data_turno": dataSql, "tipo": tipoEvento, "dipendente": dipDef, "ruolo_dipendente": ruoloDef, "cliente": cliDef, "orario": orarioFormattato};
                        chiamateApi.add(http.put(Uri.parse('http://127.0.0.1:8000/turni/${turnoDaModificare['id']}'), headers: {"Content-Type": "application/json"}, body: json.encode(payload)));
                      } else {
                        for (var t in _listaTurni) {
                          if (t['dipendente'] == turnoDaModificare['dipendente'] && t['tipo'] == turnoDaModificare['tipo']) {
                            if (!t['data'].isBefore(turnoDaModificare['data'])) {
                              String dipDef = tipoEvento == 'Panificio' ? "" : (dipendenteSelezionato ?? "");
                              String ruoloDef = tipoEvento == 'Panificio' ? "" : _listaDipendenti.firstWhere((d) => d['nome'] == dipendenteSelezionato, orElse: () => {"ruolo": ""})['ruolo'];
                              String cliDef = tipoEvento == 'Panificio' ? "" : (clienteController.text.isNotEmpty ? clienteController.text : 'Lavoro interno');
                              String dataSql = "${t['data'].year}-${t['data'].month.toString().padLeft(2,'0')}-${t['data'].day.toString().padLeft(2,'0')}";
                              
                              var payloadF = {"data_turno": dataSql, "tipo": tipoEvento, "dipendente": dipDef, "ruolo_dipendente": ruoloDef, "cliente": cliDef, "orario": orarioFormattato};
                              chiamateApi.add(http.put(Uri.parse('http://127.0.0.1:8000/turni/${t['id']}'), headers: {"Content-Type": "application/json"}, body: json.encode(payloadF)));
                            }
                          }
                        }
                      }
                    } else {
                      List<DateTime> giorniBase = [];
                      int giorniSelezionati = dateRange.end.difference(dateRange.start).inDays;
                      for(int i = 0; i <= giorniSelezionati; i++) {
                        giorniBase.add(dateRange.start.add(Duration(days: i)));
                      }

                      List<DateTime> dateFinali = [];
                      for (DateTime giornoBase in giorniBase) {
                        if (tipoRipetizione == 'Nessuna (Solo i giorni scelti)') {
                           dateFinali.add(giornoBase);
                        } else if (tipoRipetizione == 'Tutti i giorni') {
                           DateTime cursore = giornoBase;
                           while(!cursore.isAfter(dataFineRipetizione)) {
                              if (!dateFinali.any((d) => d.year == cursore.year && d.month == cursore.month && d.day == cursore.day)) dateFinali.add(cursore);
                              cursore = cursore.add(const Duration(days: 1));
                           }
                        } else if (tipoRipetizione == 'Ogni settimana (Stesso giorno)') {
                           DateTime cursore = giornoBase;
                           while(!cursore.isAfter(dataFineRipetizione)) {
                              if (!dateFinali.any((d) => d.year == cursore.year && d.month == cursore.month && d.day == cursore.day)) dateFinali.add(cursore);
                              cursore = cursore.add(const Duration(days: 7));
                           }
                        }
                      }

                      dateFinali.sort((a, b) => a.compareTo(b));
                      for (int i = 0; i < dateFinali.length; i++) {
                        DateTime giornoCalcolato = dateFinali[i];
                        String dataSql = "${giornoCalcolato.year}-${giornoCalcolato.month.toString().padLeft(2,'0')}-${giornoCalcolato.day.toString().padLeft(2,'0')}";
                        String dipDef = tipoEvento == 'Panificio' ? "" : (dipendenteSelezionato ?? "");
                        String ruoloDef = tipoEvento == 'Panificio' ? "" : _listaDipendenti.firstWhere((d) => d['nome'] == dipendenteSelezionato, orElse: () => {"ruolo": ""})['ruolo'];
                        String cliDef = tipoEvento == 'Panificio' ? "" : (clienteController.text.isNotEmpty ? clienteController.text : 'Lavoro interno');
                        var payload = {"data_turno": dataSql, "tipo": tipoEvento, "dipendente": dipDef, "ruolo_dipendente": ruoloDef, "cliente": cliDef, "orario": orarioFormattato};
                        chiamateApi.add(http.post(Uri.parse('http://127.0.0.1:8000/turni'), headers: {"Content-Type": "application/json"}, body: json.encode(payload)));
                      }
                    }

                    Navigator.pop(context);
                    setState(() => _staCaricando = true);
                    try {
                      await Future.wait(chiamateApi);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operazione completata e sincronizzata!'), backgroundColor: Colors.green));
                    } catch(e) { print("Errore Multi-Salvataggio: $e"); }
                    await _scaricaTurni(); 
                    setState(() => _staCaricando = false);
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
      
      // LA NOVITA': LO SCROLL SU TUTTA LA PAGINA
      body: _staCaricando 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                // --- SEZIONE 1: STAFF ---
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
                
                // La lista dello staff usa shrinkWrap per adattarsi allo scroll generale
                _listaDipendenti.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text("Il tuo team è vuoto. Aggiungi personale!"))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _apriFinestraDipendente(dipendenteEsistente: dipendente)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminaDipendente(dipendente['id'])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                
                const Divider(height: 40, thickness: 3),
                
                // --- SEZIONE 2: CALENDARIO ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calendario Turni', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.indigo), borderRadius: BorderRadius.circular(10)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CalendarFormat>(
                              value: _formatoCalendario,
                              icon: const Icon(Icons.calendar_view_month, color: Colors.indigo),
                              items: const [
                                DropdownMenuItem(value: CalendarFormat.month, child: Text('Mese', style: TextStyle(fontWeight: FontWeight.bold))),
                                DropdownMenuItem(value: CalendarFormat.twoWeeks, child: Text('14 Giorni', style: TextStyle(fontWeight: FontWeight.bold))),
                                DropdownMenuItem(value: CalendarFormat.week, child: Text('Settimana', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              onChanged: (nuovoFormato) { 
                                if (nuovoFormato != null) setState(() => _formatoCalendario = nuovoFormato); 
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                
                // CALENDARIO E LISTA TURNI NEL LORO WIDGET
                CalendarioTurniWidget(
                  turni: _listaTurni,
                  filtroAttuale: _filtroAttuale,
                  getColoreRuolo: _colorePerRuolo,
                  formatoCalendario: _formatoCalendario, 
                  onModificaTurno: (turno) => _apriFinestraTurno(turnoDaModificare: turno),
                  onEliminaTurno: (turno) => _chiediConfermaEliminazioneTurno(turno),
                ),
              ],
            ),
          ),
    );
  }
}