class QuizQuestion {
  // Оголошення класу QuizQuestion.
  const QuizQuestion(this.text,
      this.answers); // Конструктор класу QuizQuestion, що приймає текст питання та список відповідей.

  final String text; // Фінальна змінна для зберігання тексту питання.
  final List<String>
      answers; // Фінальна змінна для зберігання списку варіантів відповідей.

  List<String> get shuffledAnswers {
    // Getter для отримання списку відповідей у випадковому порядку.
    final shuffledList =
        List.of(answers); // Створення нової копії списку відповідей.
    shuffledList.shuffle(); // Перемішування елементів у новій копії списку.
    return shuffledList; // Повернення перемішаного списку відповідей.
  }
}
