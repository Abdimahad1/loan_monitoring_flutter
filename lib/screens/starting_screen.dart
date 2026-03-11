import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../auth_screens/login_sign_up_screens.dart';
import '../utils/app_constants.dart';

class StartingScreen extends StatefulWidget {
  const StartingScreen({super.key});

  @override
  State<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateAfterDelay();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  void _navigateAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginSignUpScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreen.withOpacity(0.8),
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Logo Container
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // App Name with Typing Effect
                        _AnimatedAppName(),

                        const SizedBox(height: 16),

                        // Tagline
                        Text(
                          "Smart Loans, Brighter Future",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Loading Indicator
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.5),
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedAppName extends StatefulWidget {
  @override
  State<_AnimatedAppName> createState() => __AnimatedAppNameState();
}

class __AnimatedAppNameState extends State<_AnimatedAppName> {
  final String fullText = "LoanMonitor";
  String displayedText = "";
  int currentIndex = 0;
  bool showCursor = true;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _blinkCursor();
  }

  void _startTyping() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (currentIndex < fullText.length) {
        setState(() {
          displayedText += fullText[currentIndex];
          currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _blinkCursor() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        showCursor = !showCursor;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          displayedText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Container(
          width: 3,
          height: 40,
          color: showCursor ? Colors.white : Colors.transparent,
        ),
      ],
    );
  }
}