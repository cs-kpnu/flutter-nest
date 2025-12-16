import 'dart:async'; // 🔥 1. Імпорт для таймера (Debounce)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  
  // 🔥 2. Таймер для затримки пошуку
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // Обов'язково зупиняємо таймер при виході
    super.dispose();
  }

  // 🔥 3. Функція, яка викликається при кожній зміні тексту
  void _onSearchChanged(String query) {
    // Якщо таймер вже йде - скасовуємо його (користувач продовжує друкувати)
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Запускаємо новий таймер на 500 мілісекунд (пів секунди)
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _searchUsers();
    });
  }

  Future<void> _searchUsers() async {
    String query = _searchController.text.trim().replaceAll('@', '').toLowerCase();

    // Якщо поле пусте — очищаємо список і виходимо
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Пошук по полю searchKey (яке ми створювали при реєстрації маленькими буквами)
      // Логіка: шукаємо все, що починається на ці букви
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('searchKey', isGreaterThanOrEqualTo: query)
          .where('searchKey', isLessThan: '$query\uf8ff') 
          .limit(10) // Обмежуємо 10 результатами, щоб не вантажити зайве
          .get();

      setState(() {
        _searchResults = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Помилка пошуку: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(Map<String, dynamic> otherUser) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == otherUser['uid']) return;

    List<String> ids = [currentUser.uid, otherUser['uid']];
    ids.sort();
    String chatId = ids.join('_');

    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser),
        ),
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          autofocus: true, // 🔥 Одразу відкриває клавіатуру
          decoration: const InputDecoration(
            hintText: 'Пошук користувачів...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged, // 🔥 Головна зміна: слухаємо кожну букву
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty 
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty 
                      ? 'Введіть ім\'я для пошуку' 
                      : 'Користувачів не знайдено',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final photoUrl = user['photoUrl'] as String?;
                    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _getImageProvider(photoUrl),
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(user['username'][0].toUpperCase())
                            : null,
                      ),
                      title: Text('@${user['username']}', style: TextStyle(color: textColor)),
                      onTap: () => _startChat(user),
                    );
                  },
                ),
    );
  }
}