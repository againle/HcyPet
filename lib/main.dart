import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'presentation/pages/main_page.dart';
import 'theme/design_constants.dart';

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
        colorScheme: const ColorScheme.dark().copyWith(
          primary: kPrimaryColor,
          secondary: kPrimaryColor,
        ),
        scaffoldBackgroundColor: kBackgroundColor,
        fontFamily: kFontFamily,
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          displayMedium: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          displaySmall: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          headlineMedium: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          headlineSmall: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
          titleLarge: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          titleMedium: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          titleSmall: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
          bodyLarge: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
          bodyMedium: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
          bodySmall: TextStyle(color: Colors.white54, decoration: TextDecoration.none),
          labelLarge: TextStyle(color: Colors.white, decoration: TextDecoration.none),
          labelMedium: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
          labelSmall: TextStyle(color: kPrimaryColor, decoration: TextDecoration.none),
        ),
      ),
      home: BlocProvider(
        create: (_) => PetBloc(),
        child: const MainPage(),
      ),
    );
  }
}

