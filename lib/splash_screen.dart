import 'package:email_summarizer/emailsummarizerscreen.dart';
import 'package:flutter/material.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin { // Changed to TickerProviderStateMixin for multiple controllers
  // 1. Setup the Rotation Animation (for the icon)
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  // 2. Setup the Dot Sequence Animation (replaces Pulse)
  late AnimationController _dotController; // Renamed from _pulseController

  @override
  void initState() {
    super.initState();

    // --- Rotation Setup ---
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2), // Duration for one full spin (changed from 3s to 2s for better flow)
      vsync: this,
    )..repeat(); 
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    );

    // --- Dot Sequence Setup (New Logic) ---
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1 second loop for the sequence (changed from 2s to 1s for snappier animation)
      vsync: this,
    )..repeat(); // Repeats indefinitely

    // --- Navigation ---
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        // Stop animations when navigating away
        _rotationController.dispose();
        _dotController.dispose(); // Dispose the dot controller
        
        // Navigate to the main screen using a custom fade transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500), // How long the fade takes
            pageBuilder: (context, animation, secondaryAnimation) => const EmailSummarizerScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
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
    _rotationController.dispose();
    _dotController.dispose(); // Dispose the dot controller
    super.dispose();
  }

  // Helper function to create an individual animated dot with staggered timing
  Widget _buildDot(double begin, double end) {
    // Creates a Tween that scales up (1.0->1.5) and immediately back down (1.5->1.0)
    final Animation<double> scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 1), // Scale up
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 1), // Scale down
    ]).animate(
      CurvedAnimation(
        parent: _dotController,
        // The Interval offsets the start time for the dot within the 1-second loop
        curve: Interval(begin, end, curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the primary color defined in MyApp's theme
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with RotationTransition
            RotationTransition(
              turns: _rotationAnimation,
              child: const Icon(
                Icons.mark_email_read_outlined, // Icon representing summarized mail
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Email Summarizer',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Powered by Gemini',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 50),
            
            // Sequential Dot Animation (Replaces Pulsing Text)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dot 1: Starts immediately (0.0), finishes pulse around 45% of the cycle
                _buildDot(0.0, 0.45),
                // Dot 2: Starts slightly delayed (0.25), finishes pulse around 65% of the cycle
                _buildDot(0.25, 0.65), 
                // Dot 3: Starts later (0.5), finishes pulse around 90% of the cycle
                _buildDot(0.5, 0.9), 
              ],
            ),
          ],
        ),
      ),
    );
  }
}
