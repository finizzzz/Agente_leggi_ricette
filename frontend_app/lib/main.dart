import 'package:flutter/material.dart';
// Il main ora deve solo sapere dove si trova la Dashboard
import 'screens/dashboard.dart';

void main() {
  runApp(const PanificioApp());
}

class PanificioApp extends StatelessWidget {
  const PanificioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panificio IA',
      theme: ThemeData(
        primarySwatch: Colors.orange, 
      ),
      home: const DashboardHomePage(),
    );
  }
}