import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'presentation/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HcyPetApp());
}

class HcyPetApp extends StatelessWidget {
  const HcyPetApp({super.key});

  static const _defaultTextStyle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HcyPet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF4FC3F7),
          secondary: const Color(0xFF4FC3F7),
        ),
        scaffoldBackgroundColor: Colors.black,
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
          labelSmall: TextStyle(color: Color(0xFF4FC3F7), decoration: TextDecoration.none),
        ),
        useMaterial3: false,
      ),
      builder: (context, child) => DefaultTextStyle.merge(
        style: _defaultTextStyle,
        child: child!,
      ),
      home: BlocProvider(
        create: (_) => PetBloc(),
        child: const HomePage(),
      ),
    );
  }
}

