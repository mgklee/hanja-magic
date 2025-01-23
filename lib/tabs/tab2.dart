import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styled_hanja.dart';

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

class _Tab2State extends State<Tab2> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const _platform = MethodChannel('com.example.hanja_magic/apps');
  final List<Map<String, String>> _apps = [];
  List<String> _installedAppNames = [];
  List<HanjaEntry> _allHanjaEntries = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isAnimationComplete = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 데이터 로드
    _loadHanjaDictionary().then((_) {
      _fetchInstalledAppNames().then((_) {
        _loadApps().then((_) {
          // 최소 1초 애니메이션이 완료된 후 로딩 상태를 업데이트
          if (_isAnimationComplete) {
            setState(() => _isLoading = false);
          } else {
            Future.delayed(const Duration(milliseconds: 700), () {
              setState(() => _isLoading = false);
            });
          }
        });
      });
    });

    // AnimationController 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // ScaleAnimation 정의
    _scaleAnimation = Tween<double>(begin: 0.5, end: 4.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 로딩 시작과 동시에 애니메이션 실행
    _animationController.forward();
  }

  // AutomaticKeepAliveClientMixin을 쓰려면 override 필수
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstalledAppNames() async {
    try {
      final List<dynamic> names = await _platform.invokeMethod('getInstalledAppNames');
      setState(() => _installedAppNames = names.cast<String>());
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
    if (!_installedAppNames.any(
      (name) => name.toLowerCase() == appName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$appName을(를) 찾을 수 없습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    try {
      final info = await _platform.invokeMethod(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name을(를) 추가했습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } on PlatformException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$appName을(를) 추가하는 데 실패했습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _launchApp(String packageName, String? extraData) async {
    try {
      final success = await _platform.invokeMethod(
        'launchApp',
        {'packageName': packageName, 'extraData': extraData ?? "",}
      );
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$packageName을(를) 실행하는 데 실패했습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } on PlatformException catch (_) {}
  }

  void showAppSearchDialog(BuildContext context) async {
    // 설치된 앱 리스트 가져오기
    List<String> installedApps = _installedAppNames;

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
          TextEditingController extraController = TextEditingController();

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
              String? selectedHanja;
              String? selectedDef;
              String? selectedKor;

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
                            cursorColor: Color(0xFFDB7890),
                            decoration: InputDecoration(
                              labelText: '한자 검색 (뜻+음)',
                              labelStyle: TextStyle(color: Color(0xFFDB7890)),
                              floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                              border: OutlineInputBorder(), // Default border
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                              ),
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
                                final isRegistered = (
                                  _apps.any((app) => app['hanja'] == entry.hanja) ||
                                  widget.defaultHanjas.containsKey(entry.hanja)
                                );
                                return ListTile(
                                  title: Text(
                                    '${entry.hanja} ${entry.def} ${entry.kor}',
                                    style: TextStyle(
                                      color: isRegistered ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                  onTap: () {
                                    if (!isRegistered) {
                                      // 한자/뜻/음/주문을 TextField에 세팅
                                      combinedController.text = '${entry.hanja} ${entry.def} ${entry.kor}';
                                      spellController.text = entry.spell ?? '';
                                      selectedHanja = entry.hanja;
                                      selectedDef = entry.def;
                                      selectedKor = entry.kor;
                                    }
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
                            cursorColor: Color(0xFFDB7890),
                            decoration: InputDecoration(
                              labelText: '주문',
                              labelStyle: TextStyle(color: Color(0xFFDB7890)),
                              floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                              border: OutlineInputBorder(), // Default border
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 추가 데이터 입력 필드 (조건부 렌더링)
                          if (appName == "전화" || appName == "삼성 인터넷") ...[
                            TextField(
                              controller: extraController,
                              cursorColor: Color(0xFFDB7890),
                              decoration: InputDecoration(
                                labelText: '전화번호 / URL',
                                labelStyle: TextStyle(color: Color(0xFFDB7890)),
                                floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                                border: OutlineInputBorder(), // Default border
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          // 저장 버튼
                          GestureDetector(
                            onTap: () {
                              // 한자/뜻/음 분리 처리
                              final selectedSpell = spellController.text.trim();
                              final selectedExtra = extraController.text.trim();
                              
                              if (selectedHanja == "" || widget.defaultHanjas.containsKey(selectedHanja)) {
                                return;
                              }

                              // _addApp 호출(추가 데이터는 ""로)
                              _addApp(
                                appName,
                                selectedHanja!,
                                selectedSpell,
                                selectedDef!,
                                selectedKor!,
                                selectedExtra,
                              );
                              Navigator.of(context).pop(); // 다이얼로그 닫기
                            },
                            child: StyledHanja(text: "完"),
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
                      cursorColor: Color(0xFFDB7890),
                      decoration: InputDecoration(
                        labelText: '검색',
                        labelStyle: TextStyle(color: Color(0xFFDB7890)),
                        floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                        border: OutlineInputBorder(), // Default border
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                        ),
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
                    GestureDetector(
                      onTap: () {
                        final name = searchController.text.trim();
                        searchController.clear();
                        if (name.isNotEmpty) {
                          Navigator.pop(context);
                          showHanjaDialog(name);
                        }
                      },
                      child: StyledHanja(text: "入"),
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

  void showEditDialog(int index) {
    final app = _apps[index];
      // 검색창 컨트롤러
    TextEditingController searchController = TextEditingController();

    // 한자/뜻/음/주문 컨트롤러
    TextEditingController combinedController = TextEditingController(text: '${app['hanja']} ${app['def']} ${app['kor']}');
    TextEditingController spellController = TextEditingController(text: app['spell']);
    TextEditingController extraController = TextEditingController(text: app['extraData']);

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
        String? selectedHanja = app['hanja'];
        String? selectedDef = app['def'];
        String? selectedKor = app['kor'];

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
                      cursorColor: Color(0xFFDB7890),
                      decoration: InputDecoration(
                        labelText: '한자 검색 (뜻+음)',
                        labelStyle: TextStyle(color: Color(0xFFDB7890)),
                        floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                        border: OutlineInputBorder(), // Default border
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                        ),
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
                          final isRegistered = (
                            _apps.any((app) => app['hanja'] == entry.hanja) ||
                            widget.defaultHanjas.containsKey(entry.hanja)
                          );
                          return ListTile(
                            title: Text(
                              '${entry.hanja} ${entry.def} ${entry.kor}',
                              style: TextStyle(
                                color: isRegistered ? Colors.grey : Colors.black,
                              ),
                            ),
                            onTap: () {
                              if (!isRegistered) {
                                // 한자/뜻/음/주문을 TextField에 세팅
                                combinedController.text = '${entry.hanja} ${entry.def} ${entry.kor}';
                                spellController.text = entry.spell ?? '';
                                selectedHanja = entry.hanja;
                                selectedDef = entry.def;
                                selectedKor = entry.kor;
                              }
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
                      cursorColor: Color(0xFFDB7890),
                      decoration: InputDecoration(
                        labelText: '주문',
                        labelStyle: TextStyle(color: Color(0xFFDB7890)),
                        floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                        border: OutlineInputBorder(), // Default border
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 추가 데이터 입력 필드 (조건부 렌더링)
                    if (app['name'] == "전화" || app['name'] == "삼성 인터넷") ...[
                      TextField(
                        controller: extraController,
                        cursorColor: Color(0xFFDB7890),
                        decoration: InputDecoration(
                          labelText: '전화번호 / URL',
                          labelStyle: TextStyle(color: Color(0xFFDB7890)),
                          floatingLabelStyle: TextStyle(color: Color(0xFFDB7890)),
                          border: OutlineInputBorder(), // Default border
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB7890)), // Color when enabled
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB7890), width: 2.0), // Color when focused
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GestureDetector(
                      onTap: () {
                        // 한자/뜻/음 분리 처리
                        final selectedSpell = spellController.text.trim();
                        final selectedExtra = extraController.text.trim();

                        Map<String, String> newAppData = {
                          'name': app['name']!,
                          'package': app['package']!,
                          'icon': app['icon']!,
                          'hanja': selectedHanja!,
                          'spell': selectedSpell,
                          'def': selectedDef!,
                          'kor': selectedKor!,
                          'extraData': selectedExtra,
                        };
                        
                        updateAppEntry(index, newAppData);
                        Navigator.of(context).pop(); // 다이얼로그 닫기
                      },
                      child: StyledHanja(text: "完"),
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

  void updateAppEntry(int index, Map<String, String> newAppData) {
    setState(() => _apps[index] = newAppData);
    _saveApps();
  }

  // build에 super.build(context) 호출 필요
  // (AutomaticKeepAliveClientMixin을 사용할 때 권장)
  @override
  Widget build(BuildContext context) {
    super.build(context); // 추가
    return Scaffold(
      appBar: _isLoading
      ? null
      : AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => showAppSearchDialog(context),
              child: StyledHanja(text: "加"),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Stack(
          children: [
            Container(
              color: Colors.white,
            ),
            // 집중선 이미지
            Positioned.fill(
              child: Opacity(
                opacity: 0.8, // 투명도 조정
                child: Image.asset(
                  'assets/focus.jpg',
                  fit: BoxFit.cover, // 화면 전체에 이미지 채우기
                ),
              ),
            ),
            // 애니메이션 이미지
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/chunjamoon.png',
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                ),
              ),
            ),
          ],
        )
        : Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _apps.length,
                separatorBuilder: (BuildContext context, int index) {
                  return Image.asset(
                    'assets/yeo.png',
                    width: 600,
                  );
                },
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                    onTap: () => showEditDialog(index),
                    child: Dismissible(
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
                            duration: Duration(seconds: 2),
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
          StyledHanja(
            text: "$hanja ",
            fontSize: 50,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Baseline(
                    baseline: 20.0,
                    baselineType: TextBaseline.alphabetic,
                      child: Text(
                        "$def ",
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'YunGothic',
                          color: Color(0xFF0177C4),
                        ),
                      ),
                    ),
                    Baseline(
                    baseline: 20.0,
                    baselineType: TextBaseline.alphabetic,
                      child: Text(
                        kor,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'YunGothic',
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0177C4),
                        ),
                      ),
                    )
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
