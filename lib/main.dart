import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/pet_bloc.dart';
import 'models/pet_state.dart';
import 'presentation/pet/pet_widget.dart';

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
        child: const TestPage(),
      ),
    );
  }
}

/// 测试 D：PetBloc + PetWidget（含 AnimationController 呼吸动画）
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: BlocBuilder<PetBloc, PetState>(
          builder: (context, state) {
            return PetWidget(
              state: state,
              size: 300,
            );
          },
        ),
      ),
    );
  }
}

