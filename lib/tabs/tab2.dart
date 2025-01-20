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

  Future<void> _addApp(String appName, String hanja, String spell, String meaning, String reading, String additivedata) async {
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
          'hanja': hanja,
          'spell': spell,
          'meaning': meaning,
          'reading': reading,
          'data': additivedata,
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

  void showAppSearchDialog(BuildContext context) async {
    // 설치된 앱 리스트 가져오기
    List<String> installedApps = await installedAppNames;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<String> filteredApps = List.from(installedApps); // 초기 상태

        TextEditingController searchController = TextEditingController();

        void filterApps(String query, StateSetter setState) {
          setState(() {
            filteredApps = installedApps
                .where((app) => app.toLowerCase().contains(query.toLowerCase()))
                .toList();
          });
        }

        // 두 번째 단계 - 한자 고르기
        void showHanjaDialog(String appName) {
          TextEditingController hanjaController = TextEditingController();
          TextEditingController meaningController = TextEditingController();
          TextEditingController readingController = TextEditingController();
          TextEditingController spellController = TextEditingController();

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add details for $appName',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: hanjaController,
                        decoration: InputDecoration(
                          labelText: 'Enter Hanja',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: meaningController,
                        decoration: InputDecoration(
                          labelText: 'Enter Meaning',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: readingController,
                        decoration: InputDecoration(
                          labelText: 'Enter Reading',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: spellController,
                        decoration: InputDecoration(
                          labelText: 'Enter Spell',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close Hanja Dialog
                          _addApp(
                            appName,
                            hanjaController.text,
                            spellController.text,
                            meaningController.text,
                            readingController.text,
                            "",
                          );
                        },
                        child: Text('Save Details'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 검색창
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search App',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        filterApps(value, setState);
                      },
                    ),
                    SizedBox(height: 10),
                    // 필터링된 목록 표시
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(filteredApps[index]),
                            onTap: () {
                              searchController.text = filteredApps[index];
                              filterApps(filteredApps[index], setState);
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    // 추가 버튼
                    ElevatedButton(
                      onPressed: () {
                        final name = searchController.text.trim();
                        searchController.clear();
                        if (name.isNotEmpty) {
                          Navigator.pop(context);
                          showHanjaDialog(name);
                        }
                      },
                      child: Text('Next'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // build에 super.build(context) 호출 필요
  // (AutomaticKeepAliveClientMixin을 사용할 때 권장)
  @override
  Widget build(BuildContext context) {
    super.build(context); // 추가
    return Scaffold(
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
                  CustomListTile(
                    hanja: app['hanja'] ?? '',
                    spell: app['spell'] ?? '',
                    meaning: app['meaning'] ?? '',
                    reading: app['reading'] ?? '',
                    icon1: _buildIcon(app['icon'] ?? ''),
                    icon2: Icon(Icons.delete),
                    onTap: (app['package'] ?? '').isNotEmpty
                        ? () => _launchApp(app['package']!)
                        : null,
                    onDelete: () => _showDeleteDialog(app['name'] ?? ''),
                  )
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {

          showAppSearchDialog(context);

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

class CustomListTile extends StatelessWidget {
  final String hanja;
  final String spell;
  final String meaning;
  final String reading;
  final Widget icon1;
  final Widget icon2;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  CustomListTile({
    required this.hanja,
    required this.spell,
    required this.meaning,
    required this.reading,
    required this.icon1,
    required this.icon2,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Leading
            Text(hanja, style: TextStyle(fontSize: 30)),

            // Title1, Title2, Title3 in Column
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spell, style: TextStyle(fontSize: 24)),
                  Text(meaning, style: TextStyle(fontSize: 26)),
                  Text(reading, style: TextStyle(fontSize: 26)),
                ],
              ),
            ),

            // Trailing Icons
            Row(
              children: [
                icon1,
                SizedBox(width: 8.0),
                IconButton(
                  icon: icon2,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


