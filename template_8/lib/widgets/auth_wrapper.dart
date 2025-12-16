//
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home_screen.dart'; 
import '../screens/auth_screen.dart'; // 🔥 1. Виправлений імпорт (шлях до вашого файлу авторизації)

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // Поки вантажиться — показуємо спіннер
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Сталася помилка авторизації'),
            ),
          );
        }

        // Якщо юзер є — йдемо в Додому
        if (snapshot.hasData) {
          return const HomeScreen(); 
        }

        // 🔥 2. Виправлена назва класу: AuthScreen замість LoginScreen
        return const AuthScreen(); 
      },
    );
  }
}