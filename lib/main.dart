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
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
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
      appBar: AppBar(
        title: const Text("마법천자문"),
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // unselectedIconTheme: IconThemeData(color: Colors.white),
        // selectedIconTheme: IconThemeData(color: Colors.deepOrange),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: "Tab 1"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: "Tab 2"
          ),
        ],
      ),
    );
  }
}