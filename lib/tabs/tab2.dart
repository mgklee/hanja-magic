import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';



class Tab2 extends StatefulWidget {
  const Tab2({super.key});

  @override
  _Tab2State createState() => _Tab2State();
}
/////
/////
/////
/////

class _Tab2State extends State<Tab2> {
  static const platform = MethodChannel('com.example.hanja_magic/apps');

  final List<Map<String, String>> fixedApps = [
    {'name': 'Chrome', 'package': 'com.android.chrome'},
    {'name': 'YouTube', 'package': 'com.google.android.youtube'},
    {'name': 'Gmail', 'package': 'com.google.android.gm'},
  ];

  List<Map<String, String>> installedApps = [];
  List<Map<String, String>> registeredApps = [];

  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInstalledApps();
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final List<dynamic> apps = await platform.invokeMethod('getInstalledApps');
      setState(() {
        installedApps = apps.map((app) => Map<String, String>.from(app)).toList();
      });
    } on PlatformException catch (e) {
      print("Failed to load installed apps: ${e.message}");
    }
  }

  void _addApp(String name) {
    final app = installedApps.firstWhere(
          (app) => app['name']!.toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
    if (app.isNotEmpty) {
      setState(() {
        registeredApps.add(app); // 검색된 앱을 registeredApps에 추가
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App ${app['name']} added!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App not found: $name')),
      );
    }
    nameController.clear(); // 입력 필드 초기화
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Launcher'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 고정된 버튼 리스트
                ...fixedApps.map((app) {
                  return ListTile(
                    title: Text(app['name']!),
                    onTap: () => _launchApp(app['package']!),
                  );
                }).toList(),
                Divider(), // 구분선
                // 사용자가 추가한 앱 리스트
                ...registeredApps.map((app) {
                  return ListTile(
                    title: Text(app['name']!),
                    subtitle: Text(app['package']!),
                    onTap: () => _launchApp(app['package']!),
                  );
                }).toList(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'App Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _addApp(nameController.text),
                  child: Text('Add App'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      color: const Color(0xFFF7F7F7),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: Icon(icon, size: 40.0, color: const Color(0xFF18C971)),
        title: Text(label, style: const TextStyle(fontSize: 16.0)),
        onTap: onTap,
      ),
    );
  }


  Future<void> _launchApp(String packageName) async {
    try {
      final success = await platform.invokeMethod('launchApp', {'packageName': packageName});
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch app: $packageName')),
        );
      }
    } on PlatformException catch (e) {
      print("Failed to launch app: ${e.message}");
    }
  }

  // 카메라 실행 함수
  Future<void> _launchCamera() async {
    final intent = AndroidIntent(
      action: 'android.media.action.IMAGE_CAPTURE',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  // 전화 앱 실행 함수
  Future<void> _makeCall(String phoneNumber) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.DIAL',
      data: phoneNumber,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }
}