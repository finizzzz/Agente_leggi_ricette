import 'package:flutter/material.dart';

class PaginaDipendenti extends StatelessWidget {
  const PaginaDipendenti({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Dipendenti e Turni'), backgroundColor: Colors.indigo),
      body: const Center(child: Text('Qui metteremo il calendario turni', style: TextStyle(fontSize: 20))),
    );
  }
}