import 'package:flutter/material.dart';

class PaginaMacchinari extends StatelessWidget {
  const PaginaMacchinari({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Macchinari'), backgroundColor: Colors.blueGrey),
      body: const Center(child: Text('Qui metteremo la lista dei macchinari', style: TextStyle(fontSize: 20))),
    );
  }
}