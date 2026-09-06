import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarioTurniWidget extends StatefulWidget {
  final List<Map<String, dynamic>> turni;
  final String filtroAttuale;
  final Color Function(String) getColoreRuolo;
  final Function(Map<String, dynamic>) onModificaTurno;
  final Function(Map<String, dynamic>) onEliminaTurno;

  const CalendarioTurniWidget({
    super.key,
    required this.turni,
    required this.filtroAttuale,
    required this.getColoreRuolo,
    required this.onModificaTurno,
    required this.onEliminaTurno,
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

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: TableCalendar(
            locale: 'it_IT',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _meseFocalizzato,
            selectedDayPredicate: (day) => isSameDay(_giornoSelezionato, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _giornoSelezionato = selectedDay;
                _meseFocalizzato = focusedDay; 
              });
            },
            calendarFormat: CalendarFormat.week,
            eventLoader: _turniDelGiorno,
            
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.map((evento) {
                    final turno = evento as Map<String, dynamic>;
                    Color colorePallino = turno['tipo'] == 'Panificio' 
                        ? Colors.grey.shade800 
                        : widget.getColoreRuolo(turno['ruolo_dipendente']);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colorePallino),
                      width: 8.0,
                      height: 8.0,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 15),
        
        Expanded(
          child: turniOggi.isEmpty
              ? const Center(child: Text('Nessun turno per questa data o filtro.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
              : ListView.builder(
                  itemCount: turniOggi.length,
                  itemBuilder: (context, index) {
                    final turno = turniOggi[index];
                    bool isPanificio = turno['tipo'] == 'Panificio';
                    Color coloreScheda = isPanificio ? Colors.grey.shade800 : widget.getColoreRuolo(turno['ruolo_dipendente']);

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: coloreScheda, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Icon(isPanificio ? Icons.storefront : Icons.person, color: coloreScheda, size: 30),
                        title: Text(
                          isPanificio ? 'Apertura Panificio' : turno['dipendente'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                        ),
                        subtitle: Text(isPanificio 
                            ? 'Orario: ${turno['orario']}' 
                            : 'Cliente: ${turno['cliente']} | Orario: ${turno['orario']}'),
                        
                        // ORA I BOTTONI CI SONO SEMPRE, ANCHE PER IL PANIFICIO!
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => widget.onModificaTurno(turno),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => widget.onEliminaTurno(turno),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}