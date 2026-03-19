import 'package:flutter/material.dart'; // Імпорт основного пакету Flutter.

import 'package:quiz/start_screen.dart'; // Імпорт віджета початкового екрану.
import 'package:quiz/questions_screen.dart'; // Імпорт віджета екрану з питаннями.
import 'package:quiz/data/questions.dart'; // Імпорт списку питань та відповідей.
import 'package:quiz/results_screen.dart'; // Імпорт віджета екрану результатів.

class Quiz extends StatefulWidget {
  // Створення головного віджета Quiz як StatefulWidget, оскільки його стан буде змінюватися.
  const Quiz({super.key}); // Конструктор віджета Quiz.

  @override
  State<Quiz> createState() {
    // Метод createState() створює та повертає об'єкт стану для віджета Quiz.
    return _QuizState();
  }
}

class _QuizState extends State<Quiz> {
  // Клас _QuizState керує станом віджета Quiz.
  List<String> _selectedAnswers =
      []; // Список для зберігання вибраних користувачем відповідей.
  var _activeScreen =
      'start-screen'; // Змінна для відстеження поточного активного екрану ('start-screen', 'questions-screen', 'results-screen').

  void _switchScreen() {
    // Метод для перемикання на екран з питаннями.
    setState(() {
      // Виклик setState() повідомляє Flutter про необхідність перемалювати UI.
      _activeScreen =
          'questions-screen'; // Зміна значення _activeScreen на 'questions-screen'.
    });
  }

  void _chooseAnswer(String answer) {
    // Метод для обробки вибору відповіді користувачем.
    _selectedAnswers.add(
        answer); // Додавання вибраної відповіді до списку _selectedAnswers.

    if (_selectedAnswers.length == questions.length) {
      // Перевірка, чи були надані відповіді на всі питання.
      setState(() {
        // Оновлення UI для відображення екрану результатів.
        _activeScreen =
            'results-screen'; // Зміна значення _activeScreen на 'results-screen'.
      });
    }
  }

  void restartQuiz() {
    // Метод для перезапуску вікторини.
    setState(() {
      // Оновлення UI для повернення до екрану з питаннями та очищення вибраних відповідей.
      _selectedAnswers = []; // Очищення списку вибраних відповідей.
      _activeScreen =
          'questions-screen'; // Встановлення активним екрану з питаннями.
    });
  }

  @override
  Widget build(context) {
    // Метод build описує, як відображати віджет Quiz.
    Widget screenWidget = StartScreen(
        _switchScreen); // За замовчуванням відображається початковий екран, передаючи функцію для переходу на наступний екран.

    if (_activeScreen == 'questions-screen') {
      // Перевірка, чи активний екран з питаннями.
      screenWidget = QuestionsScreen(
        // Створення віджета екрану з питаннями, передаючи функцію для обробки вибору відповіді.
        onSelectAnswer: _chooseAnswer,
      );
    }

    if (_activeScreen == 'results-screen') {
      // Перевірка, чи активний екран результатів.
      screenWidget = ResultsScreen(
        // Створення віджета екрану результатів, передаючи список вибраних відповідей та функцію для перезапуску вікторини.
        chosenAnswers: _selectedAnswers,
        onRestart: restartQuiz,
      );
    }

    return MaterialApp(
      // Коріневий віджет для застосунків Material Design.
      home: Scaffold(
        // Забезпечує базову структуру екрану (AppBar, Body, FloatingActionButton тощо).
        body: Container(
          // Віджет-контейнер для застосування декорацій до тіла екрану.
          decoration: const BoxDecoration(
            // Визначає декорації контейнера.
            gradient: LinearGradient(
              // Створює лінійний градієнт для фону.
              colors: [
                // Список кольорів для градієнта.
                Color.fromARGB(255, 19, 34, 241), // Перший колір градієнта.
                Color.fromARGB(255, 155, 6, 168), // Перший колір градієнта.
                Color.fromARGB(255, 161, 0, 0), // Другий колір градієнта.
              ],
              begin: Alignment
                  .topLeft, // Початок градієнта у верхньому лівому куті.
              end: Alignment
                  .bottomRight, // Кінець градієнта у нижньому правому куті.
            ),
          ),
          child:
              screenWidget, // Відображення поточного активного віджета екрану.
        ),
      ),
    );
  }
}
