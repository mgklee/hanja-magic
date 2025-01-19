import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

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

  final List<Map<String, String>> _apps = [];
  List<String> _appnames = [];
  List<String> _packages = [];
  List<Map<String, String>> installedApps = [];
  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInstalledApps();
    _loadApps();
  }

  Future<void> _loadApps() async {
    await logAppsData();
    final prefs = await SharedPreferences.getInstance();
    final List<String>? appData = prefs.getStringList('appsData'); // SharedPreferences에서 데이터 읽기
    if (appData != null) {
      final List<Map<String, String>> apps = appData.map((app) {
        final decoded = jsonDecode(app) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString())); // String으로 변환
      }).toList();

      setState(() {
        _apps.clear();
        _apps.addAll(apps); // 변환된 데이터를 _apps에 추가
      });
    }
  }


  Future<void> _saveApps(List<Map<String, String>> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> appData = apps.map((app) {
      return jsonEncode({
        'name': app['name'],
        'package': app['package'],
        'icon': app['icon'], // 아이콘 Base64 포함
      });
    }).toList();
    await prefs.setStringList('appsData', appData);
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final List<dynamic> apps = await platform.invokeMethod('getInstalledApps');
      setState(() {
        installedApps = apps.map((app) {
          final appMap = Map<String, dynamic>.from(app);
          return appMap.map((key, value) => MapEntry(key, value.toString())); // String으로 변환
        }).toList();
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
        _apps.add({
          'name': app['name']!,
          'package': app['package']!,
          'icon': app['icon']!,
        });
      });

      // 저장 시 이름과 패키지 모두 저장
      await _saveApps(_apps);

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
      // 앱 이름이 아닌 전체 객체(Map<String, String>)를 삭제하도록 수정
      _apps.removeWhere((app) => app['name'] == appName);
    });

    // 저장된 앱 데이터 업데이트
    final List<String> appData = _apps.map((app) {
      return jsonEncode({
        'name': app['name'],
        'package': app['package'],
        'icon': app['icon'], // icon 필드 추가
      });
    }).toList();
    await prefs.setStringList('appsData', appData); // Key 변경: apps -> appsData

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$appName 삭제되었습니다.')),
    );
  }

  Future<void> logAppsData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? appData = prefs.getStringList('appsData');
    if (appData != null) {
      print("SharedPreferences appsData: $appData");
    } else {
      print("SharedPreferences appsData is empty or null.");
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
                ...fixedApps.map((app) {
                  return ListTile(
                    leading: Icon(Icons.android),
                    title: Text(app['name']!),
                    onTap: () => _launchApp(app['package']!),
                  );
                }).toList(),
                Divider(),
                ..._apps.map((app) {
                  final String cleanedIcon = app['icon']!.trim().replaceAll('\n', '').replaceAll('\r', '');
                  final Uint8List? iconData = base64Decode(cleanedIcon);
                  return ListTile(
                    leading: iconData != null
                        ? Image.memory(
                      iconData,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                        : Icon(Icons.android), // 아이콘이 없을 경우 기본 아이콘 표시
                    title: Text(app['name']!),
                    subtitle: Text(app['package']!),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        deleteAppDialog(context, app['name']!); // 이름 전달
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
