import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart';
import 'package:timezone_calculator/common.dart';
import 'package:timezone_calculator/components/timezone_card.dart';
import 'package:timezone_calculator/constants.dart';
import 'package:timezone_calculator/pages/timezone_selector_page.dart';
import 'package:timezone_calculator/types/timezone_card_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tz.initializeTimeZones();
  runApp(const MyApp());
}

const appName = "Timezone calculator";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late SharedPreferences prefs;

  late TimeOfDay selectedTime;
  late tz.TZDateTime pointOfReference;
  late tz.Location selectedLocation;

  List<TimezoneCardData> otherTimezones = List.empty(growable: true);

  @override
  void initState() {
    super.initState();
    selectedLocation = tz.getLocation("UTC");
    otherTimezones.add(TimezoneCardData('Asia/Tbilisi'));

    selectedTime = TimeOfDay.now();
    pointOfReference = TZDateTime.now(selectedLocation);
  }

  Future<void> loadValues() async {
    prefs = await SharedPreferences.getInstance();

    final String? loadedLocation = prefs.getString(selectedLocationKey);
    final String? loadedOtherTimezones = prefs.getString(otherTimezonesKey);

    if (loadedLocation != null) {
      selectedLocation = tz.getLocation(loadedLocation);
      if (kDebugMode) {
        print("Set $selectedLocationKey to $loadedLocation");
      }
    }

    if (loadedOtherTimezones != null) {
      final decodedList = jsonDecode(loadedOtherTimezones) as List<dynamic>;
      otherTimezones = decodedList
          .map((e) => TimezoneCardData.fromJson(e as Map<String, dynamic>))
          .toList();
      if (kDebugMode) {
        print("Set $otherTimezonesKey");
      }
    }
  }

  List<Widget> _buildOtherZonesWidgets() {
    List<Widget> widgets = List.empty(growable: true);
    widgets.add(const Text('Other timezones'));
    for (var tzData in otherTimezones) {
      widgets.add(
          TimezoneCard(pointOfReference: pointOfReference, cardData: tzData));
    }
    widgets.add(ElevatedButton.icon(
      onPressed: () async {
        final location = await _selectLocation();
        if (location != null) {
          setState(() {
            otherTimezones.add(TimezoneCardData(location.name));
            prefs.setString(otherTimezonesKey, jsonEncode(otherTimezones));
          });
        }
      },
      label: const Text("Add timezone"),
      icon: const Icon(Icons.add),
    ));
    return widgets;
  }

  Future<Location?> _selectLocation() async {
    return await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return const TimezoneSelectorPage();
    }));
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        initialEntryMode: TimePickerEntryMode.dial,
        helpText: "Select a point of reference time");

    if (pickedTime != null && pickedTime != selectedTime) {
      setState(() {
        selectedTime = pickedTime;
        DateTime now = DateTime.now();
        pointOfReference = TZDateTime.from(
            DateTime(now.year, now.month, now.day, pickedTime.hour,
                pickedTime.minute),
            selectedLocation);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(appName),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.settings))
          ],
        ),
        body: FutureBuilder(
          future: loadValues(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ListView(
                scrollDirection: Axis.vertical,
                children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _selectTime(context),
                                child: Text(
                                  timeFormat24.format(pointOfReference),
                                  style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  final location = await _selectLocation();
                                  if (location != null) {
                                    setState(() {
                                      DateTime now = DateTime.now();
                                      selectedLocation = location;
                                      prefs.setString(
                                          selectedLocationKey, location.name);
                                      setLocalLocation(location);
                                      pointOfReference = TZDateTime.from(
                                          DateTime(
                                              now.year,
                                              now.month,
                                              now.day,
                                              selectedTime.hour,
                                              selectedTime.minute),
                                          selectedLocation);
                                    });
                                  }
                                },
                                child: Text(getTzAbbreviationWithHours(
                                    selectedLocation)),
                              ),
                            ],
                          ),
                          Text(selectedLocation.name),
                        ],
                      )),
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: _buildOtherZonesWidgets(),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ));
  }
}
