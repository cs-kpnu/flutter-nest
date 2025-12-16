import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final username = _usernameController.text.trim().replaceAll('@', '');
        if (username.isEmpty) throw 'Введіть ім\'я користувача';

        final usernameCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          throw 'Цей @username вже зайнятий';
        }

        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'email': _emailController.text.trim(),
          'username': username,
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
          'searchKey': username.toLowerCase(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blackTextStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

   
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 50, 62, 71),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.messenger, size: 80, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Вхід' : 'Реєстрація',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  if (!_isLogin)
                    TextField(
                      controller: _usernameController,
                      style: blackTextStyle,
                      cursorColor: Colors.black,
                      decoration: const InputDecoration(
                        labelText: 'Username (без @)',
                        labelStyle: labelStyle,
                        prefixText: '@',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (!_isLogin) const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    style: blackTextStyle,
                    cursorColor: Colors.black,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: labelStyle,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    style: blackTextStyle,
                    cursorColor: Colors.black,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      labelStyle: labelStyle,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _submit,
                            child: Text(_isLogin ? 'Увійти' : 'Створити акаунт', style: const TextStyle(color: Colors.white)),
                            
                          ),
                        ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Немає акаунту? Реєстрація' : 'Вже є акаунт? Вхід', style: const TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}