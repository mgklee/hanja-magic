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
    {'name': '카카오톡', 'package': 'com.kakao.talk'},
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

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AddAppDialog(
                onAddApp: _addApp,
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddAppDialog extends StatelessWidget {
  final Function(String) onAddApp;

  AddAppDialog({required this.onAddApp});

  @override
  Widget build(BuildContext context) {
    TextEditingController nameController = TextEditingController();

    return AlertDialog(
      title: Text('앱 추가하기'),
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(hintText: '앱 이름 입력'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            String appName = nameController.text.trim();
            if (appName.isNotEmpty) {
              onAddApp(appName); // 콜백 호출
              Navigator.of(context).pop();
            }
          },
          child: Text('추가'),
        ),
      ],
    );
  }
}