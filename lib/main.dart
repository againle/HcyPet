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
        child: const HomePage(),
      ),
    );
  }
}

