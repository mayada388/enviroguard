import 'package:flutter/material.dart';
import 'notifications_page.dart';

//  Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//  Admin Edit Profile Page
import 'admin_profile_page.dart';

import 'report_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final Color primaryColor = const Color(0xFF32345F);
  final Color backgroundColor = const Color(0xFFF9F9FB);

  ///  عشان أول مرة يظهر Select location وبعدها يظهر المختار
  String? _selectedLocationId; // null => Select location

  Future<void> _saveLocationId(User user, String locationId) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'locationId': locationId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProfilePage()),
    );
  }

  //  دوال Forecasts

  Color _colorForLevel(String level) {
    final l = level.toLowerCase();
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

      final ts = map['time'];
      final numVal = map['value'];
      final level = (map['status'] ?? '').toString();

      final value = (numVal is num) ? numVal.toDouble() : 0.0;
      final time = ts is Timestamp ? ts : null;
      return _Bar(
        value: value,
        color: _colorForLevel(level),
        label: time != null ? _labelFromTimestamp(time) : '--',
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

  //  Placeholders (بدون بيانات قبل اختيار الموقع)

  Widget _buildPlaceholders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Air Quality placeholder =====
        Container(
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
        ),

        const SizedBox(height: 30),

        //  Metrological
        const _SectionTitle(
          title: 'Metrological Data',
          icon: Icons.cloud_outlined,
        ),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.5,
          children: const [
            _MetCard(icon: Icons.compress, title: 'Pressure', value: '--'),
            _MetCard(icon: Icons.thermostat, title: 'Temperatuer', value: '--'),
            _MetCard(icon: Icons.air, title: 'Wind speed', value: '--'),
            _MetCard(
              icon: Icons.water_drop_outlined,
              title: 'Humidity',
              value: '--',
            ),
          ],
        ),

        const SizedBox(height: 30),

        //  Pollutants
        const _SectionTitle(
          title: 'Air Pollutants Levels',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              _PollutantRow(
                label: 'Particulate Matter 2.5',
                value: '--',
                status: '—',
                color: Color(0xFFB0BEC5),
              ),
              _PollutantRow(
                label: 'Particulate Matter 10',
                value: '--',
                status: '—',
                color: Color(0xFFB0BEC5),
              ),

              _PollutantRow(
                label: 'Carbon Dioxide (CO₂)',
                value: '--',
                status: '—',
                color: Color(0xFFB0BEC5),
              ),

              _PollutantRow(
                label: 'Nitrogen Dioxide (NO₂)',
                value: '--',
                status: '—',
                color: Color(0xFFB0BEC5),
              ),

              _PollutantRow(
                label: 'Ozone (O₃)',
                value: '--',
                status: '—',
                color: Color(0xFFB0BEC5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        //  Forecasts placeholder
        const _SectionTitle(title: 'Forecasts', icon: Icons.show_chart),
        const SizedBox(height: 15),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _buildChartBackground(
                List.generate(
                  6,
                  (i) => const _Bar(
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _buildChartBackground(
                List.generate(
                  6,
                  (i) => const _Bar(
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
                'Carbon Dioxide (CO₂)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _buildChartBackground(
                List.generate(
                  6,
                  (i) => const _Bar(
                    value: 0,
                    color: Color(0xFFB0BEC5),
                    label: '--',
                  ),
                ),
              ),
              const Text(
                'Nitrogen Dioxide (NO₂)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                'Ozone (O₃)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        ),

        const SizedBox(height: 30),

        // Download placeholder
        //  Download (PDF)
        Center(
          child: InkWell(
            onTap: () async {
              final id = _selectedLocationId;

              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a location first'),
                  ),
                );
                return;
              }

              final locDoc = await FirebaseFirestore.instance
                  .collection('locations')
                  .doc(id)
                  .get();

              final locationName = (locDoc.data()?['name'] ?? id).toString();

              await ReportService.downloadAirQualityReport(
                locationId: id,
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
    );
  }

  //  build

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================== HEADER  ==================
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data();

                  // ===== Name =====
                  final fromDbName = (userData?['name'] ?? '')
                      .toString()
                      .trim();
                  final fallbackName =
                      (user.displayName?.trim().isNotEmpty ?? false)
                      ? user.displayName!.trim()
                      : 'Admin';
                  final nameToShow = fromDbName.isNotEmpty
                      ? fromDbName
                      : fallbackName;

                  // ===== Photo =====
                  final photoUrl = (userData?['photoUrl'] ?? '')
                      .toString()
                      .trim();
                  final ImageProvider avatarProvider = photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : const AssetImage('assets/avatar.png');

                  // ===== locationId from users =====
                  final fromDbLocId = (userData?['locationId'] ?? '')
                      .toString()
                      .trim();
                  final String? nextId = fromDbLocId.isNotEmpty
                      ? fromDbLocId
                      : null;

                  // مزامنة محلية
                  if (nextId != _selectedLocationId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedLocationId = nextId);
                    });
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _openEditProfile,
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: avatarProvider,
                        ),
                      ),
                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openEditProfile,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      nameToShow,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),

                                StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: FirebaseFirestore.instance
                                      .collection('locations')
                                      .where('isActive', isEqualTo: true)
                                      .snapshots(),
                                  builder: (context, locSnap) {
                                    if (!locSnap.hasData) {
                                      return Text(
                                        '...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      );
                                    }

                                    final locDocs = locSnap.data!.docs;

                                    if (locDocs.isEmpty) {
                                      return Text(
                                        'No locations',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      );
                                    }

                                    final String? safeValue =
                                        (_selectedLocationId != null &&
                                            locDocs.any(
                                              (d) =>
                                                  d.id == _selectedLocationId,
                                            ))
                                        ? _selectedLocationId
                                        : null;

                                    // Responsive dropdown
                                    return Flexible(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 180,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: safeValue,
                                            isDense: true,
                                            isExpanded: true,
                                            icon: const Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 16,
                                            ),
                                            hint: Text(
                                              'Select location',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            items: locDocs.map((d) {
                                              final data = d.data();
                                              final name =
                                                  (data['name'] ?? d.id)
                                                      .toString();
                                              return DropdownMenuItem<String>(
                                                value: d.id,
                                                child: Text(
                                                  name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (newId) async {
                                              if (newId == null) return;

                                              setState(
                                                () =>
                                                    _selectedLocationId = newId,
                                              );
                                              await _saveLocationId(
                                                user,
                                                newId,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Row(
                        children: [
                          _HeaderIcon(
                            icon: Icons.notifications_none_rounded,
                            hasBadge: true,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 25),

              //  لو ما اختار موقع: اعرض نفس الأقسام لكن بدون بيانات
              if (_selectedLocationId == null) ...[
                _buildPlaceholders(),
              ] else ...[
                //  Air Quality Card (من Firestore)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('air_quality_data')
                      .doc(_selectedLocationId)
                      .snapshots(),
                  builder: (context, aqSnap) {
                    if (!aqSnap.hasData || aqSnap.data?.data() == null) {
                      // لو ما فيه بيانات لهذا الموقع، اعرض placeholder بدل ما تختفي الصفحة
                      return _buildPlaceholders();
                    }

                    final data = aqSnap.data!.data()!;
                    final pol = data['pollutants'];
                    final aqi = (data['aqi'] ?? 0);
                    final mainPollutant = (data['mainPollutant'] ?? '-')
                        .toString();
                    String mainStatus = 'Unknown';

                    if (pol != null && pol[mainPollutant] != null) {
                      final mainData = pol[mainPollutant];
                      mainStatus = (mainData['status'] ?? 'Unknown').toString();
                    }
                    final mainColor = _colorForLevel(mainStatus);

                    final ts = data['updateTime'] as Timestamp?;
                    String updatedText = 'Updated: -';
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
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
                                      value: (aqi / 150).clamp(0, 1).toDouble(),
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
                        ),

                        const SizedBox(height: 30),

                        //  Metrological Data (ثابتة )
                        const _SectionTitle(
                          title: 'Metrological Data',
                          icon: Icons.cloud_outlined,
                        ),
                        const SizedBox(height: 15),
                        GridView.count(
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
                              value: '${data['Pressure'] ?? '--'} hPa',
                            ),
                            _MetCard(
                              icon: Icons.thermostat,
                              title: 'Temperature',
                              value: '${data['Temperature'] ?? '--'}°',
                            ),
                            _MetCard(
                              icon: Icons.air,
                              title: 'Wind speed',
                              value: '${data['wind_speed'] ?? '--'} km/h',
                            ),
                            _MetCard(
                              icon: Icons.water_drop_outlined,
                              title: 'Humidity',
                              value: '${data['Humidity'] ?? '--'}%',
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        //  Air Pollutants Levels (ثابتة)
                        const _SectionTitle(
                          title: 'Air Pollutants Levels',
                          icon: Icons.bar_chart_rounded,
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _PollutantRow(
                                label: 'Particulate Matter 2.5',
                                value: (pol?['PM2_5']?['value'] ?? 0)
                                    .toString(),
                                status: (pol?['PM2_5']?['status'] ?? '--')
                                    .toString(),
                                color: _colorForLevel(
                                  (pol?['PM2_5']?['status'] ?? '').toString(),
                                ),
                              ),

                              _PollutantRow(
                                label: 'Particulate Matter 10',
                                value: (pol?['PM10']?['value'] ?? 0).toString(),
                                status: (pol?['PM10']?['status'] ?? '--')
                                    .toString(),
                                color: _colorForLevel(
                                  (pol?['PM10']?['status'] ?? '').toString(),
                                ),
                              ),

                              _PollutantRow(
                                label: 'Carbon Dioxide (CO₂)',
                                value: (pol?['CO2']?['value'] ?? 0).toString(),
                                status: (pol?['CO2']?['status'] ?? '--')
                                    .toString(),
                                color: _colorForLevel(
                                  (pol?['CO2']?['status'] ?? '').toString(),
                                ),
                              ),

                              _PollutantRow(
                                label: 'Nitrogen Dioxide (NO₂)',
                                value: (pol?['NO2']?['value'] ?? 0).toString(),
                                status: (pol?['NO2']?['status'] ?? '--')
                                    .toString(),
                                color: _colorForLevel(
                                  (pol?['NO2']?['status'] ?? '').toString(),
                                ),
                              ),

                              _PollutantRow(
                                label: 'Ozone (O₃)',
                                value: (pol?['O3']?['value'] ?? 0).toString(),
                                status: (pol?['O3']?['status'] ?? '--')
                                    .toString(),
                                color: _colorForLevel(
                                  (pol?['O3']?['status'] ?? '').toString(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        //   Forecasts (من Firestore)
                        const _SectionTitle(
                          title: 'Forecasts',
                          icon: Icons.show_chart,
                        ),
                        const SizedBox(height: 15),

                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('predictions')
                              .doc(_selectedLocationId)
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
                                child: const Center(
                                  child: Text(
                                    'No forecast data available.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final predData = predSnap.data!.data()!;

                            // ===== PM2.5 =====
                            List<dynamic> _safeList(dynamic data) {
                              if (data is List) return data;
                              if (data is Map) return [data];
                              return [];
                            }

                            final pm25List = _safeList(
                              predData['PM2_5Forecast'],
                            );
                            final pm10List = _safeList(
                              predData['PM10Forecast'],
                            );
                            final co2List = _safeList(predData['CO2Forecast']);
                            final no2List = _safeList(predData['NO2Forecast']);
                            final o3List = _safeList(predData['O3Forecast']);

                            final pm25Bars = _barsFromForecast(pm25List);
                            final pm10Bars = _barsFromForecast(pm10List);
                            final co2Bars = _barsFromForecast(co2List);
                            final no2Bars = _barsFromForecast(no2List);
                            final o3Bars = _barsFromForecast(o3List);

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
                                    'Carbon Dioxide (CO₂)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildChartBackground(co2Bars),

                                  const SizedBox(height: 20),
                                  const Text(
                                    'Nitrogen Dioxide (NO₂)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildChartBackground(no2Bars),

                                  const SizedBox(height: 20),
                                  const Text(
                                    'Ozone (O₃)',
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
                              if (_selectedLocationId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a location first',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // يجيب الموقع
                              final locDoc = await FirebaseFirestore.instance
                                  .collection('locations')
                                  .doc(_selectedLocationId)
                                  .get();

                              final locationName =
                                  (locDoc.data()?['name'] ??
                                          _selectedLocationId)
                                      .toString();

                              await ReportService.downloadAirQualityReport(
                                locationId: _selectedLocationId!,
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
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

//  Widgets Helper

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
