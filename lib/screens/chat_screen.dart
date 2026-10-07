import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/message.dart';
import '../services/ai_service.dart';
import '../services/vision_service.dart';
import '../services/stage5b_controller.dart';

class _InstallAppButton extends StatelessWidget {
  const _InstallAppButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Install DOUGLAS AI',
      icon: const Icon(Icons.install_mobile_rounded, size: 21),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DOUGLAS AI is ready to install on this device.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}


class _DouglasMouth extends StatelessWidget {
  final Animation<double> animation;
  final bool speaking;

  const _DouglasMouth({
    required this.animation,
    required this.speaking,
  });

  @override
  Widget build(BuildContext context) {
    if (!speaking) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Stage 5M: continuous speech-synchronized mouth motion.
        final phase = (sin(animation.value * 2 * pi) + 1.0) / 2.0;
        final speechBoost = speaking ? 1.0 : 0.0;
        final open = 4.0 + (phase * 13.0 * speechBoost);

        return IgnorePointer(
          child: CustomPaint(
            painter: _MouthPainter(openAmount: open),
            size: const Size(76, 32),
          ),
        );
      },
    );
  }
}

class _MouthPainter extends CustomPainter {
  final double openAmount;

  const _MouthPainter({
    required this.openAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final outerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;

    final innerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.98)
      ..style = PaintingStyle.fill;

    final lipPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final outerRect = Rect.fromCenter(
      center: center,
      width: 58,
      height: openAmount,
    );

    canvas.drawOval(outerRect, outerPaint);

    if (openAmount > 7) {
      final innerRect = Rect.fromCenter(
        center: center.translate(0, 1),
        width: 42,
        height: openAmount * 0.55,
      );

      canvas.drawOval(innerRect, innerPaint);
    }

    final lipPath = Path()
      ..moveTo(center.dx - 27, center.dy)
      ..quadraticBezierTo(
        center.dx,
        center.dy - openAmount * 0.20,
        center.dx + 27,
        center.dy,
      );

    canvas.drawPath(lipPath, lipPaint);
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) {
    return oldDelegate.openAmount != openAmount;
  }
}



// Stage 5H: subtle emotional tear animation.

// Stage 5I: natural human gesture layer.
class _DouglasGestureLayer extends StatelessWidget {
  final Animation<double> animation;
  final String avatarState;
  final String emotion;

  const _DouglasGestureLayer({
    required this.animation,
    required this.avatarState,
    required this.emotion,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value * 2 * pi;

          double vertical = sin(t * 0.70) * 1.2;
          double horizontal = sin(t * 0.42) * 0.8;
          double rotation = sin(t * 0.35) * 0.0025;
          double scale = 1.0 + sin(t * 0.55) * 0.0015;

          switch (avatarState) {
            case 'LISTENING':
              vertical += sin(t * 1.15) * 1.4;
              horizontal += sin(t * 0.55) * 0.7;
              rotation += sin(t * 0.82) * 0.0045;
              break;

            case 'THINKING':
              vertical += sin(t * 0.48) * 0.8;
              horizontal += sin(t * 0.30) * 1.0;
              rotation -= 0.003;
              break;

            case 'SPEAKING':
              vertical += sin(t * 1.05) * 1.8;
              horizontal += sin(t * 0.62) * 0.9;
              rotation += sin(t * 0.72) * 0.0035;
              scale += sin(t * 1.1) * 0.0018;
              break;

            default:
              break;
          }

          if (emotion == 'HAPPY') {
            vertical -= 0.7;
            rotation += sin(t * 0.9) * 0.002;
          } else if (emotion == 'SAD') {
            vertical += 0.5;
            rotation -= 0.002;
            scale -= 0.001;
          } else if (emotion == 'SURPRISED') {
            vertical -= 1.5;
            scale += 0.003;
          }

          return Transform.translate(
            offset: Offset(horizontal, vertical),
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}


// Stage 5N: human facial-expression layer.
// Uses the existing HAPPY/SAD/SURPRISED emotion states.
// It does not replace the existing eyes, tears, gestures, or mouth.
class _DouglasFacialExpression extends StatelessWidget {
  final Animation<double> animation;
  final String emotion;

  const _DouglasFacialExpression({
    required this.animation,
    required this.emotion,
  });

  @override
  Widget build(BuildContext context) {
    final currentEmotion = emotion.toUpperCase();

    if (currentEmotion == 'NEUTRAL') {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final wave =
              (sin(animation.value * 2 * pi) + 1.0) / 2.0;

          double lift = 0.0;
          double scale = 1.0;
          double rotation = 0.0;

          switch (currentEmotion) {
            case 'HAPPY':
              // Slightly lifted, lively facial posture.
              lift = -1.2 - (wave * 0.8);
              scale = 1.0 + (wave * 0.008);
              rotation = sin(animation.value * 2 * pi) * 0.002;
              break;

            case 'SAD':
              // Subtle lowered/concerned facial posture.
              lift = 1.4 + (wave * 0.6);
              scale = 1.0 - (wave * 0.004);
              rotation = -0.002;
              break;

            case 'SURPRISED':
              // Alert upward expansion.
              lift = -2.0 - (wave * 1.0);
              scale = 1.0 + (wave * 0.014);
              break;

            default:
              return const SizedBox.shrink();
          }

          return Transform.translate(
            offset: Offset(0, lift),
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: CustomPaint(
                  painter: _DouglasFacialExpressionPainter(
                    emotion: currentEmotion,
                    intensity: 0.72 + (wave * 0.28),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DouglasFacialExpressionPainter extends CustomPainter {
  final String emotion;
  final double intensity;

  const _DouglasFacialExpressionPainter({
    required this.emotion,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.0045;

    // The existing Douglas avatar is approximately 1214x1295.
    // These proportional coordinates keep the expression layer
    // responsive when the avatar is resized.
    final cx = size.width * 0.475;
    final eyeY = size.height * 0.158;
    final eyeSpacing = size.width * 0.075;
    final browY = size.height * 0.135;
    final cheekY = size.height * 0.190;

    paint.color = Colors.white.withValues(
      alpha: 0.16 + (0.18 * intensity),
    );

    switch (emotion) {
      case 'HAPPY':
        // Gentle cheek/smile cues.
        paint.strokeWidth = size.width * 0.004;

        final leftCheek = Path()
          ..moveTo(
            cx - eyeSpacing * 1.55,
            cheekY,
          )
          ..quadraticBezierTo(
            cx - eyeSpacing * 1.10,
            cheekY + size.height * 0.009,
            cx - eyeSpacing * 0.72,
            cheekY - size.height * 0.002,
          );

        final rightCheek = Path()
          ..moveTo(
            cx + eyeSpacing * 0.72,
            cheekY - size.height * 0.002,
          )
          ..quadraticBezierTo(
            cx + eyeSpacing * 1.10,
            cheekY + size.height * 0.009,
            cx + eyeSpacing * 1.55,
            cheekY,
          );

        canvas.drawPath(leftCheek, paint);
        canvas.drawPath(rightCheek, paint);

        // Small upward brow motion.
        final leftBrow = Path()
          ..moveTo(
            cx - eyeSpacing * 1.35,
            browY,
          )
          ..quadraticBezierTo(
            cx - eyeSpacing,
            browY - size.height * 0.006,
            cx - eyeSpacing * 0.65,
            browY,
          );

        final rightBrow = Path()
          ..moveTo(
            cx + eyeSpacing * 0.65,
            browY,
          )
          ..quadraticBezierTo(
            cx + eyeSpacing,
            browY - size.height * 0.006,
            cx + eyeSpacing * 1.35,
            browY,
          );

        canvas.drawPath(leftBrow, paint);
        canvas.drawPath(rightBrow, paint);
        break;

      case 'SAD':
        // Inner-raised brows create a subtle concerned expression.
        final leftBrow = Path()
          ..moveTo(
            cx - eyeSpacing * 1.40,
            browY + size.height * 0.003,
          )
          ..quadraticBezierTo(
            cx - eyeSpacing,
            browY - size.height * 0.014,
            cx - eyeSpacing * 0.62,
            browY + size.height * 0.002,
          );

        final rightBrow = Path()
          ..moveTo(
            cx + eyeSpacing * 0.62,
            browY + size.height * 0.002,
          )
          ..quadraticBezierTo(
            cx + eyeSpacing,
            browY - size.height * 0.014,
            cx + eyeSpacing * 1.40,
            browY + size.height * 0.003,
          );

        canvas.drawPath(leftBrow, paint);
        canvas.drawPath(rightBrow, paint);

        // Very subtle cheek tension.
        final leftConcern = Path()
          ..moveTo(
            cx - eyeSpacing * 1.40,
            cheekY,
          )
          ..quadraticBezierTo(
            cx - eyeSpacing * 1.05,
            cheekY - size.height * 0.004,
            cx - eyeSpacing * 0.78,
            cheekY,
          );

        final rightConcern = Path()
          ..moveTo(
            cx + eyeSpacing * 0.78,
            cheekY,
          )
          ..quadraticBezierTo(
            cx + eyeSpacing * 1.05,
            cheekY - size.height * 0.004,
            cx + eyeSpacing * 1.40,
            cheekY,
          );

        canvas.drawPath(leftConcern, paint);
        canvas.drawPath(rightConcern, paint);
        break;

      case 'SURPRISED':
        // Raised brow arcs enhance the existing eye/attention system.
        paint.color = Colors.white.withValues(
          alpha: 0.20 + (0.20 * intensity),
        );
        paint.strokeWidth = size.width * 0.005;

        final leftBrow = Path()
          ..moveTo(
            cx - eyeSpacing * 1.45,
            browY,
          )
          ..quadraticBezierTo(
            cx - eyeSpacing,
            browY - size.height * 0.022,
            cx - eyeSpacing * 0.55,
            browY,
          );

        final rightBrow = Path()
          ..moveTo(
            cx + eyeSpacing * 0.55,
            browY,
          )
          ..quadraticBezierTo(
            cx + eyeSpacing,
            browY - size.height * 0.022,
            cx + eyeSpacing * 1.45,
            browY,
          );

        canvas.drawPath(leftBrow, paint);
        canvas.drawPath(rightBrow, paint);

        // Small alert arcs above the eyes.
        paint.strokeWidth = size.width * 0.0035;

        final leftAlert = Rect.fromCenter(
          center: Offset(
            cx - eyeSpacing,
            eyeY - size.height * 0.018,
          ),
          width: eyeSpacing * 0.85,
          height: size.height * 0.030,
        );

        final rightAlert = Rect.fromCenter(
          center: Offset(
            cx + eyeSpacing,
            eyeY - size.height * 0.018,
          ),
          width: eyeSpacing * 0.85,
          height: size.height * 0.030,
        );

        canvas.drawArc(leftAlert, pi, pi, false, paint);
        canvas.drawArc(rightAlert, pi, pi, false, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DouglasFacialExpressionPainter oldDelegate,
  ) {
    return oldDelegate.emotion != emotion ||
        oldDelegate.intensity != intensity;
  }
}


// Stage 5O: action visualization layer.
// Provides subtle state-specific motion now and acts as the
// animation-control bridge for a future rigged/3D Douglas avatar.
class _DouglasActionLayer extends StatelessWidget {
  final Animation<double> animation;
  final String action;

  const _DouglasActionLayer({
    required this.animation,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    if (action == 'IDLE') {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value * 2 * pi;

          double x = 0.0;
          double y = 0.0;
          double rotation = 0.0;
          double scale = 1.0;

          switch (action) {
            case 'SIT':
              y = 2.0;
              scale = 0.996;
              break;

            case 'STAND':
              y = -1.0;
              scale = 1.004;
              break;

            case 'WAVE':
              x = sin(t * 2.0) * 2.0;
              rotation = sin(t * 2.0) * 0.008;
              break;

            case 'DANCE':
              x = sin(t * 1.8) * 3.0;
              y = sin(t * 2.4) * 2.5;
              rotation = sin(t * 1.6) * 0.012;
              scale = 1.0 + sin(t * 2.4) * 0.004;
              break;

            case 'SALUTE':
              rotation = sin(t * 1.4) * 0.004;
              y = -1.5;
              break;

            case 'SLEEP':
              y = 2.0 + sin(t * 0.35) * 0.7;
              scale = 0.997;
              break;

            case 'CROUCH':
              y = 3.0;
              scale = 0.992;
              break;

            case 'RUN':
              x = sin(t * 3.0) * 3.5;
              y = sin(t * 5.0) * 2.0;
              rotation = sin(t * 3.0) * 0.014;
              break;

            case 'WALK':
              x = sin(t * 1.5) * 1.8;
              y = sin(t * 3.0) * 1.0;
              break;

            case 'POINT':
              x = sin(t * 0.8) * 0.8;
              rotation = sin(t * 0.8) * 0.004;
              break;

            case 'CLAP':
              x = sin(t * 3.2) * 1.5;
              scale = 1.0 + sin(t * 3.2).abs() * 0.003;
              break;

            case 'NOD':
              y = sin(t * 2.5) * 1.8;
              break;

            case 'SHAKE_HEAD':
              x = sin(t * 2.2) * 1.8;
              break;
          }

          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DouglasTears extends StatelessWidget {
  final Animation<double> animation;
  final String emotion;

  const _DouglasTears({
    required this.animation,
    required this.emotion,
  });

  @override
  Widget build(BuildContext context) {
    if (emotion != 'SAD') {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final wave =
              (sin(animation.value * 2 * pi) + 1.0) / 2.0;

          return CustomPaint(
            painter: _DouglasTearsPainter(
              intensity: 0.35 + (wave * 0.30),
            ),
          );
        },
      ),
    );
  }
}

class _DouglasTearsPainter extends CustomPainter {
  final double intensity;

  const _DouglasTearsPainter({
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates are proportional to the Douglas avatar.
    final leftTear = Offset(
      size.width * 0.425,
      size.height * 0.205,
    );

    final rightTear = Offset(
      size.width * 0.575,
      size.height * 0.205,
    );

    final paint = Paint()
      ..color = Colors.lightBlueAccent.withValues(
        alpha: 0.34 * intensity,
      )
      ..style = PaintingStyle.fill;

    void drawTear(Offset origin, double phase) {
      final dropLength = size.height * (0.018 + phase * 0.006);
      final dropWidth = size.width * 0.012;

      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(
          origin.dx - dropWidth,
          origin.dy + dropLength * 0.42,
          origin.dx,
          origin.dy + dropLength,
        )
        ..quadraticBezierTo(
          origin.dx + dropWidth,
          origin.dy + dropLength * 0.42,
          origin.dx,
          origin.dy,
        )
        ..close();

      canvas.drawPath(path, paint);
    }

    drawTear(leftTear, intensity);
    drawTear(rightTear, 1.0 - intensity * 0.35);
  }

  @override
  bool shouldRepaint(covariant _DouglasTearsPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

class _DouglasEyes extends StatelessWidget {
  final Animation<double> animation;
  final String avatarState;

  const _DouglasEyes({
    required this.animation,
    required this.avatarState,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value * 2 * pi;

          // One brief natural blink during each idle cycle.
          final blinkWave = sin((t * 0.5) - 1.0);
          final blink = blinkWave > 0
              ? pow(blinkWave, 18).toDouble()
              : 0.0;

          // Very small attention movement depending on Douglas's state.
          final gazeX = avatarState == 'LISTENING'
              ? sin(t * 0.35) * 1.4
              : avatarState == 'THINKING'
                  ? sin(t * 0.22) * 0.9
                  : avatarState == 'SPEAKING'
                      ? sin(t * 0.28) * 0.6
                      : sin(t * 0.18) * 0.35;

          return CustomPaint(
            painter: _DouglasEyesPainter(
              blink: blink,
              gazeX: gazeX,
            ),
          );
        },
      ),
    );
  }
}

class _DouglasEyesPainter extends CustomPainter {
  final double blink;
  final double gazeX;

  const _DouglasEyesPainter({
    required this.blink,
    required this.gazeX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // These coordinates are proportional to the supplied Douglas avatar.
    final leftEye = Offset(size.width * 0.29 + gazeX, size.height * 0.48);
    final rightEye = Offset(size.width * 0.71 + gazeX, size.height * 0.48);

    final eyeWidth = size.width * 0.25;
    final eyeHeight = size.height * 0.20;

    // Very subtle dark eyelid/eye-line layer.
    final eyelidPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final blinkHeight = eyeHeight * (1.0 - blink * 0.92);

    final leftRect = Rect.fromCenter(
      center: leftEye,
      width: eyeWidth,
      height: blinkHeight,
    );

    final rightRect = Rect.fromCenter(
      center: rightEye,
      width: eyeWidth,
      height: blinkHeight,
    );

    if (blink > 0.18) {
      final blinkPaint = Paint()
        ..color = const Color(0xFF75452F).withValues(alpha: 0.82)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          leftRect,
          Radius.circular(eyeHeight),
        ),
        blinkPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rightRect,
          Radius.circular(eyeHeight),
        ),
        blinkPaint,
      );
    } else {
      // Keep the effect extremely light so the original photograph
      // remains visible.
      canvas.drawOval(
        Rect.fromCenter(
          center: leftEye,
          width: eyeWidth * 0.16,
          height: eyeHeight * 0.16,
        ),
        eyelidPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: rightEye,
          width: eyeWidth * 0.16,
          height: eyeHeight * 0.16,
        ),
        eyelidPaint,
      );

      canvas.drawCircle(
        leftEye.translate(gazeX * 0.35, -eyeHeight * 0.04),
        eyeHeight * 0.035,
        highlightPaint,
      );

      canvas.drawCircle(
        rightEye.translate(gazeX * 0.35, -eyeHeight * 0.04),
        eyeHeight * 0.035,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DouglasEyesPainter oldDelegate) {
    return oldDelegate.blink != blink ||
        oldDelegate.gazeX != gazeX;
  }
}


// Stage 5J: immersive one-person video-call interface frame.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {

  // Stage 5P: real camera vision foundation.
  final DouglasVisionService _visionService = DouglasVisionService();
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _visionBusy = false;
  String _visionStatus = 'VISION OFF';

  bool get _hasCameraVision =>
      _cameraController != null &&
      _cameraController!.value.isInitialized &&
      _cameraReady;

  Future<void> _initializeDouglasVision() async {
    if (!mounted) return;

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraReady = false;
          _visionStatus = 'NO CAMERA';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      await _visionService.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _visionStatus = 'VISION READY';
      });
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        _cameraReady = false;
        _visionStatus = 'CAMERA ERROR: ${error.code}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cameraReady = false;
        _visionStatus = 'VISION ERROR';
      });
    }
  }

  Future<void> _captureDouglasVisionFrame() async {
    final controller = _cameraController;

    if (!_hasCameraVision || controller == null || _visionBusy) {
      return;
    }

    setState(() {
      _visionBusy = true;
      _visionStatus = 'CAPTURING...';
    });

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();

      final interpretation = await _visionService.analyzeImage(
        imageBytes: bytes,
      );

      if (!mounted) return;

      setState(() {
        _visionStatus = 'VISION UNDERSTOOD';
      });

      // Stage 5Q: send the visual interpretation through
      // Douglas's existing spoken-response pipeline.
      _speakResponse(interpretation);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _visionStatus = 'VISION CAPTURE ERROR';
      });
    } finally {
      if (mounted) {
        setState(() {
          _visionBusy = false;
        });
      }
    }
  }

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AiService _aiService = LocalAiService();
  final Stage5BController _stage5b = Stage5BController();
  StreamSubscription<String>? _stage5bSpeechSubscription;
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;
  bool _isListening = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello. I am DOUGLAS AI. How can I help you?',
      role: MessageRole.assistant,
    ),
  ];

  bool _sending = false;

  // Stage 5K: continuous voice conversation is enabled.
  final bool _continuousConversation = true;
  String _avatarMode = 'IDLE';

  // Stage 5G: Douglas emotional state.
  String _emotion = 'NEUTRAL';

  String get _emotionState => _emotion;
  double _speechIntensity = 0.0;
  late AnimationController _mouthController;
  Timer? _speechIntensityTimer;

  String get _avatarState => _avatarMode;
  late final AnimationController _idleController;
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();

    _initializeDouglasVision();
    _initializeSpeech();
    _initializeTts();

    _greetingTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _speakResponse(
        'Hello Douglas. I am DOUGLAS AI. I am ready to assist you.',
      );
    });

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..repeat(reverse: true);
  }

  void _setAvatarState(String state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarMode = state;
    });
  }

  void setListeningState() => _setAvatarState('LISTENING');

  void setSpeakingState() => _setAvatarState('SPEAKING');
  void _setEmotion(String emotion) {
    if (!mounted) {
      return;
    }

    setState(() {
      _emotion = emotion;
    });
  }

  
// Stage 5O: Douglas action controller.
// This is the command foundation for future animated/rigged avatar actions.
// The current PNG avatar remains fully compatible with this layer.
String _douglasAction = 'IDLE';

String get _douglasActionState => _douglasAction;

void _setDouglasAction(String action) {
  if (!mounted) return;

  setState(() {
    _douglasAction = action;
  });
}

// Stage 5O: interpret natural-language physical commands.
String? _interpretDouglasAction(String text) {
  final value = text.trim().toLowerCase();

  if (value.isEmpty) {
    return null;
  }

  if (RegExp(r'\b(sit|sit down|take a seat)\b').hasMatch(value)) {
    return 'SIT';
  }

  if (RegExp(r'\b(stand|stand up|get up)\b').hasMatch(value)) {
    return 'STAND';
  }

  if (RegExp(r'\b(wave|wave at me|wave to me)\b').hasMatch(value)) {
    return 'WAVE';
  }

  if (RegExp(r'\b(dance|start dancing|do a dance)\b').hasMatch(value)) {
    return 'DANCE';
  }

  if (RegExp(r'\b(salute|salute me)\b').hasMatch(value)) {
    return 'SALUTE';
  }

  if (RegExp(r'\b(sleep|go to sleep|sleep now)\b').hasMatch(value)) {
    return 'SLEEP';
  }

  if (RegExp(r'\b(crouch|squat|squat down|crouch down)\b').hasMatch(value)) {
    return 'CROUCH';
  }

  if (RegExp(r'\b(run|run around|start running)\b').hasMatch(value)) {
    return 'RUN';
  }

  if (RegExp(r'\b(walk|walk around|start walking)\b').hasMatch(value)) {
    return 'WALK';
  }

  if (RegExp(r'\b(point|point at it|point there)\b').hasMatch(value)) {
    return 'POINT';
  }

  if (RegExp(r'\b(clap|clap your hands)\b').hasMatch(value)) {
    return 'CLAP';
  }

  if (RegExp(r'\b(nod|nod your head)\b').hasMatch(value)) {
    return 'NOD';
  }

  if (RegExp(r'\b(shake your head|shake head)\b').hasMatch(value)) {
    return 'SHAKE_HEAD';
  }

  if (RegExp(r'\b(stop|stop moving|be still|rest)\b').hasMatch(value)) {
    return 'IDLE';
  }

  return null;
}

void _handleDouglasActionCommand(String text) {
  final action = _interpretDouglasAction(text);

  if (action != null) {
    _setDouglasAction(action);
  }
}

void _detectEmotion(String text) {
    final value = text.trim().toLowerCase();

    if (value.isEmpty) {
      _setEmotion('NEUTRAL');
      return;
    }

    const happyWords = [
      'thank you',
      'thanks',
      'great',
      'good job',
      'excellent',
      'wonderful',
      'congratulations',
      'happy',
      'glad',
      'excited',
      'love',
    ];

    const sadWords = [
      'sad',
      'sorry',
      'cry',
      'crying',
      'death',
      'died',
      'loss',
      'lost',
      'heartbroken',
      'lonely',
      'pain',
      'hurt',
      'terrible',
      'bad news',
    ];

    const surpriseWords = [
      'wow',
      'really',
      'seriously',
      'surprise',
      'surprised',
      'unexpected',
      'unbelievable',
      'shocking',
    ];

    if (happyWords.any(value.contains)) {
      _setEmotion('HAPPY');
    } else if (sadWords.any(value.contains)) {
      _setEmotion('SAD');
    } else if (surpriseWords.any(value.contains)) {
      _setEmotion('SURPRISED');
    } else {
      _setEmotion('NEUTRAL');
    }
  }



  Future<void> _initializeTts() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return;
    }

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(0.90);

    // Stage 5D: prefer a natural male English voice when the
    // Android TTS engine exposes one. Fall back safely otherwise.
    try {
      final voices = await _tts.getVoices;

      if (voices is List) {
        Map<String, dynamic>? maleVoice;

        for (final item in voices) {
          if (item is Map) {
            final voice = Map<String, dynamic>.from(item);
            final name = '${voice['name'] ?? ''}'.toLowerCase();
            final locale = '${voice['locale'] ?? ''}'.toLowerCase();
            final gender = '${voice['gender'] ?? ''}'.toLowerCase();

            final english = locale.startsWith('en');
            final male = gender == 'male' ||
                name.contains('male') ||
                name.contains('man') ||
                name.contains('david') ||
                name.contains('mark') ||
                name.contains('daniel') ||
                name.contains('alex');

            if (english && male) {
              maleVoice = voice;
              break;
            }
          }
        }

        if (maleVoice != null) {
          await _tts.setVoice(
            maleVoice.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
        }
      }
    } catch (_) {
      // Keep the Android default voice if voice discovery is unavailable.
    }

    _tts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _avatarMode = 'SPEAKING';
        });
      }
    });

    _tts.setCompletionHandler(() {
      _speechIntensityTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarMode = 'IDLE';
        _speechIntensity = 0.0;
      });

      if (_continuousConversation && _speechAvailable) {
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          () {
            if (!mounted ||
                !_continuousConversation ||
                _sending ||
                _isListening ||
                _stage5b.isListening) {
              return;
            }

            _beginAutomaticListening();
          },
        );
      }
    });

    _tts.setCancelHandler(() {
      _speechIntensityTimer?.cancel();

      if (mounted) {
        setState(() {
          if (!_sending && !_isListening) {
            _avatarMode = 'IDLE';
            _speechIntensity = 0.0;
          }
        });
      }
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      if (!mounted || _avatarState != 'SPEAKING') {
        return;
      }

      // Stage 5M: speech-synchronized facial/body pulse.
      _speechIntensityTimer?.cancel();

      setState(() {
        _speechIntensity = 1.0;
      });

      _idleController.forward(from: 0.0);

      _speechIntensityTimer = Timer(
        const Duration(milliseconds: 120),
        () {
          if (!mounted || _avatarState != 'SPEAKING') {
            return;
          }

          setState(() {
            _speechIntensity = 0.25;
          });
        },
      );
    });
  }

  Future<void> _beginAutomaticListening() async {
    if (!mounted ||
        !_continuousConversation ||
        !_speechAvailable ||
        _sending ||
        _stage5b.isListening) {
      return;
    }

    setState(() {
      _isListening = true;
      _avatarMode = 'LISTENING';
      _speechIntensity = 0.0;
    });

    final started = await _stage5b.listen(localeId: 'en_US');

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _avatarMode = 'IDLE';
      });
    }
  }

  Future<void> _speakResponse(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _tts.stop();

    if (mounted) {
      setState(() {
        _avatarMode = 'SPEAKING';
        _speechIntensity = 0.0;
      });
    }

    await _tts.speak(text);
  }

  Future<void> _initializeSpeech() async {
    final available = await _stage5b.initialize();

    await _stage5bSpeechSubscription?.cancel();

    _stage5bSpeechSubscription = _stage5b.userSpeechStream.listen((
      recognizedText,
    ) {
      if (!mounted || recognizedText.trim().isEmpty) {
        return;
      }

      setState(() {
        _controller.text = recognizedText.trim();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        _isListening = false;

        if (!_sending) {
          _avatarMode = 'THINKING';
        }
      });

      if (!_sending) {
        _sendMessage();
      }
    });

    if (mounted) {
      setState(() {
        _speechAvailable = available;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable || _sending) {
      return;
    }

    if (_stage5b.isListening) {
      await _stage5b.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
          _avatarMode = 'IDLE';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isListening = true;
        _avatarMode = 'LISTENING';
      });
    }

    final started = await _stage5b.listen(localeId: 'en_US');

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _avatarMode = 'IDLE';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    _controller.clear();

    // Stage 5G: determine Douglas's emotional response.
    _detectEmotion(text);

    // Stage 5O: interpret physical/action commands.
    _handleDouglasActionCommand(text);

    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
      _sending = true;
      _avatarMode = 'THINKING';
    });

    _scrollToBottom();

    try {
      final response = await _aiService.sendMessage(
        message: text,
        history: List.unmodifiable(_messages),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(ChatMessage(text: response, role: MessageRole.assistant));
        _avatarMode = 'SPEAKING';
      });

      await _speakResponse(response);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: 'I encountered an error. Please try again.',
            role: MessageRole.assistant,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          if (!_isListening && _avatarState != 'SPEAKING') {
            _avatarMode = 'IDLE';
          }
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _visionService.dispose();
    _stage5bSpeechSubscription?.cancel();
    _stage5b.dispose();

    _tts.stop();
    _greetingTimer?.cancel();
    _speechIntensityTimer?.cancel();
    _idleController.dispose();
    _mouthController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF080B12),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/avatar/douglas_avatar.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOUGLAS AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Digital Human Assistant',
                  style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                ),
              ],
            ),
          ],
        ),
        actions: const [_InstallAppButton()],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF263142), width: 1),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Stage 5J: immersive avatar presentation.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x18000000),
                            Color(0x42000000),
                          ],
                        ),
                      ),
                    ),
                  ),

                  AnimatedBuilder(
                    animation: _idleController,
                    builder: (context, child) {
                      final t = _idleController.value * 2 * pi;
                      // Stage 5L: clearly visible but natural humanoid motion.
                      final baseBreathing = 1.0 + (sin(t) * 0.014);

                      final speakingPulse = _avatarState == 'SPEAKING'
                          ? 1.0 +
                                (sin(t * 2.15).abs() *
                                    0.008 *
                                    (1.0 + (_speechIntensity * 0.35)))
                          : 1.0;

                      final thinkingPulse = _avatarState == 'THINKING'
                          ? 1.0 + (sin(t * 1.15).abs() * 0.005)
                          : 1.0;

                      final breathing =
                          baseBreathing * speakingPulse * thinkingPulse;

                      // Natural torso/body sway.
                      final bodySway =
                          sin(t * 0.72) * 0.010 +
                          sin(t * 1.25) * 0.0035;

                      // State-aware head attention.
                      final headTurn =
                          sin(t * 0.52) * 0.014 +
                          (_avatarState == 'LISTENING'
                              ? 0.008
                              : _avatarState == 'THINKING'
                                  ? -0.006
                                  : _avatarState == 'SPEAKING'
                                      ? 0.004
                                      : 0.0);

                      // Visible vertical life movement.
                      final verticalMotion =
                          sin(t * 0.82) * 2.6 +
                          (_avatarState == 'LISTENING'
                              ? sin(t * 1.6).abs() * 1.8
                              : 0.0);

                      // Small speaking emphasis.
                      final speakingWave =
                          _avatarState == 'SPEAKING'
                              ? sin(t * 2.15) * 2.0
                              : 0.0;

                      return Transform.translate(
                        offset: Offset(
                          bodySway * 190,
                          verticalMotion + speakingWave,
                        ),
                        child: Transform.rotate(
                          angle: headTurn,
                          alignment: Alignment.center,
                          child: Transform.scale(
                            scale: breathing,
                            alignment: Alignment.center,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Stage 5P: live camera vision foundation.
                        // Camera capture runs independently while the
                        // existing Douglas avatar remains visible.
                        if (_hasCameraVision)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.001,
                                child: CameraPreview(
                                  _cameraController!,
                                ),
                              ),
                            ),
                          ),

                        Image.asset(
                          'assets/avatar/douglas_avatar.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),

                        // Stage 5P: vision capture control.
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _visionStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Material(
                                color: Colors.black.withValues(alpha: 0.68),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Let Douglas see',
                                  onPressed: _hasCameraVision && !_visionBusy
                                      ? _captureDouglasVisionFrame
                                      : null,
                                  icon: Icon(
                                    _visionBusy
                                        ? Icons.hourglass_top_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Stage 5F: subtle blinking and attention layer.
                        Positioned.fill(
                          child: _DouglasEyes(
                            animation: _idleController,
                            avatarState: _avatarState,
                          ),
                        ),

                        // Stage 5N: human facial-expression layer.
                        Positioned.fill(
                          child: _DouglasFacialExpression(
                            animation: _idleController,
                            emotion: _emotionState,
                          ),
                        ),

                        // Stage 5O: physical-action control layer.
                        Positioned.fill(
                          child: _DouglasActionLayer(
                            animation: _idleController,
                            action: _douglasActionState,
                          ),
                        ),

                        // Stage 5I: natural human gestures.
                        Positioned.fill(
                          child: _DouglasGestureLayer(
                            animation: _idleController,
                            avatarState: _avatarState,
                            emotion: _emotionState,
                          ),
                        ),

                        // Stage 5H: emotional tears.
                        Positioned.fill(
                          child: _DouglasTears(
                            animation: _idleController,
                            emotion: _emotionState,
                          ),
                        ),

                        // Stage 5G: emotional visual layer.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _idleController,
                              builder: (context, child) {
                                final pulse =
                                    (sin(_idleController.value * 2 * pi) + 1) /
                                        2;

                                final opacity = _emotionState == 'HAPPY'
                                    ? 0.018 + pulse * 0.012
                                    : _emotionState == 'SAD'
                                        ? 0.025 + pulse * 0.010
                                        : _emotionState == 'SURPRISED'
                                            ? 0.020 + pulse * 0.014
                                            : 0.0;

                                if (opacity <= 0.0) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.topCenter,
                                      radius: 0.85,
                                      colors: [
                                        Colors.white.withValues(
                                          alpha: opacity,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Stage 5E: animated mouth layer.
                        // The position is expressed proportionally so it
                        // follows the avatar when the image is resized.
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Stage 5E: Douglas's real mouth position
                              // based on the supplied 1214x1295 avatar composition.
                              final mouthWidth = constraints.maxWidth * 0.105;
                              final mouthHeight = mouthWidth * 0.42;
                              final mouthCenterX = constraints.maxWidth * 0.475;
                              final mouthCenterY = constraints.maxHeight * 0.209;

                              return Stack(
                                children: [
                                  Positioned(
                                    left: mouthCenterX - (mouthWidth / 2),
                                    top: mouthCenterY - (mouthHeight / 2),
                                    child: SizedBox(
                                      width: mouthWidth,
                                      height: mouthHeight,
                                      child: _DouglasMouth(
                                        animation: _mouthController,
                                        speaking: _avatarState == 'SPEAKING',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.45, 0.68, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sending
                                ? const Color(0xFFFFC857)
                                : const Color(0xFF32D583),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color:
                                    (_sending
                                            ? const Color(0xFFFFC857)
                                            : const Color(0xFF32D583))
                                        .withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _avatarState == 'THINKING'
                              ? 'DOUGLAS is thinking...'
                              : _avatarState == 'LISTENING'
                              ? 'DOUGLAS is listening...'
                              : _avatarState == 'SPEAKING'
                              ? 'DOUGLAS is speaking...'
                              : 'DOUGLAS is ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _MessageBubble(message: message);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_speechAvailable)
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: _isListening
                                    ? 'Stop listening'
                                    : 'Talk to DOUGLAS',
                                onPressed: _sending ? null : _toggleListening,
                                icon: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _isListening
                                      ? const Color(0xFF12B76A)
                                      : const Color(0xFF475467),
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Talk to DOUGLAS...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: FloatingActionButton(
                              heroTag: 'send',
                              elevation: 1,
                              onPressed: _sending ? null : _sendMessage,
                              backgroundColor: const Color(0xFF101828),
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.arrow_upward_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF101828) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF101828),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
