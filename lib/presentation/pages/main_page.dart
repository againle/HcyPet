import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_state.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<PetBloc, PetState>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 80, color: Color(0xFF4FC3F7)),
                const SizedBox(height: 20),
                Text(
                  '宠物: ${state.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '心情: ${state.mood.displayName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF4FC3F7).withOpacity(0.05),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFF4FC3F7),
          unselectedItemColor: const Color(0xFF4FC3F7).withOpacity(0.2),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.pets_outlined), label: '主页'),
            BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: '自习'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: '伴侣'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '设置'),
          ],
        ),
      ),
    );
  }
}
