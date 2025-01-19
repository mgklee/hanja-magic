import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

class Tab2 extends StatefulWidget {
  const Tab2({Key? key}) : super(key: key);

  @override
  _Tab2State createState() => _Tab2State();
}

class _Tab2State extends State<Tab2> with AutomaticKeepAliveClientMixin {
  static const platform = MethodChannel('com.example.hanja_magic/apps');

  final List<Map<String, String>> fixedApps = [
    {'name': 'Chrome', 'package': 'com.android.chrome'},
    {'name': '카카오톡', 'package': 'com.kakao.talk'},
    {'name': 'Gmail', 'package': 'com.google.android.gm'},
  ];
  final List<Map<String, String>> _apps = [];
  final TextEditingController nameController = TextEditingController();
  List<String> installedAppNames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInstalledAppNames().then((_) {
      // 설치된 앱 이름 목록을 먼저 받아오고,
      _loadApps().then((_) {
        // SharedPreferences에서 _apps 로드
        setState(() {
          isLoading = false;
        });
      });
    });
  }

  // AutomaticKeepAliveClientMixin을 쓰려면 override 필수
  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchInstalledAppNames() async {
    try {
      final List<dynamic> names =
      await platform.invokeMethod('getInstalledAppNames');
      setState(() {
        installedAppNames = names.cast<String>();
      });
    } on PlatformException catch (_) {}
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

  Future<void> _saveApps() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _apps.map((app) => jsonEncode(app)).toList();
    await prefs.setStringList('appsData', data);
  }

  Future<void> _addApp(String appName) async {
    if (!installedAppNames.any(
            (name) => name.toLowerCase() == appName.toLowerCase())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('App not found: $appName')));
      return;
    }
    try {
      final info = await platform.invokeMethod(
        'getSingleAppInfoByName',
        {'appName': appName},
      );
      final String name = info['name'] ?? '';
      final String packageName = info['package'] ?? '';
      final String iconBase64 = info['icon'] ?? '';
      setState(() {
        _apps.add({
          'name': name,
          'package': packageName,
          'icon': iconBase64,
        });
      });
      await _saveApps();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('App "$name" added!')));
    } on PlatformException catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add $appName')));
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      final success =
      await platform.invokeMethod('launchApp', {'packageName': packageName});
      if (!success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cannot launch $packageName')));
      }
    } on PlatformException catch (_) {}
  }

  Future<void> _deleteApp(String appName) async {
    setState(() {
      _apps.removeWhere((element) => element['name'] == appName);
    });
    await _saveApps();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$appName 삭제되었습니다.')));
  }

  void _showDeleteDialog(String appName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$appName 삭제하겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteApp(appName);
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  // build에 super.build(context) 호출 필요
  // (AutomaticKeepAliveClientMixin을 사용할 때 권장)
  @override
  Widget build(BuildContext context) {
    super.build(context); // 추가
    return Scaffold(
      appBar: AppBar(
        title: Text('App Launcher'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final app in fixedApps)
                  ListTile(
                    leading: Icon(Icons.android),
                    title: Text(app['name']!),
                    onTap: () => _launchApp(app['package']!),
                  ),
                Divider(),
                for (final app in _apps)
                  ListTile(
                    leading: _buildIcon(app['icon'] ?? ''),
                    title: Text(app['name'] ?? ''),
                    subtitle: Text(app['package'] ?? ''),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () =>
                          _showDeleteDialog(app['name'] ?? ''),
                    ),
                    onTap: (app['package'] ?? '').isNotEmpty
                        ? () => _launchApp(app['package']!)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('앱 추가하기'),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: '앱 이름 입력'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    nameController.clear();
                    Navigator.pop(context);
                    if (name.isNotEmpty) {
                      _addApp(name);
                    }
                  },
                  child: Text('추가'),
                ),
              ],
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildIcon(String base64Str) {
    try {
      final decoded = base64Decode(base64Str);
      return Image.memory(decoded, width: 40, height: 40, fit: BoxFit.cover);
    } catch (_) {
      return Icon(Icons.android);
    }
  }
}
