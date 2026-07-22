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

  static const _textTheme = TextTheme(
    bodyLarge: TextStyle(color: Colors.white70, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
    bodySmall: TextStyle(color: Colors.white54, fontSize: 12),
    titleMedium: TextStyle(color: Colors.white, fontSize: 16),
    labelSmall: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HcyPet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF4FC3F7),
          secondary: const Color(0xFF4FC3F7),
        ),
        scaffoldBackgroundColor: Colors.black,
        textTheme: _textTheme,
        useMaterial3: false,
      ),
      home: BlocProvider(
        create: (_) => PetBloc(),
        child: const HomePage(),
      ),
    );
  }
}

