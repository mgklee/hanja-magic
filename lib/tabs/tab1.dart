import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tab1 extends StatefulWidget {
  final Map<String, dynamic> dict;
  final Map<String, dynamic> smp2trd;
  final Interpreter interpreter;
  final List<String> labels;

  const Tab1({
    super.key,
    required this.dict,
    required this.smp2trd,
    required this.interpreter,
    required this.labels,
  });

  @override
  _Tab1State createState() => _Tab1State();
}

class _Tab1State extends State<Tab1> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.hanja_magic/apps');
  final List<Map<String, String>> _apps = [];
  List<Offset?> _points = [];
  List<String> _recognizedHanja = [];
  String _selectedHanja = "";
  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _canvasKey = GlobalKey();
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech; // Speech-to-text object
  bool _isListening = false; // Indicates if the app is currently listening
  String _spokenText = ""; // Stores the recognized text
  bool _isFromSP = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _startAutoScroll();
    configureTTS();

    // Initialize the SpeechToText object
    _speech = stt.SpeechToText();

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Define the scale animation
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('appsData');

    if (data != null) {
      final list = data.map((jsonStr) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }).toList();
      _apps.clear();
      _apps.addAll(list);
    }
  }

  Future<void> _launchApp(String packageName, String? extraData) async {
    try {
      final success = await platform.invokeMethod(
        'launchApp',
        {'packageName': packageName, 'extraData': extraData ?? "",}
      );
      if (!success) {
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cannot launch $packageName')));
      }
    } on PlatformException catch (_) {}
  }

  void _startAutoScroll() {
    Timer.periodic(Duration(milliseconds: 50), (Timer timer) {
      if (_scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;

        if (_scrollOffset < maxScrollExtent) {
          _scrollOffset += 2.0; // Adjust the scroll speed
          _scrollController.animateTo(
            _scrollOffset,
            duration: Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  void configureTTS() async {
    // Set language
    await _flutterTts.setLanguage("ko-KR");

    await _flutterTts.setVoice({
      "name": "ko-KR-SMTg01",
      "locale": "kor-x-lvariant-g01",
    });

    // Set speech rate
    await _flutterTts.setSpeechRate(0.5); // 0.0 to 1.0

    // Set pitch
    await _flutterTts.setPitch(1.0); // 0.5 to 2.0
  }

  void _findHanjaFromSpeech(String speechText) {
    // normalize spoken text
    String normalize(String text) {
      return text.replaceAll(RegExp(r'[^\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F\w]'), '').toLowerCase();
    }

    String normalizedInput = normalize(speechText);
    print("Normalized input: $normalizedInput");

    String? matchedHanja;

    // search hanja from _apps[]
    for (var app in _apps) {
      // spell + def + kor
      String appSpell = app["spell"] ?? "";
      String appDef = app["meaning"] ?? "";
      String appKor = app["reading"] ?? "";

      // normalize combined text
      String combinedText = normalize("$appSpell$appDef$appKor");

      if (combinedText == normalizedInput) {
        matchedHanja = app["hanja"];
        _isFromSP = true;
        break;
      }
    }

    // search hanja from dict.json
    if (matchedHanja == null) {
      widget.dict.forEach((hanja, details) {
        for (var detail in details) {
          // spell + def + kor
          String dbSpell = detail["spell"] ?? "";
          String dbDef = detail["def"] ?? "";
          String dbKor = detail["kor"] ?? "";

          // normalize combined text
          String combinedText = normalize("$dbSpell$dbDef$dbKor");

          if (combinedText == normalizedInput) {
            matchedHanja = hanja;
            _isFromSP = false;
            break;
          }
        }
      });
    }

    // get result
    if (matchedHanja != null) {
      print("Matched Hanja: $matchedHanja");
      _showHanja(matchedHanja!);
    } else {
      print("No matching Hanja found for $speechText");
    }
  }

  // Start listening to speech
  void _startListening() async {
    // Check and request microphone permission
    if (await Permission.microphone.request().isGranted) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
            print("spokenText is $_spokenText");
            if (_spokenText.isNotEmpty) {
              _findHanjaFromSpeech(_spokenText);
            }
          });
        });
      } else {
        print("Speech recognition not available");
      }
    } else {
      print("Microphone permission denied");
    }
  }

  // Stop listening
  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> recognizeHanja() async {
    final imagePath = await saveDrawingToImage();
    final inputImage = File(imagePath).readAsBytesSync();
    final input = preprocessImage(inputImage); // Prepare image input
    final output = List.generate(1, (index) => List.filled(3755, 0.0)); // Adjust output size

    try {
      widget.interpreter.run(input, output); // Run inference

      // Flatten the output tensor (if necessary) and extract scores
      final scores = output[0];

      // Pair scores with their indices and sort them by score in descending order
      final topResults = List.generate(scores.length, (index) => MapEntry(index, scores[index]))
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get the top-5 results
      final top5 = topResults.take(5).toList();

      // Display the top-5 candidates with their labels and scores
      setState(() {
        _recognizedHanja = top5.map((entry) => widget.labels[entry.key]).toList();
      });

      print("Top-5 Results:");
      for (var entry in top5) {
        print("${widget.labels[entry.key]}: ${entry.value}");
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

  void _showHanja(String hanja) {
    bool isInApps = _apps.any((app) => app["hanja"] == hanja);
    setState(() {
      _points.clear();
      _recognizedHanja = [];
      if (widget.smp2trd.containsKey(hanja)) {
        _selectedHanja = widget.smp2trd[hanja]!;
      } else {
        _selectedHanja = hanja;
      }
      _isFromSP = isInApps;
    });

    final dictEntry = widget.dict[_selectedHanja];
    if (dictEntry == null) {
      // dict에 전혀 없는 한자를 입력한 경우
      // 1) 음성으로 안내하고(또는 아무것도 안 하고),
      // 2) 혹시 애니메이션이라도 보여주고 싶다면 (한자만 표시)
      _flutterTts.speak("등록되지 않은 한자입니다.");
      _animationController.forward(from: 0).then((_) {
        Future.delayed(
          const Duration(milliseconds: 1000),
              () => setState(() => _selectedHanja = ""),
        );
      });
      return; // 아래 코드로 내려가지 않도록
    }

    _flutterTts.speak('${widget.dict[_selectedHanja]?[0]["spell"] ?? ""} ${widget.dict[_selectedHanja]?[0]["def"] ?? ""} ${widget.dict[_selectedHanja]?[0]["kor"] ?? ""}');

    _animationController.forward(from: 0).then((_) {
      _scrollOffset = 0;

      Future.delayed(
        const Duration(milliseconds: 1000),
        () {
          Map<String, String>? matchingApp = _apps.firstWhere(
            (app) => app["hanja"] == _selectedHanja, // Condition to match
            orElse: () => {"hanja": ""}, // What to return if no match is found
          );

          defaultHanjaMagic(hanja);

          if (matchingApp["hanja"] != "" && _isFromSP) {
            _launchApp(matchingApp['package']!, matchingApp['extraData']);
          } else {
            print("No matching app found");
          }

          setState(() => _selectedHanja = "");
        }
      );
    });
  }

  Future<void> defaultHanjaMagic(String hanja) async {
    switch (hanja) {
      case "光":
        await platform.invokeMethod('turnOnFlashlight');
        break;
      case "消":
        await platform.invokeMethod('turnOffFlashlight');
        break;
      case "震":
        await platform.invokeMethod('setVibrationMode');
        break;
      case "音":;
        await platform.invokeMethod('setSoundMode');
        break;
      case "無":
        await platform.invokeMethod('setSilentMode');
        break;
      case "暗":
        await platform.invokeMethod('enableDarkMode');
        break;
      case "明":
        await platform.invokeMethod('enableLightMode');
        break;
      case "出":
        await platform.invokeMethod('getOutApp');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController textController = TextEditingController();
    List<String> specialHanjas = ["友", "信", "勇", "敬", "忍", "學", "孝", "希", "情", "心"];

    return Center(
      child: SingleChildScrollView(
        child: _selectedHanja.isNotEmpty
          ? ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    // Text with border effect
                    Text(
                      _selectedHanja,
                      style: TextStyle(
                        fontSize: 300,
                        fontFamily: 'HanyangHaeseo',
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4 // Border thickness
                          ..color = specialHanjas.contains(_selectedHanja)
                            ? Color(0xFF80B23D)
                            : Color(0xFFDB7890), // Border color
                      ),
                    ),
                    // Main text
                    Text(
                      _selectedHanja,
                      style: TextStyle(
                        fontSize: 300,
                        fontFamily: 'HanyangHaeseo',
                        fontWeight: FontWeight.bold,
                        color: specialHanjas.contains(_selectedHanja)
                          ? Color(0xFFA6CB5B)
                          : Color(0xFFE392A3), // Text color
                      ),
                    ),
                  ],
                ),
                ...?(
                    _isFromSP
                        ? _apps.where((e) => e['hanja'] == _selectedHanja)
                        : widget.dict[_selectedHanja] ?? []
                ).map((e) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e["spell"] != null)
                          Text(
                            "${e["spell"]} ",
                            style: const TextStyle(
                              fontSize: 30,
                              fontFamily: 'YunGothic',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${e["def"]} ",
                              style: const TextStyle(
                                fontSize: 40,
                                fontFamily: 'YunGothic',
                                color: Color(0xFF0177C4),
                              ),
                            ),
                            Text(
                              "${e["kor"]}",
                              style: const TextStyle(
                                fontSize: 40,
                                fontFamily: 'YunGothic',
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0177C4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                            setState(() => _points.add(localPosition));
                          }
                        },
                        onPanEnd: (_) {
                          setState(() => _points.add(null)); // Separate strokes
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
                          icon: Icon(Icons.mic),
                          color: _isListening ? Colors.red : Colors.green,
                          onPressed: _isListening ? _stopListening : _startListening,
                        ),
                        IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () => recognizeHanja(),
                        ),
                        IconButton(
                          icon: Icon(Icons.undo),
                          onPressed: () {
                            setState(() {
                              if (_points.isNotEmpty) {
                                int lastStrokeIndex = _points.sublist(0, _points.length - 1).lastIndexOf(null);
                                if (lastStrokeIndex != -1) {
                                  _points.removeRange(lastStrokeIndex, _points.length - 1);
                                } else {
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
                              _recognizedHanja = [];
                              _selectedHanja = "";
                            });
                          },
                        ),
                      ],
                    ),
                    // Display spoken text (optional)
                    if (_spokenText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Spoken Text: $_spokenText",
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                        ),
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
                            _showHanja(value); // Show the typed Hanja
                            textController.clear(); // Clear the text field after submission
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_recognizedHanja.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: _recognizedHanja.map((hanja) {
                      return TextButton(
                        onPressed: () => _showHanja(hanja),
                        child: Text(
                          hanja,
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