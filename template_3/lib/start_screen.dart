import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StartScreen extends StatelessWidget {
const StartScreen(this.startQuiz, {super.key});

final void Function() startQuiz;

@override
    Widget build(context) {
    return Center(
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    Image.asset(
    'assets/images/quiz_logo2.png',
    width: 300,
    //color: const Color.fromARGB(150, 255, 255, 255),
    ),
    const SizedBox(height: 20),
      Text(
      'Тест "Яка ти вiдеокарта вiд Gigabyte?\n Створений студентами кафедри комп\'ютерних наук',
      style: GoogleFonts.lato(
      color: const Color.fromARGB(255, 237, 223, 252),
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 30),
    OutlinedButton.icon(
    onPressed: startQuiz,
    style: OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: const BorderSide(color: Colors.white),
  ),
icon: const Icon(Icons.arrow_right_alt),
label: const Text('Розпочати тест'),
)
],
),
);
}
}