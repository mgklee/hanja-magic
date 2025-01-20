import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class Tab1 extends StatefulWidget {
  const Tab1({super.key});

  @override
  _Tab1State createState() => _Tab1State();
}

class _Tab1State extends State<Tab1> with SingleTickerProviderStateMixin {
  List<Offset?> _points = [];
  List<String> _recognizedHanzi = [];
  String _selectedHanzi = "";
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Map<String, dynamic> _dict;
  late Interpreter _interpreter;
  late List<String> _labels = [];
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Define the scale animation
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    loadDict();
    loadModel();
    loadLabels();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> loadDict() async {
    try {
      final jsonString = await rootBundle.loadString('assets/dict.json');
      _dict = json.decode(jsonString);
      print(_dict);
    } catch (e) {
      print("Error loading dictionary: $e");
    }
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<void> loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n'); // Directly assign the labels
    } catch (e) {
      print("Error loading labels: $e");
    }
  }

  Future<void> recognizeHanzi() async {
    final imagePath = await saveDrawingToImage();
    final inputImage = File(imagePath).readAsBytesSync();
    final input = preprocessImage(inputImage); // Prepare image input
    final output = List.generate(1, (index) => List.filled(3755, 0.0)); // Adjust output size

    try {
      _interpreter.run(input, output); // Run inference

      // Flatten the output tensor (if necessary) and extract scores
      final scores = output[0];

      // Pair scores with their indices and sort them by score in descending order
      final topResults = List.generate(scores.length, (index) => MapEntry(index, scores[index]))
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get the top-5 results
      final top5 = topResults.take(5).toList();

      // Display the top-5 candidates with their labels and scores
      setState(() {
        _recognizedHanzi = top5.map((entry) => _labels[entry.key]).toList();
      });

      print("Top-5 Results:");
      for (var entry in top5) {
        print("${_labels[entry.key]}: ${entry.value}");
      }
    } catch (e) {
      print("Error during inference: $e");
    }
  }

  List<List<dynamic>> preprocessImage(Uint8List imageBytes) {
    // Decode the image bytes
    final originalImage = img.decodeImage(Uint8List.fromList(imageBytes));
    if (originalImage == null) {
      throw Exception("Failed to decode image");
    }

    // Resize the image to 96x96
    final resizedImage = img.copyResize(originalImage, width: 96, height: 96);

    // Convert the image to grayscale
    final grayscaleImage = img.grayscale(resizedImage);

    // Normalize the image to have pixel values between 0 and 1
    List rows = [];
    for (int y = 0; y < grayscaleImage.height; y++) {
      List row = [];
      for (int x = 0; x < grayscaleImage.width; x++) {
        final pixel = grayscaleImage.getPixel(x, y);
        final luminance = pixel.a;
        row.add([luminance / 255.0]); // Normalize to [0, 1]
      }
      rows.add(row);
    }

    // Add batch dimension and reshape to [1, 96, 96, 1]
    return [rows];
  }

  Future<String> saveDrawingToImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15.0;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/drawing.png';
    final file = File(filePath);
    await file.writeAsBytes(buffer);

    return filePath;
  }

  void _showHanzi(String hanzi) {
    setState(() {
      _points.clear();
      _recognizedHanzi = [];
      _selectedHanzi = hanzi;
    });

    _controller.forward(from: 0).then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        _controller.reverse().then((_) {
          // Clear _selectedHanzi after the reverse animation finishes
          setState(() {
            _selectedHanzi = "";
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController textController = TextEditingController();

    return SingleChildScrollView(
      child: Center(
        child: _selectedHanzi.isNotEmpty
          ? ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    // Text with border effect
                    Text(
                      _selectedHanzi,
                      style: TextStyle(
                        fontSize: 300,
                        fontFamily: 'HanyangHaeseo',
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4 // Border thickness
                          ..color = Color(0xFFDB7890), // Border color
                      ),
                    ),
                    // Main text
                    Text(
                      _selectedHanzi,
                      style: const TextStyle(
                        fontSize: 300,
                        fontFamily: 'HanyangHaeseo',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE392A3), // Text color
                      ),
                    ),
                  ],
                ),
                ...?_dict[_selectedHanzi]?.map((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${e["def"]} ",
                        style: const TextStyle(
                          fontSize: 50,
                          fontFamily: 'YunGothic',
                          color: Color(0xFF308AC6),
                        ),
                      ),
                      Text(
                        "${e["kor"]}",
                        style: const TextStyle(
                          fontSize: 50,
                          fontFamily: 'YunGothic',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF308AC6),
                        ),
                      ),
                    ],
                  );
                }) ?? [],
              ],
            ),
          )
          : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 300,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          final RenderBox renderBox =
                          _canvasKey.currentContext!.findRenderObject() as RenderBox;
                          final canvasSize = renderBox.size;

                          // Restrict the points within the canvas bounds
                          final localPosition = details.localPosition;
                          if (localPosition.dx >= 7 &&
                              localPosition.dy >= 7 &&
                              localPosition.dx <= canvasSize.width - 15 &&
                              localPosition.dy <= canvasSize.height - 15) {
                            setState(() {
                              _points.add(localPosition);
                            });
                          }
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _points.add(null); // Separate strokes
                          });
                        },
                        child: Container(
                          key: _canvasKey, // Assign the key to the canvas container
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.green, width: 4.0),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: HandwritingPainter(_points),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () => recognizeHanzi(),
                        ),
                        IconButton(
                          icon: Icon(Icons.undo),
                          onPressed: () {
                            setState(() {
                              // Remove the last stroke
                              if (_points.isNotEmpty) {
                                int lastStrokeIndex = _points.lastIndexOf(null);
                                if (lastStrokeIndex != -1) {
                                  _points.removeRange(lastStrokeIndex, _points.length);
                                } else {
                                  // If there are no null separators, clear the entire drawing
                                  _points.clear();
                                }
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _points.clear();
                              _recognizedHanzi = [];
                              _selectedHanzi = "";
                            });
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          labelText: "한자를 입력하세요",
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^[\u4E00-\u9FFF]$'), // Allows only one Chinese character
                          ),
                        ],
                        maxLength: 1, // Limits input to one character
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _showHanzi(value); // Show the typed Hanzi
                            textController.clear(); // Clear the text field after submission
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_recognizedHanzi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: _recognizedHanzi.map((hanzi) {
                      return TextButton(
                        onPressed: () => _showHanzi(hanzi),
                        child: Text(
                          hanzi,
                          style: TextStyle(fontSize: 18)
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
      ),
    );
  }
}

class HandwritingPainter extends CustomPainter {
  final List<Offset?> points;

  HandwritingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashWidth = 5.0; // Length of each dash
    final dashSpace = 5.0; // Space between dashes

    // Draw the center horizontal dotted line
    _drawDashedLine(
      canvas,
      Offset(0, size.height / 2), // Start at middle height
      Offset(size.width, size.height / 2), // End at middle height
      gridPaint,
      dashWidth,
      dashSpace,
    );

    // Draw the center vertical dotted line
    _drawDashedLine(
      canvas,
      Offset(size.width / 2, 0), // Start at middle width
      Offset(size.width / 2, size.height), // End at middle width
      gridPaint,
      dashWidth,
      dashSpace,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashWidth, double dashSpace) {
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double distance = dx.abs() + dy.abs();
    double dashCount = (distance / (dashWidth + dashSpace)).floorToDouble();

    for (int i = 0; i < dashCount; i++) {
      double t1 = i / dashCount;
      double t2 = (i + 1) / dashCount;
      Offset p1 = Offset(start.dx + dx * t1, start.dy + dy * t1);
      Offset p2 = Offset(start.dx + dx * t2, start.dy + dy * t2);
      if (i % 2 == 0) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}