import 'package:flutter/material.dart'; // Імпорт основного пакету Flutter.

class QuestionIdentifier extends StatelessWidget {
  // Створення віджета QuestionIdentifier як StatelessWidget.
  const QuestionIdentifier({
    // Конструктор віджета QuestionIdentifier.
    super.key,
    required this.isCorrectAnswer, // Обов'язковий параметр: булеве значення, що вказує, чи була відповідь правильною.
    required this.questionIndex, // Обов'язковий параметр: індекс поточного питання.
  });

  final int
      questionIndex; // Оголошення фінальної змінної для зберігання індексу питання.
  final bool
      isCorrectAnswer; // Оголошення фінальної змінної для зберігання інформації про правильність відповіді.

  @override
  Widget build(BuildContext context) {
    // Метод build описує, як відображати віджет QuestionIdentifier.
    final questionNumber =
        questionIndex + 1; // Обчислення номера питання (індекс + 1).
    return Container(
      // Віджет Container для створення візуального контейнера для номера питання.
      width: 30, // Встановлення ширини контейнера.
      height: 30, // Встановлення висоти контейнера.
      alignment: Alignment.center, // Вирівнювання вмісту контейнера по центру.
      decoration: BoxDecoration(
        // Декорація контейнера (визначає колір та форму).
        color:
            isCorrectAnswer // Вибір кольору фону залежно від правильності відповіді.
                ? const Color.fromARGB(255, 150, 198,
                    241) // Колір для правильної відповіді (світло-синій).
                : const Color.fromARGB(255, 249, 133,
                    241), // Колір для неправильної відповіді (рожевий).
        borderRadius: BorderRadius.circular(
            100), // Заокруглення країв контейнера для створення круглої форми.
      ),
      child: Text(
        // Відображення номера питання.
        questionNumber.toString(), // Перетворення номера питання в рядок.
        style: const TextStyle(
          // Стиль тексту номера питання.
          fontWeight: FontWeight.bold, // Встановлення жирного шрифту.
          color: Color.fromARGB(
              255, 22, 2, 56), // Колір тексту (темно-фіолетовий).
        ),
      ),
    );
  }
}
