import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_screen.dart'; // <--- ДОДАЙТЕ ЦЕЙ ІМПОРТ

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    try {
      if (photoUrl.startsWith('http')) return NetworkImage(photoUrl);
      return MemoryImage(base64Decode(photoUrl));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Drawer();

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Бере колір з теми
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          String username = user.displayName ?? 'Користувач';
          String email = user.email ?? '';
          String? photoUrl;

          if (snapshot.hasData && snapshot.data!.data() != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            username = data['username'] ?? username;
            photoUrl = data['photoUrl'];
          }
          
          final imageProvider = _getImageProvider(photoUrl);
          final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
          
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                accountName: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                accountEmail: Text(email, style: const TextStyle(color: Colors.white70)),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', 
                        style: TextStyle(fontSize: 40.0, color: Theme.of(context).primaryColor))
                      : null,
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: textColor, size: 30),
                title: Text('Налаштування', style: TextStyle(color: textColor, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context); // Закриваємо меню
                  // Переходимо на екран налаштувань
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              Divider(color: textColor.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: textColor, size: 30),
                title: Text('Вийти', style: TextStyle(color: textColor, fontSize: 15)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}