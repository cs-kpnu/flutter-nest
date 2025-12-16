import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// 1. Змінюємо StatelessWidget на StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// 2. Створюємо клас стану (тут живуть змінні та логіка)
class _MyAppState extends State<MyApp> {
  // Змінна винесена за межі методу build, щоб вона зберігала значення
  int pressedButton = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter First App',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to Flutter'),
        ),
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Flutter - The Complete Guide Course',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Learn Flutter step-by-step, from the ground up.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // КНОПКА
              ElevatedButton(
                onPressed: () {
                  // 3. Магічна функція setState оновлює екран
                  setState(() {
                    pressedButton += 1;
                  });
                  print('Кнопку натиснули: $pressedButton разів');
                },
                child: const Text('Почати навчання'),
              ),
              
              const SizedBox(height: 20),
              
              // ТЕКСТ З ЛІЧИЛЬНИКОМ
              Text(
                'Кнопку натиснули: $pressedButton разів',
                style: const TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}