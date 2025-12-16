import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Обробник фонових повідомлень (має бути поза класом, top-level функція)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Тут можна обробити повідомлення, коли додаток закритий (наприклад, зберегти в локальну БД)
  if (kDebugMode) {
    print('Handling a background message ${message.messageId}');
  }
}

// Глобальні змінні
late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
bool isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }

  // 1. 🔥 ЗАПИТ ДОЗВОЛУ (Критично для Android 13+)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('🔒 Статус дозволу на сповіщення: ${settings.authorizationStatus}');

  // 2. Налаштовуємо канал для Android (High Importance)
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id (має співпадати з AndroidManifest, якщо там прописано)
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max, // 🔥 MAX = спливаюче вікно + звук
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 3. Ініціалізація налаштувань для Android
  // '@mipmap/ic_launcher' — це стандартна іконка додатка. 
  // Переконайтеся, що вона існує в android/app/src/main/res/mipmap-*/
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // Налаштування для iOS (якщо плануєте в майбутньому)
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      // Тут можна обробити натискання на сповіщення
      print("🔔 Натиснули на сповіщення: ${details.payload}");
    },
  );

  // 4. Створюємо канал на пристрої
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 5. Налаштовуємо показ сповіщень у Foreground (коли додаток відкритий)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  isFlutterLocalNotificationsInitialized = true;
  print("✅ Сервіс сповіщень налаштовано");
}

// Допоміжна функція для ручного показу сповіщення
void showFlutterNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  
  if (notification != null && android != null && !kIsWeb) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          // Переконайтесь, що іконка існує, інакше додаток впаде
          icon: '@mipmap/ic_launcher', 
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}