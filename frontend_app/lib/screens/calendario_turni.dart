import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarioTurniWidget extends StatefulWidget {
  final List<Map<String, dynamic>> turni;
  final String filtroAttuale;
  final Color Function(String) getColoreRuolo;
  final Function(Map<String, dynamic>) onModificaTurno;
  final Function(Map<String, dynamic>) onEliminaTurno;
  final CalendarFormat formatoCalendario; 

  const CalendarioTurniWidget({
    super.key,
    required this.turni,
    required this.filtroAttuale,
    required this.getColoreRuolo,
    required this.onModificaTurno,
    required this.onEliminaTurno,
    required this.formatoCalendario,
  });

  @override
  State<CalendarioTurniWidget> createState() => _CalendarioTurniWidgetState();
}

class _CalendarioTurniWidgetState extends State<CalendarioTurniWidget> {
  DateTime _giornoSelezionato = DateTime.now();
  DateTime _meseFocalizzato = DateTime.now();

  List<Map<String, dynamic>> _turniDelGiorno(DateTime giorno) {
    return widget.turni.where((turno) {
      bool stessoGiorno = isSameDay(turno['data'], giorno);
      if (!stessoGiorno) return false;
      if (widget.filtroAttuale == 'Tutti') return true;
      if (widget.filtroAttuale == 'Solo Panificio' && turno['tipo'] == 'Panificio') return true;
      if (turno['dipendente'] == widget.filtroAttuale) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final turniOggi = _turniDelGiorno(_giornoSelezionato);

    // LAYOUT AFFIANCATO: Sinistra Calendario, Destra Lista Turni
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- PARTE SINISTRA: IL CALENDARIO (Prende il 60% dello spazio) ---
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.shade100)),
            child: TableCalendar(
              locale: 'it_IT',
              startingDayOfWeek: StartingDayOfWeek.monday, 
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _meseFocalizzato,
              calendarFormat: widget.formatoCalendario, 
              
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              
              selectedDayPredicate: (day) => isSameDay(_giornoSelezionato, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _giornoSelezionato = selectedDay;
                  _meseFocalizzato = focusedDay; 
                });
              },
              eventLoader: _turniDelGiorno,
              
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.map((evento) {
                      final turno = evento as Map<String, dynamic>;
                      Color colorePallino = turno['tipo'] == 'Panificio' ? Colors.grey.shade800 : widget.getColoreRuolo(turno['ruolo_dipendente'] ?? '');
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: colorePallino,
                          border: Border.all(color: Colors.white, width: 1.0)
                        ), 
                        width: 10.0, 
                        height: 10.0
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 15),

        // --- PARTE DESTRA: I TURNI DEL GIORNO (Prende il 40% dello spazio) ---
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50.withOpacity(0.5), 
              borderRadius: BorderRadius.circular(15), 
              border: Border.all(color: Colors.indigo.shade100)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intestazione del pannello laterale
                Text(
                  "Eventi del ${DateFormat('dd/MM/yyyy').format(_giornoSelezionato)}", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)
                ),
                const SizedBox(height: 15),
                
                turniOggi.isEmpty
                    ? const Text('Nessun evento in questa data.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    // IMPORTANTE: shrinkWrap: true permette alla lista di non dare errore dentro la riga scorrimento
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: turniOggi.length,
                        itemBuilder: (context, index) {
                          final turno = turniOggi[index];
                          bool isPanificio = turno['tipo'] == 'Panificio';
                          Color coloreScheda = isPanificio ? Colors.grey.shade800 : widget.getColoreRuolo(turno['ruolo_dipendente'] ?? '');

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(side: BorderSide(color: coloreScheda, width: 2), borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(isPanificio ? Icons.storefront : Icons.person, color: coloreScheda, size: 30),
                              title: Text(isPanificio ? 'Apertura Panificio' : turno['dipendente'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text(isPanificio ? 'Orario: ${turno['orario']}' : 'Cliente: ${turno['cliente']}\nOrario: ${turno['orario']}'),
                              isThreeLine: !isPanificio,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => widget.onModificaTurno(turno)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => widget.onEliminaTurno(turno)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}