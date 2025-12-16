import 'package:flutter/material.dart';

import 'package:basics/gradient_container.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: GradientContainer(
          Color.fromARGB(255, 255, 0, 0), //Зміна першого кольору градієнта зліва зверху 
          Color.fromARGB(255, 68, 21, 149), //Зміна другого кольору градієнта з правої сторони знизу
        ),
      ),
    ),
  );
}
