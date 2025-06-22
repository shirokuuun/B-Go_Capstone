import 'package:flutter/material.dart';

class Responsive {
  final double width;
  final double height;

  Responsive(BuildContext context)
      : width = MediaQuery.of(context).size.width,
        height = MediaQuery.of(context).size.height;
}