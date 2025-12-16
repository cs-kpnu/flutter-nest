import 'dart:convert'; // Для base64Encode
import 'dart:io'; // Для роботи з файлами
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // <--- Імпорт пікера
import '../theme_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // Хелпер для відображення картинки (той самий, що в інших файлах)
  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    try {
      if (photoUrl.startsWith('http')) return NetworkImage(photoUrl);
      return MemoryImage(base64Decode(photoUrl));
    } catch (e) {
      return null;
    }
  }

  // --- ЗМІНА АВАТАРКИ ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    // imageQuality: 50 і maxWidth: 400 дуже важливі для Base64 у Firestore,
    // інакше розмір рядка перевищить ліміти і база видасть помилку.
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 50, 
      maxWidth: 400
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      // Читаємо файл у байти
      final bytes = await File(image.path).readAsBytes();
      // Конвертуємо у Base64 рядок
      final base64String = base64Encode(bytes);

      // Оновлюємо Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'photoUrl': base64String,
      });

      // Оновлюємо Auth (опціонально, але корисно)
      // Примітка: Auth очікує URL, але ми можемо технічно зберегти і рядок, 
      // проте основне джерело правди у нас - Firestore.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аватарку оновлено!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка завантаження: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ЗМІНА ТЕМИ ---
  void _toggleTheme(bool isDark) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // --- ЗМІНА НІКНЕЙМУ ---
  Future<void> _changeUsername() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Змінити нікнейм'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Новий нікнейм"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Скасувати")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                final newName = controller.text.trim();
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'username': newName,
                  'searchKey': newName.toLowerCase(),
                });
                await user!.updateDisplayName(newName);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нікнейм оновлено!')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Зберегти"),
          ),
        ],
      ),
    );
  }

  // --- ЗМІНА ПАРОЛЮ ---
  Future<void> _changePassword() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Змінити пароль'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Новий пароль (мін. 6 символів)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Скасувати")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль занадто короткий')));
                return;
              }
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await user!.updatePassword(controller.text.trim());
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль успішно змінено!')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e. Спробуйте вийти і зайти знову.')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Зберегти"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(title: const Text("Налаштування")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              // Підписуємось на зміни користувача, щоб аватар оновлювався миттєво
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                
                String? photoUrl;
                if (snapshot.hasData && snapshot.data!.data() != null) {
                   photoUrl = (snapshot.data!.data() as Map<String, dynamic>)['photoUrl'];
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // --- Секція Аватарки ---
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _getImageProvider(photoUrl),
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text("Зовнішній вигляд", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    SwitchListTile(
                      title: Text(
                        "Темна тема",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      secondary: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      value: isDarkMode,
                      onChanged: _toggleTheme,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.grey.withOpacity(0.5),
                      inactiveThumbColor: Colors.blueGrey,
                      inactiveTrackColor: Colors.grey[300],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text("Обліковий запис", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ListTile(
                      leading: Icon(Icons.person, color: Theme.of(context).iconTheme.color),
                      title: Text("Змінити нікнейм", style: TextStyle(color: textColor)),
                      subtitle: Text(user?.displayName ?? '', style: const TextStyle(color: Colors.grey)),
                      onTap: _changeUsername,
                    ),
                    ListTile(
                      leading: Icon(Icons.lock, color: Theme.of(context).iconTheme.color),
                      title: Text("Змінити пароль", style: TextStyle(color: textColor)),
                      onTap: _changePassword,
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_active, color: Colors.orange),
                      title: const Text("Отримати FCM Token (для тестів)"),
                      subtitle: const Text("Натисніть, щоб скопіювати в буфер"),
                      onTap: () async {
                        // 1. Отримуємо токен
                        final token = await FirebaseMessaging.instance.getToken();
                        
                        // 2. Виводимо в консоль (про всяк випадок)
                        print("🔥 ВАШ ТОКЕН: $token");

                        // 3. Копіюємо в буфер обміну телефону
                        if (token != null) {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Токен скопійовано!')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              }
            ),
    );
  }
}