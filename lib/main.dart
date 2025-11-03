import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: Colors.red, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class PolkaDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(98765); // New seed for wider distribution
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Divide the space into sections for better distribution
    final sections = 5;
    final sectionWidth = size.width / sections;

    // Create different sized dots for more natural look
    final dots = [
      {
        "size": 14.0,
        "count": 3,
        "opacity": 0.9,
      }, // Slightly smaller but more spread
      {"size": 10.0, "count": 4, "opacity": 0.85},
      {"size": 8.0, "count": 5, "opacity": 0.8},
    ];

    // Function to check if a point is too close to existing dots
    List<Offset> existingDots = [];
    bool isTooClose(Offset newPoint, double minDistance) {
      for (final dot in existingDots) {
        if ((dot - newPoint).distance < minDistance) {
          return true;
        }
      }
      return false;
    }

    // Draw dots section by section
    for (int section = 0; section < sections; section++) {
      for (final dot in dots) {
        paint.color = Colors.white.withOpacity(dot["opacity"] as double);
        final dotSize = dot["size"] as double;

        for (int i = 0; i < (dot["count"] as int); i++) {
          // Try to place dot up to 10 times to ensure good spacing
          for (int attempt = 0; attempt < 10; attempt++) {
            final x =
                section * sectionWidth + random.nextDouble() * sectionWidth;
            final y = random.nextDouble() * size.height;
            final newPoint = Offset(x, y);

            // Check if dot is well-spaced and within bounds
            if (!isTooClose(newPoint, dotSize * 2) &&
                x > dotSize &&
                x < size.width - dotSize &&
                y > dotSize &&
                y < size.height - dotSize) {
              // Draw glow/outline effect
              paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);
              paint.color = Colors.white.withOpacity(0.3);
              canvas.drawCircle(newPoint, (dotSize / 2) + 1, paint);

              // Draw main dot
              paint.maskFilter = null;
              paint.color = Colors.white.withOpacity(dot["opacity"] as double);
              canvas.drawCircle(newPoint, dotSize / 2, paint);

              existingDots.add(newPoint);
              break;
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'Fungi Scan',
              style: GoogleFonts.titanOne(
                fontSize: 40,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5
                  ..color = Colors.black87,
              ),
            ),
            Text(
              'Fungi Scan',
              style: GoogleFonts.titanOne(
                fontSize: 40,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 3,
                    color: Colors.black87,
                  ),
                  Shadow(
                    offset: Offset(2, 0),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                  Shadow(
                    offset: Offset(-2, 0),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                  Shadow(
                    offset: Offset(0, -2),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Stack(
          children: [
            Container(color: Colors.red),
            CustomPaint(painter: PolkaDotPainter(), child: Container()),
          ],
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 1),
              child: Image.asset(
                'assets/background.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
              child: FractionallySizedBox(
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '🍄',
                            style: TextStyle(
                              fontSize: 40,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Fungi Scan',
                        style: GoogleFonts.titanOne(
                          fontSize: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scan or upload photos to see which fungi species you have found.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration: const Duration(
                                  milliseconds: 400,
                                ),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const CameraPage(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      final tween =
                                          Tween(
                                            begin: const Offset(0, 1),
                                            end: Offset.zero,
                                          ).chain(
                                            CurveTween(curve: Curves.easeInOut),
                                          );
                                      return SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          },
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            'Scan Mushroom',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(
                            'Upload Photo',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _permissionDenied = false;
  bool _initializing = false;
  bool _noAvailableCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializing) {
      return;
    }
    setState(() {
      _initializing = true;
      _permissionDenied = false;
      _noAvailableCamera = false;
    });
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      if (cameras.isEmpty) {
        setState(() {
          _noAvailableCamera = true;
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
      await _controller?.dispose();
      final initializeFuture = controller.initialize();
      setState(() {
        _controller = controller;
        _initializeControllerFuture = initializeFuture;
      });
      await initializeFuture;
    } on CameraException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt') {
        setState(() {
          _permissionDenied = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() {
        _controller = null;
        _initializeControllerFuture = null;
      });
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (_permissionDenied) {
      return const Center(
        child: Text(
          'Camera permission denied',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }
    if (_noAvailableCamera) {
      return const Center(
        child: Text(
          'No camera available',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }
    final controller = _controller;
    final future = _initializeControllerFuture;
    if (controller == null || future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(controller);
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Failed to start camera',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 24),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
