import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_state.dart';
import '../../theme/design_constants.dart';
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
      backgroundColor: kBackgroundColor,
      body: BlocBuilder<PetBloc, PetState>(
        builder: (context, state) {
          return IndexedStack(
            index: _currentIndex,
            children: _pages,
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0x0D4FC3F7), // #4FC3F7 @ 5%
              width: BottomNavSpec.borderWidth,
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
          backgroundColor: kBackgroundColor,
          selectedItemColor: BottomNavSpec.selectedColor,
          unselectedItemColor: BottomNavSpec.unselectedColor,
          selectedFontSize: 0,
          unselectedFontSize: 0,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(AppIcons.home, size: BottomNavSpec.iconSize),
              activeIcon: Icon(AppIcons.homeActive, size: BottomNavSpec.iconSize),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(AppIcons.study, size: BottomNavSpec.iconSize),
              activeIcon: Icon(AppIcons.studyActive, size: BottomNavSpec.iconSize),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(AppIcons.partner, size: BottomNavSpec.iconSize),
              activeIcon: Icon(AppIcons.partnerActive, size: BottomNavSpec.iconSize),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(AppIcons.settings, size: BottomNavSpec.iconSize),
              activeIcon: Icon(AppIcons.settingsActive, size: BottomNavSpec.iconSize),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
