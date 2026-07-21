import 'package:flutter/material.dart';
import 'models/pet_state.dart';
import 'presentation/pet/pet_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HcyPetApp());
}

class HcyPetApp extends StatelessWidget {
  const HcyPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HcyPet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const TestPage(),
    );
  }
}

/// 测试 B：只用 CustomPaint + PetPainter，不加载 PetBloc
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CustomPaint(
          size: const Size(300, 300),
          painter: PetPainter(
            state: PetState.initial(),
            size: 300,
          ),
        ),
      ),
    );
  }
}

