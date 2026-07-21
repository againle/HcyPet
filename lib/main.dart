import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'presentation/pages/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FATAL: ${details.exception}');
  };
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
          primary: const Color(0xFF4FC3F7),
          secondary: const Color(0xFF4FC3F7),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: BlocProvider(
        create: (context) => PetBloc(),
        child: const MainPage(),
      ),
    );
  }
}
