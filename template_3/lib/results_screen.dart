// ignore_for_file: prefer_const_constructors
// Encoding: UTF-8
import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
const ResultsScreen({
super.key,
required this.chosenAnswers,
required this.onRestart,
});

final void Function() onRestart;
final List<String> chosenAnswers;

String get result {
// Логiка визначення результату на основi вiдповiдей
int rtx4090 = 0, rtx3060 = 0, gtx1660 = 0, rx6700 = 0;
for (int i = 0; i < chosenAnswers.length; i++) {
  if (i == 0) {
    if (chosenAnswers[i].contains('4090')) {
      rtx4090 += 2;
    } else if (chosenAnswers[i].contains('3060')) rtx3060 += 2;
    else if (chosenAnswers[i].contains('1660')) gtx1660 += 2;
    else if (chosenAnswers[i].contains('6700')) rx6700 += 2;
  } else {
    if (chosenAnswers[i].contains('максимальна') || chosenAnswers[i].contains('ультра') || chosenAnswers[i].contains('першим')) {
      rtx4090++;
    } else if (chosenAnswers[i].contains('ефективнiсть') || chosenAnswers[i].contains('плавний') || chosenAnswers[i].contains('не вiдставати')) rtx3060++;
    else if (chosenAnswers[i].contains('класика') || chosenAnswers[i].contains('стандартний') || chosenAnswers[i].contains('не переживаю')) gtx1660++;
   else if (chosenAnswers[i].contains('нове') || chosenAnswers[i].contains('плавний') || chosenAnswers[i].contains('гонка')) rx6700++;
  }
}

final maxScore = [rtx4090, rtx3060, gtx1660, rx6700].reduce((a, b) => a > b ? a : b);

  if (maxScore == rtx4090) return 'RTX 4090 Gaming OC';
  if (maxScore == rtx3060) return 'RTX 3060 Eagle';
  if (maxScore == gtx1660) return 'GTX 1660 Super';
  if(maxScore == rx6700)  return 'RX 6700 XT Gaming OC';
  return result;
}
String get gpuImage {
  switch (result) {
    case 'RTX 4090 Gaming OC':
      return 'assets/images/rtx4090.png';
    case 'RTX 3060 Eagle':
      return 'assets/images/rtx3060.png';
    case 'GTX 1660 Super':
      return 'assets/images/gtx1660.png';
    default:
      return 'assets/images/rx6700.png';
  }
}
String get description {
  switch (result) {
    case 'RTX 4090 Gaming OC':
    return 'Ти — справжнiй флагман! Як RTX 4090, ти завжди прагнеш до максимуму, любиш бути першим i не боїшся викликiв.';
    case 'RTX 3060 Eagle':
    return 'Ти — iдеальний баланс! Як RTX 3060, ти поєднуєш продуктивнiсть iз надiйнiстю, знаєш цiну якостi.';
    case 'GTX 1660 Super':
    return 'Ти — класика, яка нiколи не виходить з моди! Як GTX 1660 Super, ти стабiльний, практичний i завжди на висотi.';
    default:
    return 'Ти — iнноватор! Як RX 6700 XT, ти любиш нестандартнi пiдходи i завжди вiдкритий для нового.';
}
}

@override
Widget build(BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: Container(
      margin: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Твоя вiдеокарта:',
            style: TextStyle(
              color: const Color.fromARGB(255, 230, 200, 253),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 42, 27, 61),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    gpuImage,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  result,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            description,
            style: TextStyle(
              color: const Color.fromARGB(255, 230, 200, 253),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: onRestart,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Спробувати ще раз'),
          ),
        ],
      ),
    ),
  );
}
}