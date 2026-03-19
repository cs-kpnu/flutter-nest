import 'package:flutter/material.dart'; // Імпорт основного пакету Flutter.

import 'package:quiz/answer_button.dart'; // Імпорт кастомного віджета AnswerButton.
import 'package:quiz/data/questions.dart'; // Імпорт списку питань.

class QuestionsScreen extends StatefulWidget {
  // Створення віджета QuestionsScreen як StatefulWidget.
  const QuestionsScreen({
    // Конструктор віджета QuestionsScreen.
    super.key,
    required this.onSelectAnswer, // Обов'язковий параметр: функція, яка викликається при виборі відповіді.
  });

  final void Function(String answer)
      onSelectAnswer; // Оголошення функції onSelectAnswer, яка приймає вибрану відповідь як аргумент.

  @override
  State<QuestionsScreen> createState() {
    // Метод createState() створює та повертає об'єкт стану для віджета QuestionsScreen.
    return _QuestionsScreenState();
  }
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  // Клас _QuestionsScreenState керує станом віджета QuestionsScreen.
  var currentQuestionIndex =
      0; // Змінна для відстеження індексу поточного питання.

  void answerQuestion(String selectedAnswer) {
    // Метод для обробки вибору відповіді.
    widget.onSelectAnswer(
        selectedAnswer); // Виклик функції onSelectAnswer, переданої з батьківського віджета, з вибраною відповіддю.
    // currentQuestionIndex = currentQuestionIndex + 1;
    // currentQuestionIndex += 1;
    setState(() {
      // Виклик setState() для оновлення UI та переходу до наступного питання.
      currentQuestionIndex++; // Збільшення індексу поточного питання на 1.
    });
  }

  @override
  Widget build(context) {
    // Метод build описує, як відображати віджет QuestionsScreen.
    final currentQuestion = questions[
        currentQuestionIndex]; // Отримання поточного питання зі списку questions за індексом.

    return SizedBox(
      // Віджет SizedBox для встановлення фіксованої ширини.
      //width:
        //  double.infinity, // Встановлення ширини на всю доступну ширину екрану.
      child: Container(
        // Віджет-контейнер для застосування відступів.
        margin:
            const EdgeInsets.all(40), // Встановлення відступів з усіх боків.
        child: Column(
          // Віджет Column для вертикального розташування елементів.
          mainAxisAlignment: MainAxisAlignment
              .center, // Розташування дочірніх елементів по центру по вертикалі.
          crossAxisAlignment: CrossAxisAlignment
              .stretch, // Розтягування дочірніх елементів по всій ширині.
          children: [
            // Список дочірніх віджетів Column.
            Text(
              // Віджет для відображення тексту питання.
              currentQuestion.text, // Отримання тексту поточного питання.
              style: const TextStyle(
                // Стиль тексту з використанням шрифту Lato.
                color: Color.fromARGB(255, 255, 255, 255), // Колір тексту (блідо-фіолетовий).
                fontSize: 24, // Розмір шрифту.
                fontWeight: FontWeight.bold, // Встановлення жирного шрифту.
              ),
              textAlign: TextAlign.center, // Вирівнювання тексту по центру.
            ),
            const SizedBox(
                height:
                    30), // Віджет SizedBox для створення вертикального проміжку.
            ...currentQuestion.shuffledAnswers.map((answer) {
              // Використання оператора spread (...) для розгортання списку віджетів AnswerButton.
              return AnswerButton(
                
                // Створення віджета AnswerButton для кожного варіанту відповіді.
                answerText:
                    answer, // Передача тексту відповіді до віджета AnswerButton.
                onTap: () {
                  // Анонімна функція, яка викликається при натисканні на кнопку відповіді.
                  answerQuestion(
                      answer); // Виклик методу answerQuestion з вибраною відповіддю.
                },
              );
            })
          ],
        ),
      ),
    );
  }
}
