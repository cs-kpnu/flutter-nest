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
import 'package:flutter/foundation.dart' show kIsWeb; // Універсальна перевірка

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await setupFlutterNotifications(); 

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      await _saveFcmToken(user.uid);
    }
  });

  runApp(const MyApp());
}

Future<void> _saveFcmToken(String userId) async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    
    if (token != null) {
      await _firestoreInstance
          .collection('users')
          .doc(userId)
          .set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _firestoreInstance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': newToken});
      });
    }
  } catch (e) {
    debugPrint("⛔ FCM ERROR: $e");
  }
}

final _firestoreInstance = FirebaseFirestore.instance;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      ChatService.setActiveChatId(null);
    }
  }

  Future<void> _setOptimalDisplayMode() async {
    // Перевіряємо kIsWeb перед використанням плагінів, що працюють тільки на Android/iOS
    if (!kIsWeb) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        debugPrint("Error setting display mode: $e");
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