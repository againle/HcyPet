import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'bloc/pet_bloc.dart';
import 'presentation/pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Firebase 手动初始化（Info.plist 中禁用了自动配置）
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase 初始化失败不阻塞启动
  }

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
