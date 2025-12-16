import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme_manager.dart';
import 'widgets/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'dart:io'; // Щоб перевірити, чи це Android

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await setupFlutterNotifications(); 

  // 🔥 ЗАПУСКАЄМО СЛУХАЧА АВТОРИЗАЦІЇ
  // Цей код спрацює автоматично, як тільки Firebase згадає, хто залогінений
  // або коли ви увійдете в акаунт.
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      print("👤 ЮЗЕР ВИЯВЛЕНИЙ: ${user.uid}. Пробуємо зберегти токен...");
      await _saveFcmToken(user.uid);
    } else {
      print("👤 ЮЗЕР НЕ ЗАЛОГІНЕНИЙ");
    }
  });

  runApp(const MyApp());
}

// 🔥 ОКРЕМА ФУНКЦІЯ ДЛЯ ЗБЕРЕЖЕННЯ ТОКЕНА
Future<void> _saveFcmToken(String userId) async {
  try {
    // 1. Отримуємо токен
    String? token = await FirebaseMessaging.instance.getToken();
    
    if (token != null) {
      print("🔔 ОТРИМАНО ТОКЕН: $token");

      // 2. Пишемо в базу
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
            'fcmToken': token,
            'deviceInfo': 'Android/iOS', // Можна додати для дебагу
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)) // Важливо: merge, щоб не стерти інші поля
          .then((_) => print("✅✅✅ ТОКЕН УСПІШНО ЗАПИСАНО В FIREBASE!"))
          .catchError((error) => print("⛔⛔⛔ ПОМИЛКА ЗАПИСУ В БД: $error"));
          
      // 3. Також слухаємо оновлення токена (якщо він зміниться під час роботи)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': newToken});
        print("🔄 Токен оновлено автоматично");
      });
    } else {
      print("⚠️ Токен не отримано (null)");
    }
  } catch (e) {
    print("⛔ КРИТИЧНА ПОМИЛКА FCM: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

Future<void> _setHighRefreshRate() async {
  if (Platform.isAndroid) {
    try {
      // Цей метод автоматично шукає і ставить максимальну доступну частоту (90, 120, 144 Гц)
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      print("Error setting high refresh rate: $e");
    }
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setHighRefreshRate(); 
    _setOptimalDisplayMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      print('📱 Додаток у фоні, очищаємо активний чат');
      ChatService.setActiveChatId(null);
    }
  }

Future<void> _setOptimalDisplayMode() async {
    if (Platform.isAndroid) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        print("Error setting display mode: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Chat App',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const AuthWrapper(),
        );
      },
    );
  
  }

}