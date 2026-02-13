import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'alerts_page.dart';
import 'settings_page.dart';
import 'notifications_page.dart';
import 'edit_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool notificationsEnabled = false;
  String userName = '...';

  // ✅ مهم عشان أول مرة يظهر Select location وبعدها يظهر المختار
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    // OFF by default أول مرة
    if (!prefs.containsKey('notificationsEnabled')) {
      await prefs.setBool('notificationsEnabled', false);
    }

    if (!mounted) return;
    setState(() {
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  // ================== دوال مساعدة للـ Forecasts ==================

  Color _colorForLevel(String level) {
    final l = level.toLowerCase();
    if (l == 'good') return Colors.green;
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
      final map = item as Map<String, dynamic>;

      final ts = map['time'] as Timestamp;
      final numVal = map['value'] as num;
      final value = numVal.toDouble();
      final level = (map['level'] ?? '').toString();

      return _Bar(
        value: value,
        color: _colorForLevel(level),
        label: _labelFromTimestamp(ts),
      );
    }).toList();
  }

  // ================== build ==================

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF32345F);
    final backgroundColor = const Color(0xFFF9F9FB);

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
              // -------- 1) الهيدر (الصورة + الاسم) + الموقع تحت بالنص ----------
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
                            // ✅ حتى الصورة نفسها تفتح البروفايل
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
                              child: StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .snapshots(),
                                builder: (context, snap) {
                                  final data = snap.data?.data();
                                  final photoUrl =
                                      (data?['photoUrl'] ?? '').toString().trim();

                                  ImageProvider avatarProvider;
                                  if (photoUrl.isNotEmpty) {
                                    avatarProvider = NetworkImage(photoUrl);
                                  } else {
                                    avatarProvider =
                                        const AssetImage('assets/avatar.png');
                                  }

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

                                  // اسم المستخدم
                                  StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Text(
                                          '...',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        );
                                      }

                                      if (!snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return Text(
                                          'User',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        );
                                      }

                                      final data = snapshot.data!.data();
                                      final name =
                                          (data?['name'] ?? 'User').toString().trim();

                                      return Text(
                                        name.isEmpty ? 'User' : name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),

                                  // ✅ الموقع تحت وفي النص زي الصورة
                                  const SizedBox(height: 8),
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

                                        // Dropdown من locations + حفظ locationId داخل users
                                        StreamBuilder<
                                            QuerySnapshot<Map<String, dynamic>>>(
                                          stream: FirebaseFirestore.instance
                                              .collection('locations')
                                              .where('isActive', isEqualTo: true)
                                              .snapshots(),
                                          builder: (context, locSnap) {
                                            if (!locSnap.hasData) {
                                              return Text(
                                                '...',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
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
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              );
                                            }

                                            return StreamBuilder<
                                                DocumentSnapshot<Map<String, dynamic>>>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .snapshots(),
                                              builder: (context, userSnap) {
                                                final userData =
                                                    userSnap.data?.data();
                                                final fromDb = (userData?['locationId'] ??
                                                        '')
                                                    .toString()
                                                    .trim();

                                                final String? nextId =
                                                    fromDb.isNotEmpty ? fromDb : null;

                                                // ✅ مزامنة محلية (عشان أول مرة يظهر Select location)
                                                if (nextId != _selectedLocationId) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((_) {
                                                    if (!mounted) return;
                                                    setState(() =>
                                                        _selectedLocationId = nextId);
                                                  });
                                                }

                                                return DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: _selectedLocationId,
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
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                      color: Colors.grey[800],
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    items: docs.map((d) {
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
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (newId) async {
                                                      if (newId == null) return;

                                                      setState(() =>
                                                          _selectedLocationId = newId);

                                                      await FirebaseFirestore.instance
                                                          .collection('users')
                                                          .doc(user.uid)
                                                          .set(
                                                        {
                                                          'locationId': newId,
                                                          'updatedAt': FieldValue
                                                              .serverTimestamp(),
                                                        },
                                                        SetOptions(merge: true),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
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

                  // أيقونات التنبيه والإعدادات
                  Row(
                    children: [
                      _HeaderIcon(
                        icon: Icons.notifications_none_rounded,
                        hasBadge: notificationsEnabled,
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final enabled =
                              prefs.getBool('notificationsEnabled') ?? false;

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

                          if (changed == true) {
                            _loadNotifications();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // -------- 2) كرت جودة الهواء الرئيسي ----------
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();

                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  final locationId = userData?['locationId'];

                  if (locationId == null) return const SizedBox();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('air_quality_data')
                        .doc(locationId)
                        .snapshots(),
                    builder: (context, aqSnap) {
                      if (!aqSnap.hasData || !aqSnap.data!.exists) {
                        return const SizedBox();
                      }

                      final data = aqSnap.data!.data() as Map<String, dynamic>;

                      final aqi = data['aqi'] ?? 0;
                      final mainPollutant = data['mainPollutant'] ?? '-';
                      final ts = data['updateTime'] as Timestamp?;
                      final formattedTime = ts != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                              ts.millisecondsSinceEpoch)
                          : null;

                      String updatedText = 'Updated: -';
                      if (formattedTime != null) {
                        int hour = formattedTime.hour;
                        final minute =
                            formattedTime.minute.toString().padLeft(2, '0');
                        final ampm = formattedTime.hour >= 12 ? 'PM' : 'AM';

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
                                    backgroundColor:
                                        const Color(0xFFF1F1F1),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFE9B35F),
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
                  );
                },
              ),

              const SizedBox(height: 30),

              // -------- 4) Metrological Data (لسه ثابتة) ----------
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
                  _MetCard(icon: Icons.compress, title: 'Pressure', value: '720 hpa'),
                  _MetCard(icon: Icons.thermostat, title: 'Temperatuer', value: '29°'),
                  _MetCard(icon: Icons.air, title: 'Wind speed', value: '12km/h'),
                  _MetCard(icon: Icons.water_drop_outlined, title: 'Humidity', value: '2,3'),
                ],
              ),

              const SizedBox(height: 30),

              // -------- 5) Air Pollutants Levels (ثابتة حالياً) ----------
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
                      value: '80.0',
                      status: 'Unhealthy',
                      color: Color(0xFFD65B66),
                    ),
                    _PollutantRow(
                      label: 'Particulate Matter 10',
                      value: '69.6',
                      status: 'Moderate',
                      color: Color(0xFFE9B35F),
                    ),
                    _PollutantRow(
                      label: 'Ozone (O3)',
                      value: '19.4',
                      status: 'Good',
                      color: Colors.green,
                    ),
                    _PollutantRow(
                      label: 'Carbon Monoxide(CO)',
                      value: '3.3',
                      status: 'Good',
                      color: Colors.green,
                    ),
                    _PollutantRow(
                      label: 'Sulfer Dioxide (SO2)',
                      value: '1.5',
                      status: 'Good',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // -------- 6) Forecasts (من Firestore) ----------
              const _SectionTitle(title: 'Forecasts', icon: Icons.show_chart),
              const SizedBox(height: 15),

              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox();
                  }

                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  final locationId = userData?['locationId'] as String?;

                  if (locationId == null) return const SizedBox();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('predictions')
                        .doc(locationId)
                        .snapshots(),
                    builder: (context, predSnap) {
                      if (!predSnap.hasData || !predSnap.data!.exists) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'No forecast data available.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final predData =
                          predSnap.data!.data() as Map<String, dynamic>;
                      final pm25List =
                          (predData['pm2.5Forecast'] as List<dynamic>?) ?? [];
                      final pm10List =
                          (predData['pm10Forecast'] as List<dynamic>?) ?? [];

                      final pm25Bars = _barsFromForecast(pm25List);
                      final pm10Bars = _barsFromForecast(pm10List);

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
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 30),

              Center(
                child: InkWell(
                  onTap: () {},
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
        ),
      ),
    );
  }

  Widget _buildChartBackground(List<Widget> bars) {
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
              children: bars,
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Helper Widgets ==================

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
          icon: Icon(
            icon,
            color: const Color(0xFF32345F),
            size: 26,
          ),
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
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B4B4B),
              ),
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
  const _Bar({
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final double scaledHeight = (value / 80) * 110;
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
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}