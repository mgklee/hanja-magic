import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tabs/tab1.dart';
import 'tabs/tab2.dart';

void main() async {
  late Map<String, dynamic> dict;
  late Map<String, dynamic> smp2trd;
  late Interpreter interpreter;
  late List<String> labels;

  // Ensures async operations work before runApp
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final jsonString = await rootBundle.loadString('assets/dict.json');
    dict = json.decode(jsonString);
  } catch (e) {
    print("Error loading dictionary: $e");
  }

  try {
    final jsonString = await rootBundle.loadString('assets/smp2trd.json');
    smp2trd = json.decode(jsonString);
  } catch (e) {
    print("Error loading smp2trd: $e");
  }

  try {
    interpreter = await Interpreter.fromAsset('assets/model.tflite');
  } catch (e) {
    print("Error loading model: $e");
  }

  try {
    final labelsData = await rootBundle.loadString('assets/labels.txt');
    labels = labelsData.split('\n'); // Directly assign the labels
  } catch (e) {
    print("Error loading labels: $e");
  }

  runApp(
    MyApp(
      dict: dict,
      smp2trd: smp2trd,
      interpreter: interpreter,
      labels: labels,
    )
  );
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic> dict;
  final Map<String, dynamic> smp2trd;
  final Interpreter interpreter;
  final List<String> labels;

  const MyApp({
    super.key,
    required this.dict,
    required this.smp2trd,
    required this.interpreter,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        highlightColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.white,
        splashColor: Colors.transparent,
      ),
      home: HomePage(
        dict: dict,
        smp2trd: smp2trd,
        interpreter: interpreter,
        labels: labels,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> dict;
  final Map<String, dynamic> smp2trd;
  final Interpreter interpreter;
  final List<String> labels;

  const HomePage({
    super.key,
    required this.dict,
    required this.smp2trd,
    required this.interpreter,
    required this.labels,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      Tab1(
        dict: widget.dict,
        smp2trd: widget.smp2trd,
        interpreter: widget.interpreter,
        labels: widget.labels,
      ),
      Tab2(),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80), // Custom height for the AppBar
        child: const SizedBox(height: 80),
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        elevation: 0,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.draw),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: "",
          ),
        ],
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}