import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_state.dart';
import 'home_page.dart';
import 'study_page.dart';
import 'partner_page.dart';
import 'settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    StudyPage(),
    PartnerPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<PetBloc, PetState>(
        builder: (context, state) {
          return _pages[_currentIndex];
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
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.pets_outlined, size: 22), activeIcon: Icon(Icons.pets, size: 22), label: '主页'),
            BottomNavigationBarItem(icon: Icon(Icons.book_outlined, size: 22), activeIcon: Icon(Icons.book, size: 22), label: '自习室'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border, size: 22), activeIcon: Icon(Icons.favorite, size: 22), label: '伴侣'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 22), activeIcon: Icon(Icons.settings, size: 22), label: '设置'),
          ],
        ),
      ),
    );
  }
}
