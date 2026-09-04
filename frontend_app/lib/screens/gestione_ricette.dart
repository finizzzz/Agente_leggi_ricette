import 'package:flutter/material.dart';

class PaginaRicette extends StatelessWidget {
  const PaginaRicette({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Ricette'), backgroundColor: Colors.teal),
      body: const Center(child: Text('Qui caricheremo i PDF e le ricette manuali', style: TextStyle(fontSize: 20))),
    );
  }
}