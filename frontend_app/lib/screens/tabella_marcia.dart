import 'package:flutter/material.dart';

class PaginaTabellaDiMarcia extends StatelessWidget {
  const PaginaTabellaDiMarcia({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> turniFinti = [
      {"orario": "06:00 - 06:18", "azione": "Impasto Finale", "macchina": "Impastatrice a spirale"},
      {"orario": "06:18 - 06:58", "azione": "Spezzatura e Formatura", "macchina": "Banco di lavoro"},
      {"orario": "06:58 - 07:23", "azione": "Cottura", "macchina": "Forno a piani"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabella di Marcia Operativa'),
        backgroundColor: Colors.orange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: turniFinti.length,
        itemBuilder: (context, index) {
          final turno = turniFinti[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.access_time, color: Colors.orange, size: 30),
              title: Text(turno["orario"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text("${turno["azione"]} su ${turno["macchina"]}", style: const TextStyle(fontSize: 16)),
              trailing: const Icon(Icons.check_circle_outline, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}