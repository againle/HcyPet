import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'presentation/pages/main_page.dart';
import 'presentation/widgets/debug_bar.dart';
import 'services/debug_config.dart';
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
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          titleSmall: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(color: Colors.white54, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          labelMedium: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
          labelSmall: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w400),
        ),
      ),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: DebugConfig.notifier,
        builder: (_, enabled, w) => Column(
          children: [
            Expanded(child: w!),
            if (enabled) const DebugBar(),
          ],
        ),
        child: child,
      ),
      home: BlocProvider(
        create: (_) => PetBloc(),
        child: const MainPage(),
      ),
    );
  }
}

