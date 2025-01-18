import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';


class Tab2 extends StatefulWidget {
  const Tab2({super.key});

  @override
  _Tab2State createState() => _Tab2State();
}

class _Tab2State extends State<Tab2> {
  Map<String, dynamic> routines = {};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 카카오톡 실행 버튼
          _buildAppCard(
            context,
            icon: Icons.message,
            label: "Open KakaoTalk",
            onTap: () => _launchApp('com.kakao.talk'),
          ),
          // 카메라 실행 버튼
          _buildAppCard(
            context,
            icon: Icons.camera_alt,
            label: "Open Camera",
            onTap: () => _launchCamera(),
          ),
          // 갤러리 실행 버튼
          _buildAppCard(
            context,
            icon: Icons.photo,
            label: "Open Gallery",
            onTap: () => _launchApp('com.sec.android.gallery3d'),
          ),
          // 크롬 실행 버튼
          _buildAppCard(
            context,
            icon: Icons.web,
            label: "Open Chrome",
            onTap: () => _launchApp('com.android.chrome'),
          ),
          // 전화 앱 실행 버튼
          _buildAppCard(
            context,
            icon: Icons.phone,
            label: "Make a Call",
            onTap: () => _makeCall("tel:+8201086415372"),
          ),


          // Categories List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: routines.length + 1, // Extra card for the (+) button
            itemBuilder: (context, index) {
              // (+) Button Card
              if (index == routines.length) {
                return Card(
                  color: Color(0xFFF7F7F7),
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        // Add a new empty category with a unique name
                        setState(() {
                          int routineIndex = 1;
                          String newRoutineName;
                          do {
                            newRoutineName = "루틴 $routineIndex";
                            routineIndex++;
                          } while (routines.containsKey(newRoutineName));

                          routines[newRoutineName] = newRoutineName;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.add, size: 40.0, color: Color(0xFF18C971)
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Card(
                color: Color(0xFFF7F7F7),
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Text(routines.keys.elementAt(index)),
                  ],
                ),
              );
            },
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

  // 앱 실행 함수
  void _launchKakaoTalk() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.kakao.talk',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  void _launchGallery() async {
    const packageName = 'com.sec.android.gallery3d';
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: packageName,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  void _launchChrome() {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'com.android.chrome',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
  }

  void _launchApp(String packageName) {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: packageName,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    intent.launch();
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