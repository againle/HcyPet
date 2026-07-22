import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'models/pet_state.dart';
import 'presentation/pet/pet_widget.dart';

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
      home: BlocProvider(
        create: (_) => PetBloc(),
        child: const TestPage(),
      ),
    );
  }
}

/// 测试 E：PetBloc + PetWidget + BottomNavigationBar
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: BlocBuilder<PetBloc, PetState>(
          builder: (context, state) {
            return PetWidget(state: state, size: 300);
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF4FC3F7),
        unselectedItemColor: const Color(0xFF4FC3F7).withOpacity(0.2),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: '主页'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '自习室'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '伴侣'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

