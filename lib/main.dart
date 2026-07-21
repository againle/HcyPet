import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('HcyPet', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 24)),
      ),
    ),
  ));
}

