import 'package:flutter/material.dart'; // Імпорт основного пакету Flutter для створення інтерфейсу користувача.

import 'package:quiz/quiz.dart'; // Імпорт кастомного віджета Quiz, який є коренем нашого застосунку.

void main() {
  runApp(
      const Quiz()); // Функція main() є точкою входу в застосунок. runApp() запускає наданий віджет (у цьому випадку, Quiz).
}
