import 'package:flutter/material.dart';
import 'tabs/tab1.dart';
import 'tabs/tab2.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        highlightColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.white,
        splashColor: Colors.transparent,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      Tab1(),
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
        // unselectedIconTheme: IconThemeData(color: Colors.white),
        // selectedIconTheme: IconThemeData(color: Colors.deepOrange),
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