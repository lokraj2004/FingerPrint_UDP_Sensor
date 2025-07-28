import 'package:flutter/material.dart';

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  final bool useDarkOverlay;

  const BackgroundWrapper({
    Key? key,
    required this.child,
    this.useDarkOverlay = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/Background.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Optional dark overlay
        if (useDarkOverlay)
          Container(
            color: Colors.black.withOpacity(0.2),
          ),

        // Foreground content
        SafeArea(
          child: child,
        ),
      ],
    );
  }
}
