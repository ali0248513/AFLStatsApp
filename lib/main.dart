import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';  // This should now find HomeScreen

class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/afl.png',
          width: 160,
          height: 160,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "your-api-key",
        authDomain: "your-project-id.firebaseapp.com",
        projectId: "your-project-id",
        storageBucket: "your-project-id.appspot.com",
        messagingSenderId: "000000000000",
        appId: "1:000000000000:web:0000000000000000000000",
        measurementId: "G-0000000000"
      )
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(const AFLStatsApp());
}

class AFLStatsApp extends StatelessWidget {
  const AFLStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFL Stats Tracker',
      theme: ThemeData(
        primaryColor: Colors.red[900],
        fontFamily: 'RobotoCondensed',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.blue[900],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: FutureBuilder(
        future: Future.delayed(const Duration(seconds: 1)),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashLogo();
          }
          return const HomeScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}



