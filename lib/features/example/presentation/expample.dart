import 'package:flutter/material.dart';
import '../../../helpers/ui_helpers.dart';


class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Padding(
        padding: EdgeInsets.all(UIHelper.kDefaulutPadding()),
        child: const SingleChildScrollView(
          child: Column(
            children: [],
          ),
        ),
      )),
    );
  }
}
