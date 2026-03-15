import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../widgets/profile_drawer.dart';
import 'search_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd.MM').format(date);
  }

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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Messenger'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
          ),
        ],
      ),
      drawer: const ProfileDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Помилка: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Немає чатів. Почніть спілкування через пошук!'),
                ],
              ),
            );
          }
          
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final t1 = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp? ?? Timestamp(0, 0);
            final t2 = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp? ?? Timestamp(0, 0);
            return t2.compareTo(t1);
          });

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8),
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              
              final otherUserId = (chatData['participants'] as List).firstWhere(
                (id) => id != currentUser.uid, 
                orElse: () => currentUser.uid
              );

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox(height: 72); 
                  
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox();

                  final lastMessage = chatData['lastMessage'] ?? '';
                  final time = _formatTime(chatData['lastMessageTime']);
                  final photoUrl = userData['photoUrl'] as String?;

                  // 🔥 ОПТИМІЗАЦІЯ: Прибираємо вкладений StreamBuilder для кожної картки,
                  // щоб не створювати купу одночасних лістенерів на Web.
                  // Показуємо просто останнє повідомлення.

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: _getImageProvider(photoUrl),
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(userData['username'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(
                      userData['username'], 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      lastMessage, 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chatId: chatDoc.id, otherUser: userData),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}