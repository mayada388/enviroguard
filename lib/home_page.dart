import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'alerts_page.dart';
import 'settings_page.dart';
import 'notifications_page.dart';
import 'edit_profile_page.dart';

import 'report_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool notificationsEnabled = false;

  //  أول مرة يظهر Select location وبعدها يظهر المختار
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('notificationsEnabled')) {
      await prefs.setBool('notificationsEnabled', false);
    }
    if (!mounted) return;
    setState(() {
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  //  Helpers (Colors/Forecast Bars)
  Color _colorForLevel(String level) {
    final l = level.toLowerCase().trim();

    if (l == 'healthy') return Colors.green;
    if (l == 'moderate') return const Color(0xFFE9B35F);
    if (l == 'unhealthy') return const Color(0xFFD65B66);

    return const Color(0xFFB0BEC5);
  }

  String _labelFromTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    int hour = dt.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour $ampm';
  }

  List<_Bar> _barsFromForecast(List<dynamic> forecast) {
    return forecast.map((item) {
      if (item is! Map<String, dynamic>) {
        return const _Bar(value: 0, color: Color(0xFFB0BEC5), label: '--');
      }

      final map = item;

      final tsRaw = map['time'];

      // إذا الوقت ناقص رجّع بار فاضي بدل ما ينهار التطبيق
      if (tsRaw == null) {
        return const _Bar(value: 0, color: Color(0xFFB0BEC5), label: '--');
      }

      final ts = tsRaw as Timestamp?;
      if (ts == null) {
        return const _Bar(value: 0, color: Color(0xFFB0BEC5), label: '--');
      }
      final numVal = map['value'];
      final value = (numVal is num) ? numVal.toDouble() : 0.0;

      final level = (map['status'] ?? '').toString();

      return _Bar(
        value: value,
        color: _colorForLevel(level),
        label: _labelFromTimestamp(ts),
      );
    }).toList();
  }

  Widget _buildChartBackground(List<Widget> bars) {
    double maxValue = 0;

    for (var bar in bars) {
      if (bar is _Bar) {
        if (bar.value > maxValue) {
          maxValue = bar.value;
        }
      }
    }
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (index) => Row(
                children: [
                  SizedBox(
                    width: 25,
                    child: Text(
                      '${80 - (index * 20)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                  const Expanded(
                    child: Divider(height: 1, color: Color(0xFFF1F1F1)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                if (bar is _Bar) {
                  return _Bar(
                    value: bar.value,
                    color: bar.color,
                    label: bar.label,
                    maxValue: maxValue,
                  );
                }
                return bar;
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  //  Placeholder values (بدون موقع)
  Widget _placeholderAirQualityCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Air Quality',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE9B35F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Main Pollutant: --\nUpdated: --',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: 0,
                  strokeWidth: 10,
                  backgroundColor: Color(0xFFF1F1F1),
                  valueColor: AlwaysStoppedAnimation(Color(0xFFE9B35F)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '--',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    'AQI',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // build

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF32345F);
    final backgroundColor = const Color(0xFFF9F9FB);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    //  نقرأ user doc مرة واحدة فقط
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data();
            final fromDbLocId = (userData?['locationId'] ?? '')
                .toString()
                .trim();
            final String? locationId = fromDbLocId.isNotEmpty
                ? fromDbLocId
                : null;

            // مزامنة محلية للـ dropdown
            if (locationId != _selectedLocationId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _selectedLocationId = locationId);
              });
            }

            //  stream لبيانات الموقع (إذا فيه locationId)
            final Stream<DocumentSnapshot<Map<String, dynamic>>>? aqStream =
                (locationId == null)
                ? null
                : FirebaseFirestore.instance
                      .collection('air_quality_data')
                      .doc(locationId)
                      .snapshots();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //  HEADER + Dropdown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfilePage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(50),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfilePage(),
                                      ),
                                    );
                                  },
                                  child:
                                      StreamBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>
                                      >(
                                        stream: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .snapshots(),
                                        builder: (context, snap) {
                                          final data = snap.data?.data();
                                          final photoUrl =
                                              (data?['photoUrl'] ?? '')
                                                  .toString()
                                                  .trim();
                                          final ImageProvider avatarProvider =
                                              photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : const AssetImage(
                                                  'assets/avatar.png',
                                                );
                                          return CircleAvatar(
                                            radius: 25,
                                            backgroundImage: avatarProvider,
                                          );
                                        },
                                      ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Good evening!',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ((userData?['name'] ?? 'User')
                                                .toString()
                                                .trim()
                                                .isEmpty)
                                            ? 'User'
                                            : (userData?['name'] ?? 'User')
                                                  .toString()
                                                  .trim(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // Dropdown locations
                                      Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            StreamBuilder<
                                              QuerySnapshot<
                                                Map<String, dynamic>
                                              >
                                            >(
                                              stream: FirebaseFirestore.instance
                                                  .collection('locations')
                                                  .where(
                                                    'isActive',
                                                    isEqualTo: true,
                                                  )
                                                  .snapshots(),
                                              builder: (context, locSnap) {
                                                if (!locSnap.hasData) {
                                                  return Text(
                                                    '...',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  );
                                                }
                                                final docs = locSnap.data!.docs;
                                                if (docs.isEmpty) {
                                                  return Text(
                                                    'No locations',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  );
                                                }

                                                final String? safeValue =
                                                    (_selectedLocationId !=
                                                            null &&
                                                        docs.any(
                                                          (d) =>
                                                              d.id ==
                                                              _selectedLocationId,
                                                        ))
                                                    ? _selectedLocationId
                                                    : null;

                                                return DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: safeValue,
                                                    isDense: true,
                                                    icon: const Icon(
                                                      Icons.keyboard_arrow_down,
                                                      size: 18,
                                                    ),
                                                    hint: Text(
                                                      'Select location',
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                      color: Colors.grey[800],
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    items: docs.map((d) {
                                                      final data = d.data();
                                                      final name =
                                                          (data['name'] ?? d.id)
                                                              .toString();
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: d.id,
                                                        child: Text(
                                                          name,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (newId) async {
                                                      if (newId == null) return;
                                                      setState(
                                                        () =>
                                                            _selectedLocationId =
                                                                newId,
                                                      );

                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(user.uid)
                                                          .set(
                                                            {
                                                              'locationId':
                                                                  newId,
                                                              'updatedAt':
                                                                  FieldValue.serverTimestamp(),
                                                            },
                                                            SetOptions(
                                                              merge: true,
                                                            ),
                                                          );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Icons
                      Row(
                        children: [
                          _HeaderIcon(
                            icon: Icons.notifications_none_rounded,
                            hasBadge: notificationsEnabled,
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final enabled =
                                  prefs.getBool('notificationsEnabled') ??
                                  false;

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => enabled
                                      ? const NotificationsPage()
                                      : const AlertsPage(),
                                ),
                              );

                              _loadNotifications();
                            },
                          ),
                          _HeaderIcon(
                            icon: Icons.settings_outlined,
                            onPressed: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                              if (changed == true) _loadNotifications();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  //  Air Quality Card (Firestore OR --)
                  if (aqStream == null)
                    _placeholderAirQualityCard(primaryColor)
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: aqStream,
                      builder: (context, aqSnap) {
                        if (!aqSnap.hasData || aqSnap.data?.data() == null) {
                          // حتى لو ما جت بيانات، نخلي الشكل موجود
                          return _placeholderAirQualityCard(primaryColor);
                        }

                        final data = aqSnap.data!.data()!;
                        final aqiRaw = data['aqi'] ?? 0;
                        final aqi = (aqiRaw is num)
                            ? aqiRaw.toDouble()
                            : double.tryParse(aqiRaw.toString()) ?? 0;

                        final mainPollutant = (data['mainPollutant'] ?? '--')
                            .toString();
                        final pollutants =
                            data['pollutants'] as Map<String, dynamic>?;

                        String mainStatus = 'Unknown';

                        if (pollutants != null &&
                            pollutants[mainPollutant] != null) {
                          final mainData =
                              pollutants[mainPollutant] as Map<String, dynamic>;
                          mainStatus = (mainData['status'] ?? 'Unknown')
                              .toString();
                        }
                        final mainColor = _colorForLevel(mainStatus);
                        final ts = data['updateTime'] as Timestamp?;
                        String updatedText = 'Updated: --';
                        if (ts != null) {
                          final dt = ts.toDate();
                          int hour = dt.hour;
                          final minute = dt.minute.toString().padLeft(2, '0');
                          final ampm = hour >= 12 ? 'PM' : 'AM';
                          if (hour == 0) {
                            hour = 12;
                          } else if (hour > 12) {
                            hour -= 12;
                          }
                          updatedText = 'Updated: $hour:$minute $ampm';
                        }

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mainStatus,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: mainColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'AQI: ${aqi.toInt()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Main Pollutant: $mainPollutant\n$updatedText',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),

                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 85,
                                    height: 85,
                                    child: CircularProgressIndicator(
                                      value: (aqi / 150).clamp(0, 1),
                                      strokeWidth: 10,
                                      backgroundColor: const Color(0xFFF1F1F1),
                                      valueColor: AlwaysStoppedAnimation(
                                        mainColor,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$aqi',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                      Text(
                                        'AQI',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 30),

                  //  Metrological Data (Firestore OR --)
                  const _SectionTitle(
                    title: 'Metrological Data',
                    icon: Icons.cloud_outlined,
                  ),
                  const SizedBox(height: 15),

                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: aqStream,
                    builder: (context, metSnap) {
                      final data = metSnap.data?.data();

                      String pressure = '--';
                      String temp = '--';
                      String wind = '--';
                      String humidity = '--';

                      if (data != null) {
                        if (data['Pressure'] != null)
                          pressure = '${data['Pressure']} hPa';
                        if (data['Temperature'] != null)
                          temp = '${data['Temperature']}°';
                        if (data['wind_speed'] != null)
                          wind = '${data['wind_speed']} km/h';
                        if (data['Humidity'] != null)
                          humidity = '${data['Humidity']}%';
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 1.5,
                        children: [
                          _MetCard(
                            icon: Icons.compress,
                            title: 'Pressure',
                            value: pressure,
                          ),
                          _MetCard(
                            icon: Icons.thermostat,
                            title: 'Temperature',
                            value: temp,
                          ),
                          _MetCard(
                            icon: Icons.air,
                            title: 'Wind speed',
                            value: wind,
                          ),
                          _MetCard(
                            icon: Icons.water_drop_outlined,
                            title: 'Humidity',
                            value: humidity,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  //  Air Pollutants Levels (Firestore OR --)
                  const _SectionTitle(
                    title: 'Air Pollutants Levels',
                    icon: Icons.bar_chart_rounded,
                  ),
                  const SizedBox(height: 15),

                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: aqStream,
                    builder: (context, polSnap) {
                      final pol =
                          polSnap.data?.data()?['pollutants']
                              as Map<String, dynamic>?;

                      // defaults
                      String vPm25 = '--', sPm25 = '--';
                      Color cPm25 = const Color(0xFFB0BEC5);
                      String vPm10 = '--', sPm10 = '--';
                      Color cPm10 = const Color(0xFFB0BEC5);
                      String vCO2 = '--', sCO2 = '--';
                      Color cCO2 = const Color(0xFFB0BEC5);
                      String vNO2 = '--', sNO2 = '--';
                      Color cNO2 = const Color(0xFFB0BEC5);
                      String vO3 = '--', sO3 = '--';
                      Color cO3 = const Color(0xFFB0BEC5);

                      Map<String, dynamic>? _asMap(dynamic x) =>
                          (x is Map<String, dynamic>) ? x : null;

                      if (pol != null) {
                        final pm25 = _asMap(pol['PM2_5']);
                        final pm10 = _asMap(pol['PM10']);
                        final co2 = _asMap(pol['CO2']);
                        final no2 = _asMap(pol['NO2']);
                        final o3 = _asMap(pol['O3']);

                        if (pm25 != null) {
                          vPm25 = (pm25['value'] ?? '--').toString();
                          sPm25 = (pm25['status'] ?? '--').toString();
                          cPm25 = _colorForLevel(sPm25);
                        }
                        if (pm10 != null) {
                          vPm10 = (pm10['value'] ?? '--').toString();
                          sPm10 = (pm10['status'] ?? '--').toString();
                          cPm10 = _colorForLevel(sPm10);
                        }
                        if (co2 != null) {
                          vCO2 = (co2['value'] ?? '--').toString();
                          sCO2 = (co2['status'] ?? '--').toString();
                          cCO2 = _colorForLevel(sCO2);
                        }
                        if (no2 != null) {
                          vNO2 = (no2['value'] ?? '--').toString();
                          sNO2 = (no2['status'] ?? '--').toString();
                          cNO2 = _colorForLevel(sNO2);
                        }

                        if (o3 != null) {
                          vO3 = (o3['value'] ?? '--').toString();
                          sO3 = (o3['status'] ?? '--').toString();
                          cO3 = _colorForLevel(sO3);
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _PollutantRow(
                              label: 'Particulate Matter 2.5',
                              value: vPm25,
                              status: sPm25,
                              color: cPm25,
                            ),
                            _PollutantRow(
                              label: 'Particulate Matter 10',
                              value: vPm10,
                              status: sPm10,
                              color: cPm10,
                            ),
                            _PollutantRow(
                              label: 'Carbon Dioxide (CO2)',
                              value: vCO2,
                              status: sCO2,
                              color: cCO2,
                            ),
                            _PollutantRow(
                              label: 'Nitrogen Dioxide (NO2)',
                              value: vNO2,
                              status: sNO2,
                              color: cNO2,
                            ),
                            _PollutantRow(
                              label: 'Ozone (O3)',
                              value: vO3,
                              status: sO3,
                              color: cO3,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  //  Forecasts (Firestore OR Placeholder)
                  const _SectionTitle(
                    title: 'Forecasts',
                    icon: Icons.show_chart,
                  ),
                  const SizedBox(height: 15),

                  if (locationId == null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Particulate Matter 2.5',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildChartBackground(
                            List.generate(
                              6,
                              (_) => const _Bar(
                                value: 0,
                                color: Color(0xFFB0BEC5),
                                label: '--',
                              ),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(color: Color(0xFFF1F1F1)),
                          ),

                          const Text(
                            'Particulate Matter 10',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildChartBackground(
                            List.generate(
                              6,
                              (_) => const _Bar(
                                value: 0,
                                color: Color(0xFFB0BEC5),
                                label: '--',
                              ),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(color: Color(0xFFF1F1F1)),
                          ),

                          const Text(
                            'Carbon Dioxide (CO2)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildChartBackground(
                            List.generate(
                              6,
                              (_) => const _Bar(
                                value: 0,
                                color: Color(0xFFB0BEC5),
                                label: '--',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('predictions')
                          .doc(locationId)
                          .snapshots(),
                      builder: (context, predSnap) {
                        if (!predSnap.hasData ||
                            predSnap.data?.data() == null) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Particulate Matter 2.5',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildChartBackground(
                                  List.generate(
                                    6,
                                    (_) => const _Bar(
                                      value: 0,
                                      color: Color(0xFFB0BEC5),
                                      label: '--',
                                    ),
                                  ),
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(color: Color(0xFFF1F1F1)),
                                ),

                                const Text(
                                  'Particulate Matter 10',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildChartBackground(
                                  List.generate(
                                    6,
                                    (_) => const _Bar(
                                      value: 0,
                                      color: Color(0xFFB0BEC5),
                                      label: '--',
                                    ),
                                  ),
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(color: Color(0xFFF1F1F1)),
                                ),

                                const Text(
                                  'Carbon Dioxide (CO2)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildChartBackground(
                                  List.generate(
                                    6,
                                    (_) => const _Bar(
                                      value: 0,
                                      color: Color(0xFFB0BEC5),
                                      label: '--',
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Nitrogen Dioxide (NO2)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildChartBackground(
                                  List.generate(
                                    6,
                                    (_) => const _Bar(
                                      value: 0,
                                      color: Color(0xFFB0BEC5),
                                      label: '--',
                                    ),
                                  ),
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(color: Color(0xFFF1F1F1)),
                                ),

                                const Text(
                                  'Ozone (O3)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildChartBackground(
                                  List.generate(
                                    6,
                                    (_) => const _Bar(
                                      value: 0,
                                      color: Color(0xFFB0BEC5),
                                      label: '--',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final predData = predSnap.data!.data()!;

                        List<dynamic> _safeList(dynamic data) {
                          if (data is List) return data;
                          if (data is Map)
                            return [data]; // يحوله ليست فيها عنصر واحد
                          return [];
                        }

                        final pm25List = _safeList(predData['PM2_5Forecast']);
                        final pm10List = _safeList(predData['PM10Forecast']);
                        final co2List = _safeList(predData['CO2Forecast']);
                        final no2List = _safeList(predData['NO2Forecast']);
                        final o3List = _safeList(predData['O3Forecast']);

                        final pm25Bars = pm25List.isEmpty
                            ? List.generate(
                                6,
                                (_) => const _Bar(
                                  value: 0,
                                  color: Color(0xFFB0BEC5),
                                  label: '--',
                                ),
                              )
                            : _barsFromForecast(pm25List);

                        final pm10Bars = pm10List.isEmpty
                            ? List.generate(
                                6,
                                (_) => const _Bar(
                                  value: 0,
                                  color: Color(0xFFB0BEC5),
                                  label: '--',
                                ),
                              )
                            : _barsFromForecast(pm10List);

                        final co2Bars = co2List.isEmpty
                            ? List.generate(
                                6,
                                (_) => const _Bar(
                                  value: 0,
                                  color: Color(0xFFB0BEC5),
                                  label: '--',
                                ),
                              )
                            : _barsFromForecast(co2List);

                        final no2Bars = no2List.isEmpty
                            ? List.generate(
                                6,
                                (_) => const _Bar(
                                  value: 0,
                                  color: Color(0xFFB0BEC5),
                                  label: '--',
                                ),
                              )
                            : _barsFromForecast(no2List);

                        final o3Bars = o3List.isEmpty
                            ? List.generate(
                                6,
                                (_) => const _Bar(
                                  value: 0,
                                  color: Color(0xFFB0BEC5),
                                  label: '--',
                                ),
                              )
                            : _barsFromForecast(o3List);

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Particulate Matter 2.5',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildChartBackground(pm25Bars),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Color(0xFFF1F1F1)),
                              ),

                              const Text(
                                'Particulate Matter 10',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildChartBackground(pm10Bars),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Color(0xFFF1F1F1)),
                              ),

                              const Text(
                                'Carbon Dioxide (CO2)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildChartBackground(co2Bars),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Color(0xFFF1F1F1)),
                              ),

                              const Text(
                                'Nitrogen Dioxide (NO2)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildChartBackground(no2Bars),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Color(0xFFF1F1F1)),
                              ),

                              const Text(
                                'Ozone (O3)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildChartBackground(o3Bars),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 30),

                  Center(
                    child: InkWell(
                      onTap: () async {
                        final locationId = _selectedLocationId;
                        if (locationId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a location first'),
                            ),
                          );
                          return;
                        }

                        final locDoc = await FirebaseFirestore.instance
                            .collection('locations')
                            .doc(locationId)
                            .get();

                        final locationName =
                            (locDoc.data()?['name'] ?? locationId).toString();

                        await ReportService.downloadAirQualityReport(
                          locationId: locationId,
                          locationName: locationName,
                          context: context,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            color: primaryColor.withOpacity(0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Download Air Quality Report',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

//  Helper Widgets

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool hasBadge;
  const _HeaderIcon({
    required this.icon,
    required this.onPressed,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: const Color(0xFF32345F), size: 26),
        ),
        if (hasBadge)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF32345F)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF32345F),
          ),
        ),
      ],
    );
  }
}

class _MetCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _MetCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF1F1F1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 24),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollutantRow extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final Color color;
  const _PollutantRow({
    required this.label,
    required this.value,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B4B4B)),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  final String label;
  final double maxValue;

  const _Bar({
    required this.value,
    required this.color,
    required this.label,
    this.maxValue = 100,
  });

  @override
  Widget build(BuildContext context) {
    final double scaledHeight = maxValue == 0
        ? 0
        : ((value / maxValue) * 110).clamp(0, 110);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 14,
          height: scaledHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
