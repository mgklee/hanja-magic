import 'package:flutter/material.dart';

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
}