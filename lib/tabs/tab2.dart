import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tab2 extends StatefulWidget {
  final Map<String, dynamic> dict;
  final Map<String, Map<String, String>> defaultHanjas;

  const Tab2({
    super.key,
    required this.dict,
    required this.defaultHanjas,
  });

  @override
  _Tab2State createState() => _Tab2State();
}

class _Tab2State extends State<Tab2> with AutomaticKeepAliveClientMixin {
  static const platform = MethodChannel('com.example.hanja_magic/apps');
  final List<Map<String, String>> _apps = [];
  final TextEditingController nameController = TextEditingController();
  List<String> installedAppNames = [];
  List<HanjaEntry> _allHanjaEntries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // 1. dict.json 로드
    _loadHanjaDictionary().then((_) {
      // 2. 앱 목록 불러오기
      _fetchInstalledAppNames().then((_) {
        _loadApps().then((_) {
          setState(() => isLoading = false);
        });
      });
    });
  }

  // AutomaticKeepAliveClientMixin을 쓰려면 override 필수
  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchInstalledAppNames() async {
    try {
      final List<dynamic> names = await platform.invokeMethod('getInstalledAppNames');
      setState(() => installedAppNames = names.cast<String>());
    } on PlatformException catch (_) {}
  }

  Future<void> _loadHanjaDictionary() async {
    // rawData의 key = 한자, value = List<Map<String, String>>
    // 예: "刻": [{"kor":"각","def":"새길","spell":"새겨져라!"}], ...
    List<HanjaEntry> tempList = [];

    widget.dict.forEach((hanja, entries) {
      // entries: [{"kor":"각","def":"새길","spell":"새겨져라!"}, ... ]
      if (entries is List) {
        for (var e in entries) {
          if (e is Map<String, dynamic>) {
            final kor = e["kor"] ?? "";
            final def = e["def"] ?? "";
            final spell = e["spell"];
            tempList.add(
              HanjaEntry(
                hanja: hanja,
                spell: spell,
                kor: kor,
                def: def,
              ),
            );
          }
        }
      }
    });

    // 한자 전체 목록 저장
    setState(() => _allHanjaEntries = tempList);
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

  Future<void> _addApp(
    String appName,
    String hanja,
    String spell,
    String def,
    String kor,
    String extraData
  ) async {
    if (!installedAppNames.any(
      (name) => name.toLowerCase() == appName.toLowerCase())) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$appName을(를) 찾을 수 없습니다.')));
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
          'def': def,
          'kor': kor,
          'extraData': extraData,
        });
      });
      await _saveApps();
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name을(를) 추가했습니다.')));
    } on PlatformException catch (_) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$appName을(를) 추가하는 데 실패했습니다.')));
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
          .showSnackBar(SnackBar(content: Text('$packageName을(를) 실행하는 데 실패했습니다.')));
      }
    } on PlatformException catch (_) {}
  }

  void showAppSearchDialog(BuildContext context) async {
    // 설치된 앱 리스트 가져오기
    List<String> installedApps = installedAppNames;

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
          // 검색창 컨트롤러
          TextEditingController searchController = TextEditingController();

          // 한자/뜻/음/주문 컨트롤러
          TextEditingController combinedController = TextEditingController();
          TextEditingController spellController = TextEditingController();
          TextEditingController additiveController = TextEditingController();

          // 검색 결과용 임시 리스트
          List<HanjaEntry> filteredEntries = List.from(_allHanjaEntries);

          // 검색 로직: (def + kor)에서 공백 제거 후, 사용자가 입력한 검색어도 공백 제거 후 contains
          void filterHanja(String query, StateSetter setState) {
            final trimmedQuery = query.replaceAll(RegExp(r'\s+'), '');
            setState(() {
              filteredEntries = _allHanjaEntries.where((entry) {
                final combined = (entry.def + entry.kor).replaceAll(RegExp(r'\s+'), '');
                return combined.contains(trimmedQuery);
              }).toList();
            });
          }

          // 다이얼로그 표시
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Dialog(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 상단 검색 창
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: '한자 검색 (뜻+음)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              filterHanja(value, setState);
                            },
                          ),
                          const SizedBox(height: 10),

                          // 검색 결과 리스트
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredEntries.length,
                              itemBuilder: (context, index) {
                                final entry = filteredEntries[index];
                                return ListTile(
                                  title: Text(
                                    '${entry.hanja} ${entry.def} ${entry.kor}',
                                  ),
                                  onTap: () {
                                    // 한자/뜻/음/주문을 TextField에 세팅
                                    combinedController.text =
                                    '${entry.hanja} ${entry.def} ${entry.kor}';
                                    spellController.text = entry.spell ?? '';
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 선택된 한자/뜻/음 표시하는 TextField
                          TextField(
                            controller: combinedController,
                            decoration: InputDecoration(
                              labelText: '한자/뜻/음',
                              border: OutlineInputBorder(),
                            ),
                            enabled: false, // 수정 불가
                          ),
                          const SizedBox(height: 10),

                          // 주문(spell)만 수정 가능
                          TextField(
                            controller: spellController,
                            decoration: InputDecoration(
                              labelText: '주문',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 추가 데이터 입력 필드 (조건부 렌더링)
                          if (appName == "전화" || appName == "삼성 인터넷")
                            TextField(
                              controller: additiveController,
                              decoration: InputDecoration(
                                labelText: '전화번호 / URL',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          const SizedBox(height: 10),

                          // 저장 버튼
                          ElevatedButton(
                            onPressed: () {
                              // 한자/뜻/음 분리 처리
                              final combinedText = combinedController.text.trim();
                              final parts = combinedText.split(' ');

                              final selectedHanja = parts.isNotEmpty ? parts[0] : '';
                              final selectedDef = parts.length > 1 ? parts[1] : '';
                              final selectedKor = parts.length > 2 ? parts[2] : '';
                              final selectedSpell = spellController.text.trim();
                              final selectedAdditive = additiveController.text.trim();
                              
                              if (selectedHanja == "") {
                                return;
                              }

                              // 중복 확인
                              final isDuplicate = _apps.any((app) => app['hanja'] == selectedHanja);

                              if (isDuplicate || widget.defaultHanjas.containsKey(selectedHanja)) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: Text('중복 경고'),
                                      content: Text('이미 등록한 한자입니다.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text('확인'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                return;
                              }

                              Navigator.of(context).pop(); // 다이얼로그 닫기

                              // _addApp 호출(추가 데이터는 ""로)
                              _addApp(
                                appName,
                                selectedHanja,    // hanja
                                selectedSpell,    // spell
                                selectedDef,      // def
                                selectedKor,      // kor
                                selectedAdditive, // extraData
                              );
                            },
                            child: Text('저장'),
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

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 검색창
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: '검색',
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
                      child: Text('다음'),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => showAppSearchDialog(context),
              child: Stack(
                children: [
                  Text(
                    "加",
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'HanyangHaeseo',
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2 // Border thickness
                        ..color = Color(0xFFDB7890), // Border color
                    ),
                  ),
                  // Main text
                  Text(
                    "加",
                    style: const TextStyle(
                      fontSize: 30,
                      fontFamily: 'HanyangHaeseo',
                      color: Color(0xFFE392A3), // Text color
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _apps.length,
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    color: Colors.grey, // Divider color
                    thickness: 1.0,     // Divider thickness
                    indent: 16.0,       // Space from the start
                    endIndent: 16.0,    // Space from the end
                  );
                },
                itemBuilder: (BuildContext context, int index) {
                  return Dismissible(
                    key: ValueKey(_apps[index]['hanja']),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20.0),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) async {
                      final removedApp = _apps[index];
                      setState(() => _apps.removeAt(index));
                      await _saveApps();

                      // Snackbar with "Undo"
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${removedApp['name']}을(를) 제거했습니다.'),
                          action: SnackBarAction(
                            label: '실행 취소',
                            onPressed: () {
                              setState(() => _apps.insert(index, removedApp));
                              _saveApps();
                            },
                          ),
                        ),
                      );
                    },
                    child: CustomListTile(
                      hanja: _apps[index]['hanja'] ?? '',
                      spell: _apps[index]['spell'] ?? '',
                      def: _apps[index]['def'] ?? '',
                      kor: _apps[index]['kor'] ?? '',
                      icon: _buildIcon(_apps[index]['icon'] ?? ''),
                      onTap: (_apps[index]['package'] ?? '').isNotEmpty
                        ? () => _launchApp(
                          _apps[index]['package']!,
                          _apps[index]['extraData'],
                        )
                        : null,
                    ),
                  );
                }
              ),
            ),
          ],
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
  final String def;
  final String kor;
  final Widget icon;
  final VoidCallback? onTap;

  const CustomListTile({
    super.key,
    required this.hanja,
    required this.spell,
    required this.def,
    required this.kor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Stack(
            children: [
              Text(
                "$hanja ",
                style: TextStyle(
                  fontSize: 50,
                  fontFamily: 'HanyangHaeseo',
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2 // Border thickness
                    ..color = Color(0xFFDB7890), // Border color
                ),
              ),
              // Main text
              Text(
                "$hanja ",
                style: const TextStyle(
                  fontSize: 50,
                  fontFamily: 'HanyangHaeseo',
                  color: Color(0xFFE392A3), // Text color
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spell != "")
                  Text(
                    spell,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'YunGothic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      "$def ",
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'YunGothic',
                        color: Color(0xFF0177C4),
                      ),
                    ),
                    Text(
                      kor,
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'YunGothic',
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0177C4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: icon,
          ),
        ],
      ),
    );
  }
}

class HanjaEntry {
  final String hanja;   // "刻"
  final String? spell;  // "새겨져라!"
  final String def;     // "새길"
  final String kor;     // "각"

  HanjaEntry({
    required this.hanja,
    this.spell,
    required this.def,
    required this.kor,
  });
}
