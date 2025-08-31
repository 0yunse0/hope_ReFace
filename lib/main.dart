<<<<<<< HEAD
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'signup_page.dart';

Future<void> main() async {
=======
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'signup_page.dart';

void main() async {
>>>>>>> origin/main
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'ReFace',
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/signup': (_) => const SignUpPage(),
      },
      home: const LoginPage(), // 시작화면 = 로그인
=======
      title: 'Auth Test App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
>>>>>>> origin/main
    );
  }
}
