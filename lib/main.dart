import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fungi Variety',
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

class Classifier {
  tfl.Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 224;
  bool _isFloat = true;

  Future<void> load() async {
    if (_interpreter != null) return;
    final interpreter = await tfl.Interpreter.fromAsset('assets/model_unquant.tflite');
    _interpreter = interpreter;
    final inputShape = interpreter.getInputTensor(0).shape;
    _inputSize = inputShape.length >= 3 ? inputShape[1] : 224;
    _isFloat = true;
    final labelsStr = await rootBundle.loadString('assets/labels.txt');
    _labels = labelsStr
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.replaceFirst(RegExp(r'^\s*\d+\s*'), '').trim())
        .toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  Future<List<double>> classifyProbs(File file) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Interpreter not loaded');
    }
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Failed to decode image');
    // Center-crop to square to avoid distortion, then resize to model input
    final shortest = decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropX = ((decoded.width - shortest) / 2).floor();
    final cropY = ((decoded.height - shortest) / 2).floor();
    final square = img.copyCrop(decoded, x: cropX, y: cropY, width: shortest, height: shortest);
    final resized = img.copyResize(square, width: _inputSize, height: _inputSize);
    if (_isFloat) {
      final input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0))));
      final rgba = resized.getBytes(order: img.ChannelOrder.rgba);
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final base = (y * _inputSize + x) * 4;
          // Normalize to [0, 1]
          final r = rgba[base] / 255.0;
          final g = rgba[base + 1] / 255.0;
          final b = rgba[base + 2] / 255.0;
          input[0][y][x][0] = r;
          input[0][y][x][1] = g;
          input[0][y][x][2] = b;
        }
      }
      final outputTensor = interpreter.getOutputTensor(0);
      final numClasses = outputTensor.shape.last;
      final output = [List.filled(numClasses, 0.0)];
      interpreter.run(input, output);
      final probs = (output[0] as List).cast<double>();
      return probs;
    } else {
      final input = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(3, 0))));
      final rgba = resized.getBytes(order: img.ChannelOrder.rgba);
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final base = (y * _inputSize + x) * 4;
          input[0][y][x][0] = rgba[base];
          input[0][y][x][1] = rgba[base + 1];
          input[0][y][x][2] = rgba[base + 2];
        }
      }
      final outputTensor = interpreter.getOutputTensor(0);
      final numClasses = outputTensor.shape.last;
      final output = [List.filled(numClasses, 0)];
      interpreter.run(input, output);
      final probs = (output[0] as List).map((e) => (e as int).toDouble()).toList();
      return probs;
    }
  }

  Future<List<Map<String, dynamic>>> classify(File file, {int topK = 3}) async {
    final probs = await classifyProbs(file);
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < probs.length; i++) {
      final label = i < _labels.length ? _labels[i] : 'Class $i';
      results.add({'label': label, 'index': i, 'confidence': probs[i]});
    }
    results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    return results.take(topK).toList();
  }

  String formatTopResult(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return 'No result';
    final best = results.first;
    final conf = (best['confidence'] as double);
    return '${best['label']} • ${(conf * 100).toStringAsFixed(1)}%';
  }
}

class FungiInfo {
  final String name;
  final String description;
  final String imagePath;

  const FungiInfo({
    required this.name,
    required this.description,
    required this.imagePath,
  });
}

const List<FungiInfo> kFungiDictionary = [
  FungiInfo(
    name: 'Button Mushroom',
    description:
        'A small, white mushroom that is commonly used in cooking. It has a mild flavor and soft texture. This is the type you often see in grocery stores.',
    imagePath: 'assets/photos/button.jpg',
  ),
  FungiInfo(
    name: 'Oyster Mushroom',
    description:
        'A mushroom with wide, fan-shaped caps that look like oysters. It has a soft, delicate texture and a slightly sweet, mild taste. Often used in stir-fries and soups.',
    imagePath: 'assets/photos/oyster.jpg',
  ),
  FungiInfo(
    name: 'Enoki Mushroom',
    description:
        'A mushroom with long, thin stems and tiny white caps. It grows in tight bunches and has a crunchy texture. Common in ramen, hotpot, and salads.',
    imagePath: 'assets/photos/enoki.jpg',
  ),
  FungiInfo(
    name: 'Morel Mushroom',
    description:
        'A rare mushroom with a honeycomb-like cap full of holes. It has a rich, earthy flavor and is considered a gourmet ingredient.',
    imagePath: 'assets/photos/morel.jpg',
  ),
  FungiInfo(
    name: 'Chanterelle Mushroom',
    description:
        'A bright yellow or orange mushroom shaped like a small trumpet. It has a fruity smell and a slightly peppery taste. Popular in fine dining dishes.',
    imagePath: 'assets/photos/chanterelles.jpg',
  ),
  FungiInfo(
    name: 'Black Trumpet Mushroom',
    description:
        'A dark, funnel-shaped mushroom that almost looks like a hollow trumpet. It has a smoky, deep flavor and is often used in sauces.',
    imagePath: 'assets/photos/black_trumpet.jpg',
  ),
  FungiInfo(
    name: 'Fly Agaric Mushroom',
    description:
        'A bright red mushroom with white spots. It is famous in fairy tales and video games. Not safe to eat, as it can be poisonous.',
    imagePath: 'assets/photos/fly_agaric.jpg',
  ),
  FungiInfo(
    name: 'Reishi Mushroom',
    description:
        'A tough, woody mushroom often used in traditional medicine. It has a shiny, reddish surface and is usually made into teas or supplements, not eaten as food.',
    imagePath: 'assets/photos/reishi.jpg',
  ),
  FungiInfo(
    name: 'Coral Fungus',
    description:
        'A fungus that looks like underwater coral, with many branching arms. It comes in different colors and grows on the forest floor.',
    imagePath: 'assets/photos/coral.jpg',
  ),
  FungiInfo(
    name: 'Bleeding Tooth Fungus',
    description:
        'A white fungus that “bleeds” bright red liquid droplets. It looks unusual and is not edible. The red appearance comes from natural pigments.',
    imagePath: 'assets/photos/bleeding_tooth.jpeg',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;
  final Classifier _classifier = Classifier();
  bool _showDictionary = false;

  Future<void> _runClassificationAndShow(File file) async {
    await _classifier.load();
    final start = DateTime.now();
    List<double>? sum;
    int count = 0;
    while (DateTime.now().difference(start).inSeconds < 10) {
      final probs = await _classifier.classifyProbs(file);
      sum ??= List.filled(probs.length, 0.0);
      for (int i = 0; i < probs.length; i++) {
        sum[i] += probs[i];
      }
      count++;
      await Future.delayed(const Duration(milliseconds: 600));
    }
    final avg = sum!.map((v) => v / count).toList();
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < avg.length; i++) {
      results.add({'label': i < _classifier._labels.length ? _classifier._labels[i] : 'Class $i', 'index': i, 'confidence': avg[i]});
    }
    results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_classifier.formatTopResult(results)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Averaged over $count runs',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...results.take(3).map((r) => Text(
                  '${r['label']} - ${((r['confidence'] as double) * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _classifier.load();
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picking) {
      return;
    }
    setState(() {
      _picking = true;
    });
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted) {
        return;
      }
      if (picked != null) {
        await _runClassificationAndShow(File(picked.path));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

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
              padding: const EdgeInsets.only(top: 40, left: 24, right: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FractionallySizedBox(
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
                                  'Scan Fungus',
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
                                onPressed: _picking ? null : _pickImage,
                                icon: const Icon(Icons.upload_file_outlined),
                                label: _picking
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      )
                                    : Text(
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
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _showDictionary = !_showDictionary;
                              });
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fungi Dictionary',
                                        style: GoogleFonts.titanOne(
                                          fontSize: 24,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to ${_showDictionary ? 'hide' : 'view'} the list of fungi classes.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showDictionary
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          if (_showDictionary) ...[
                            const SizedBox(height: 16),
                            ...kFungiDictionary.map(
                              (fungus) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(
                                            fungus.name,
                                            style: GoogleFonts.titanOne(
                                              fontSize: 22,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: AspectRatio(
                                                  aspectRatio: 1,
                                                  child: Image.asset(
                                                    fungus.imagePath,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                fungus.description,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.asset(
                                          fungus.imagePath,
                                          height: 48,
                                          width: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          fungus.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
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
  final Classifier _classifier = Classifier();
  bool _processing = false;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _classifier.load();
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
    _classifier.dispose();
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? size,
                        height: controller.value.previewSize?.width ?? size,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
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
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(child: _buildCameraPreview()),
                Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.85),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              minimum: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _processing ? null : _scanAndClassifyFor10s,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: _processing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera),
                    label: Text(
                      _processing ? 'Scanning ${_countdown}s...' : 'Scan 10s & Identify',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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

// removed custom reshape extension; we build 2D lists directly for outputs

extension _CameraScanActions on _CameraPageState {
  Future<void> _scanAndClassifyFor10s() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      _processing = true;
      _countdown = 10;
    });
    try {
      await _classifier.load();
      final end = DateTime.now().add(const Duration(seconds: 10));
      List<double>? sum;
      int count = 0;
      int lastSecond = 10;
      while (DateTime.now().isBefore(end)) {
        // Update countdown once per second
        final rem = end.difference(DateTime.now()).inSeconds + 1;
        if (rem != lastSecond && mounted) {
          setState(() => _countdown = rem.clamp(0, 10));
          lastSecond = rem;
        }

        // Capture a frame and classify
        final xfile = await controller.takePicture();
        final probs = await _classifier.classifyProbs(File(xfile.path));
        sum ??= List.filled(probs.length, 0.0);
        for (int i = 0; i < probs.length; i++) {
          sum[i] += probs[i];
        }
        count++;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final avg = sum?.map((v) => v / (count == 0 ? 1 : count)).toList() ?? [];
      final results = <Map<String, dynamic>>[];
      for (int i = 0; i < avg.length; i++) {
        results.add({'label': i < _classifier._labels.length ? _classifier._labels[i] : 'Class $i', 'index': i, 'confidence': avg[i]});
      }
      results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
      if (!mounted) return;
      final best = results.isNotEmpty ? results.first : null;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Prediction', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (best != null)
                Text('${best['label']}', style: GoogleFonts.titanOne(fontSize: 24, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 8),
              Text('Averaged over $count frames', style: GoogleFonts.poppins()),
              const SizedBox(height: 8),
              ...results.take(3).map((r) => Text(
                    '${r['label']} - ${((r['confidence'] as num) * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(),
                  )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to scan: $e')));
    } finally {
      if (mounted) setState(() {
        _processing = false;
        _countdown = 0;
      });
    }
  }
}
