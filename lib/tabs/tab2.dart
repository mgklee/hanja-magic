import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tab2 extends StatefulWidget {
  const Tab2({super.key});

  @override
  _Tab2State createState() => _Tab2State();
}

class _Tab2State extends State<Tab2> {
  static const platform = MethodChannel('com.example.hanja_magic/apps');

  final List<Map<String, String>> fixedApps = [
    {'name': 'Chrome', 'package': 'com.android.chrome'},
    {'name': '카카오톡', 'package': 'com.kakao.talk'},
    {'name': 'Gmail', 'package': 'com.google.android.gm'},
  ];

  final List<String> _apps = [];
  List<Map<String, String>> installedApps = [];
  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInstalledApps();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedApps = prefs.getStringList('apps');
    if (savedApps != null) {
      setState(() {
        _apps.clear();
        _apps.addAll(savedApps);
      });
    }
  }

  Future<void> _saveApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('apps', _apps);
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

  void _addApp(String name) async {
    final app = installedApps.firstWhere(
          (app) => app['name']!.toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
    if (app.isNotEmpty) {
      setState(() {
        _apps.add(app['name']!);
      });
      await _saveApps();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App ${app['name']} added!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App not found: $name')),
      );
    }
    nameController.clear();
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

  void deleteAppDialog(BuildContext context, String appName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$appName 삭제하겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _deleteApp(appName);
                Navigator.of(context).pop();
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteApp(String appName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apps.remove(appName);
    });
    await prefs.setStringList('apps', _apps);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$appName 삭제되었습니다.')),
    );
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
                ...fixedApps.map((app) {
                  return ListTile(
                    title: Text(app['name']!),
                    onTap: () => _launchApp(app['package']!),
                  );
                }).toList(),
                Divider(),
                ..._apps.map((appName) {
                  final app = installedApps.firstWhere(
                        (app) => app['name'] == appName,
                    orElse: () => {'name': appName, 'package': ''},
                  );
                  return ListTile(
                    title: Text(app['name']!),
                    subtitle: Text(app['package']!),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        deleteAppDialog(context, appName);
                      },
                    ),
                    onTap: app['package']!.isNotEmpty
                        ? () => _launchApp(app['package']!)
                        : null,
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
              onAddApp(appName);
              Navigator.of(context).pop();
            }
          },
          child: Text('추가'),
        ),
      ],
    );
  }
}
