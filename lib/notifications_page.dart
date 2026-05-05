import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isGenerating = false;
  StreamSubscription? _airSubscription;
  StreamSubscription? _predictionSubscription;
  Timer? _debounce;

  static const List<String> pollutantIds = ['PM2_5', 'PM10', 'CO', 'NO2', 'O3'];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAlertsForAllUsers();
      _listenForDatabaseChanges();
    });
  }

  void _listenForDatabaseChanges() {
    _airSubscription = FirebaseFirestore.instance
        .collection('air_quality_data')
        .snapshots()
        .listen((_) {
          _runGeneratorWithDelay();
        });

    _predictionSubscription = FirebaseFirestore.instance
        .collection('predictions')
        .snapshots()
        .listen((_) {
          _runGeneratorWithDelay();
        });
  }

  void _runGeneratorWithDelay() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _generateAlertsForAllUsers();
    });
  }

  @override
  void dispose() {
    _airSubscription?.cancel();
    _predictionSubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _generateAlertsForAllUsers() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);
    try {
      final firestore = FirebaseFirestore.instance; // مرجع Firestore

      final usersSnap = await firestore
          .collection('users')
          .get(); // قراءة كل المستخدمين

      if (usersSnap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No users found.')));
        return;
      }

      final Map<String, Map<String, dynamic>> thresholdsByLocation = {};

      for (final u in usersSnap.docs) {
        final locationId = (u.data()['locationId'] ?? '').toString().trim();
        if (locationId.isEmpty) continue;

        if (thresholdsByLocation.containsKey(locationId)) continue;

        final thDoc = await firestore
            .collection('thresholds')
            .doc(locationId)
            .get();
        final th = thDoc.data();

        if (th != null) thresholdsByLocation[locationId] = th;
      }

      // 3) كاش للـ templates (عشان ما نقرأها لكل alert)
      final Map<String, Map<String, dynamic>> templateCache = {};
      Future<Map<String, dynamic>> getTemplate(String pid, String level) async {
        final docId = '${pid}_${level.toLowerCase()}';
        if (templateCache.containsKey(docId)) return templateCache[docId]!;
        final doc = await firestore
            .collection('alert_templates')
            .doc(docId)
            .get();
        final data = doc.data() ?? <String, dynamic>{};
        templateCache[docId] = data;
        return data;
      }

      // 4) كاش لبيانات الهواء لكل Location
      final Map<String, Map<String, dynamic>?> airCache = {};
      final batch = firestore.batch();

      int created = 0;
      int skippedSameLevel = 0;
      int skippedNoLocation = 0;
      int skippedNoAirDoc = 0;

      // 6) نمشي على كل يوزر
      for (final u in usersSnap.docs) {
        final userUid = u.id;
        final uData = u.data();
        final locationId = (uData['locationId'] ?? '').toString();
        final personalAlerts = uData['personalAirAlerts'];
        final hasPersonalPreferences =
            personalAlerts is Map && personalAlerts.isNotEmpty;
        final notificationsEnabled =
            uData['notificationsEnabled'] == true ||
            uData['notificationEnabled'] == true ||
            uData['alertsEnabled'] == true;

        if (!notificationsEnabled) {
          continue;
        }

        // ================== Quiet Hours ==================

        final qh = uData['quietHours'];
        if (qh is Map) {
          final enabled = (qh['enabled'] == true);

          // start: {hour: x, minute: y}
          final quietStart = _readTime(qh['start']);
          final quietEnd = _readTime(qh['end']);

          TimeOfDay? readTime(dynamic m) {
            if (m is Map) {
              final h = m['hour'];
              final min = m['minute'];
              final hour = (h is int) ? h : int.tryParse('$h');
              final minute = (min is int) ? min : int.tryParse('$min');
              if (hour != null && minute != null) {
                return TimeOfDay(hour: hour, minute: minute);
              }
            }
            return null;
          }

          bool isNowInQuietHours(TimeOfDay start, TimeOfDay end) {
            final now = TimeOfDay.fromDateTime(DateTime.now());
            int toMin(TimeOfDay t) => t.hour * 60 + t.minute;

            final nowM = toMin(now);
            final startM = toMin(start);
            final endM = toMin(end);

            if (startM > endM) {
              return nowM >= startM || nowM <= endM;
            }
            return nowM >= startM && nowM <= endM;
          }

          if (enabled && quietStart != null && quietEnd != null) {
            final now = TimeOfDay.fromDateTime(DateTime.now());

            int toMin(TimeOfDay t) => t.hour * 60 + t.minute;

            final nowM = toMin(now);
            final startM = toMin(quietStart);
            final endM = toMin(quietEnd);

            bool inQuiet;

            if (startM > endM) {
              inQuiet = nowM >= startM || nowM <= endM;
            } else {
              inQuiet = nowM >= startM && nowM <= endM;
            }

            if (inQuiet) {
              continue;
            }
          }
        }
        // ================== End Quiet Hours ==================

        if (locationId.isEmpty) {
          skippedNoLocation++;
          continue;
        }

        Map<String, dynamic>? air;
        if (airCache.containsKey(locationId)) {
          air = airCache[locationId]; // رجع من الكاش
        } else {
          final airDoc = await firestore
              .collection('air_quality_data')
              .doc(locationId)
              .get(); // air_quality_data/{locationId}
          air = airDoc.data(); // بيانات الهواء
          airCache[locationId] = air; // خزّن بالكاش
        }

        if (air == null) {
          skippedNoAirDoc++;
          continue;
        }

        final Map<String, dynamic> alertState = (uData['alertState'] is Map)
            ? Map<String, dynamic>.from(uData['alertState'])
            : {}; // alertState كامل

        final Map<String, dynamic> locState = (alertState[locationId] is Map)
            ? Map<String, dynamic>.from(alertState[locationId])
            : {}; // alertState الخاص باللوكيشن

        for (final pid in pollutantIds) {
          bool wantsThisPollutant = true;

          if (hasPersonalPreferences && personalAlerts is Map) {
            wantsThisPollutant = personalAlerts[pid] == true;
          }

          if (!wantsThisPollutant) {
            continue;
          } // ================== Prediction Alerts ==================
          if (wantsThisPollutant) {
            final predictionsDoc = await firestore
                .collection('predictions')
                .doc(locationId)
                .get();

            final predictions = predictionsDoc.data();

            String forecastField = '${pid}Forecast';

            final forecastArr = predictions?[forecastField];

            final firstUnhealthy = _getFirstUnhealthy(forecastArr);

            if (firstUnhealthy != null) {
              final fValue = _toDouble(firstUnhealthy['value']);
              final fTime = firstUnhealthy['time']?.toString();

              final Map<String, dynamic> pidState =
                  (locState['prediction_$pid'] is Map)
                  ? Map<String, dynamic>.from(locState['prediction_$pid'])
                  : {};

              final lastValue = pidState['value'];
              final lastTime = pidState['time'];

              if (fValue != lastValue || fTime != lastTime) {
                final docId = '${pid}_prediction_unhealthy';

                final tplDoc = await firestore
                    .collection('alert_templates')
                    .doc(docId)
                    .get();

                final tplData = tplDoc.data() ?? {};

                final title =
                    (tplData['title'] ??
                            '${_displayPollutant(pid)} Unhealthy Soon')
                        .toString();

                final message =
                    (tplData['message'] ??
                            '${_displayPollutant(pid)} will reach unhealthy levels soon.')
                        .toString();

                final alertRef = firestore.collection('alerts').doc();

                batch.set(alertRef, {
                  'userUid': userUid,
                  'locationId': locationId,
                  'pollutantId': pid,
                  'pollutantType': _displayPollutant(pid),
                  'value': fValue,
                  'alertLevel': 'Unhealthy',
                  'title': title,
                  'message': message,
                  'timestamp': Timestamp.now(),
                  'isPrediction': true,
                });

                final userRef = firestore.collection('users').doc(userUid);

                batch.set(userRef, {
                  'alertState': {
                    locationId: {
                      ...locState,
                      'prediction_$pid': {
                        'value': fValue,
                        'time': fTime,
                        'lastSentAt': FieldValue.serverTimestamp(),
                      },
                    },
                  },
                }, SetOptions(merge: true));

                created++;
              }
            }
          }

          final pollutants = air['pollutants'];

          if (pollutants is! Map || pollutants[pid] == null) continue;

          final pollutantData = pollutants[pid];

          if (pollutantData is! Map) continue;

          final value = _toDouble(pollutantData['value']);
          if (value == null) continue;

          final th = thresholdsByLocation[locationId]?[pid];
          if (th == null || th is! Map) continue;

          final level = _computeLevel(value, Map<String, dynamic>.from(th));
          if (level == null) continue;

          final Map<String, dynamic> pidState = (locState[pid] is Map)
              ? Map<String, dynamic>.from(locState[pid])
              : {};

          final lastLevel = (pidState['level'] ?? '').toString();

          if (lastLevel.toLowerCase() == level.toLowerCase()) {
            skippedSameLevel++;
            continue;
          }

          // ================== template ==================

          final docId = '${pid}_${level.toLowerCase()}';

          final tpl1 = await FirebaseFirestore.instance
              .collection('alert_templates')
              .doc(docId)
              .get();

          final tplData = tpl1.data() ?? {};
          print('TEMPLATE DATA: $tplData');

          final title = (tplData['title'] ?? '${_displayPollutant(pid)} $level')
              .toString();

          final message =
              (tplData['message'] ??
                      '${_displayPollutant(pid)} levels are $level.')
                  .toString();

          final alertRef = firestore.collection('alerts').doc();
          batch.set(alertRef, {
            'userUid': userUid,
            'locationId': locationId,
            'pollutantId': pid,
            'pollutantType': _displayPollutant(pid),
            'value': value, // القيمة الحالية
            'alertLevel': level, // Moderate / Unhealthy
            'title': title, // عنوان من template
            'message': message,
            'timestamp': Timestamp.now(),
          });
          final userRef = firestore.collection('users').doc(userUid);
          // حدّث alertState عند اليوزر (عشان منع التكرار المرة الجاية)
          batch.set(userRef, {
            'alertState': {
              locationId: {
                ...locState,
                pid: {
                  'level': level,
                  'lastSentAt': FieldValue.serverTimestamp(),
                  'value': value,
                },
              },
            },
          }, SetOptions(merge: true));

          created++;
        }
      }

      await batch.commit();

      //  رسالة نجاح

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Done | Created: $created | SameLevelSkipped: $skippedSameLevel | NoLocation: $skippedNoLocation | NoAirDoc: $skippedNoAirDoc',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  TimeOfDay? _readTime(dynamic v) {
    if (v is String && v.contains(':')) {
      final parts = v.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  // حساب مستوى التنبيه بناء على thresholds (max_safe / max_moderate)
  String? _computeLevel(double value, Map<String, dynamic> th) {
    final maxSafe = _toDouble(th['max_safe']); // الحد الآمن
    final maxModerate = _toDouble(th['max_moderate']); // حد Moderate
    if (maxSafe == null || maxModerate == null) return null;

    if (value > maxModerate) return 'Unhealthy'; // أعلى من moderate = Unhealthy
    if (value > maxSafe) return 'Moderate'; // أعلى من safe = Moderate
    return null;
  }

  Map<String, dynamic>? _getFirstUnhealthy(dynamic forecastData) {
    if (forecastData == null) return null;

    if (forecastData is Map) {
      final status = (forecastData['status'] ?? '').toString().toLowerCase();
      if (status == 'unhealthy') {
        return Map<String, dynamic>.from(forecastData);
      }
    }

    if (forecastData is List) {
      for (final item in forecastData) {
        if (item is Map) {
          final status = (item['status'] ?? '').toString().toLowerCase();
          if (status == 'unhealthy') {
            return Map<String, dynamic>.from(item);
          }
        }
      }
    }

    return null;
  }

  String _displayPollutant(String pid) {
    switch (pid) {
      case 'PM2_5':
        return 'PM2.5';
      case 'PM10':
        return 'PM10';
      case 'CO':
        return 'CO';
      case 'NO2':
        return 'NO₂';
      case 'O3':
        return 'O₃';
      default:
        return pid;
    }
  }

  // تنسيق الوقت (6:01 AM)
  String _formatTime(Timestamp ts) {
    final dt = ts.toDate(); // تحويل لتاريخ
    int hour = dt.hour; // الساعة
    final minute = dt.minute.toString().padLeft(2, '0'); // الدقيقة
    final ampm = hour >= 12 ? 'PM' : 'AM'; // AM/PM
    hour = hour % 12; // نظام 12 ساعة
    if (hour == 0) hour = 12; // 0 تتحول 12
    return '$hour:$minute $ampm';
  }

  // تقسيم الأقسام Today/Yesterday/This week
  String _groupLabel(DateTime dt) {
    final now = DateTime.now(); // الآن
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    ); // تاريخ اليوم بدون وقت
    final d = DateTime(dt.year, dt.month, dt.day); // تاريخ العنصر بدون وقت
    final diff = today.difference(d).inDays; // الفرق بالأيام

    if (diff == 0) return 'Today'; // اليوم
    if (diff == 1) return 'Yesterday'; // أمس
    return 'This week';
  }

  // ألوان حسب مستوى التنبيه
  ({Color statusColor, Color indicatorColor, Color titleColor}) _levelColors(
    String level,
  ) {
    final l = level.toLowerCase(); // lower case للمقارنة

    if (l.contains('unhealthy') ||
        l.contains('hazard') ||
        l.contains('danger')) {
      return (
        statusColor: const Color(0xFFF2A7AD), // خلفية البادج
        indicatorColor: const Color(0xFFD65B66), // لون الشريط + النص
        titleColor: const Color(0xFFD65B66), // لون العنوان
      );
    }

    if (l.contains('moderate')) {
      return (
        statusColor: const Color(0xFFFDE9C9),
        indicatorColor: const Color(0xFFE9B35F),
        titleColor: const Color(0xFFE9B35F),
      );
    }

    return (
      statusColor: const Color(0xFFE7EEF8),
      indicatorColor: const Color(0xFF3B3E66),
      titleColor: const Color(0xFF3B3E66),
    );
  }

  // فلتر: عرض فقط آخر 7 أيام
  bool _isWithinLast7Days(Timestamp ts) {
    final dt = ts.toDate(); // تاريخ التنبيه
    final now = DateTime.now();
    return now.difference(dt).inDays < 7; // أقل من 7 أيام
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid; // اليوزر الحالي

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // خلفية زي الصورة
      appBar: AppBar(
        backgroundColor: Colors.transparent, // شفاف
        elevation: 0, // بدون ظل
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF32345F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications', // عنوان
          style: TextStyle(
            color: Color(0xFF32345F),
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),

      body: uid == null
          ? const Center(
              child: Text(
                'Please login first.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alerts') // alerts collection
                  .where('userUid', isEqualTo: uid) // تنبيهات هذا اليوزر
                  .orderBy('timestamp', descending: true) // الأحدث أول
                  .limit(200) // نجيب أكثر لأننا بنفلتر 7 أيام
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  ); // تحميل
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                final docs = <QueryDocumentSnapshot>[];
                for (final d in allDocs) {
                  final data = d.data() as Map<String, dynamic>; // data
                  final ts = data['timestamp']; // timestamp
                  if (ts is! Timestamp) continue;
                  if (!_isWithinLast7Days(ts)) continue;
                  docs.add(d);
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // تجميع الأقسام Today/Yesterday/This week
                final Map<String, List<QueryDocumentSnapshot>> grouped =
                    {}; // grouped map
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>; // data
                  final ts = data['timestamp'] as Timestamp; // timestamp
                  final label = _groupLabel(ts.toDate());
                  grouped.putIfAbsent(label, () => []);
                  grouped[label]!.add(d);
                }

                // ترتيب الأقسام
                final sectionOrder = ['Today', 'Yesterday', 'This week'];
                final sections = <String>[
                  for (final s in sectionOrder)
                    if (grouped.containsKey(s) && grouped[s]!.isNotEmpty) s,
                ];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  itemCount: sections.length, // عدد الأقسام
                  itemBuilder: (context, index) {
                    final section = sections[index]; // اسم القسم
                    final items = grouped[section] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // محاذاة
                      children: [
                        _SectionHeader(title: section), // عنوان القسم
                        const SizedBox(height: 8), // مسافة
                        ...items.map((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>; // data

                          final pollutant = (data['pollutantType'] ?? '-')
                              .toString(); // اسم ملوث للعرض
                          final message = (data['message'] ?? '')
                              .toString(); // رسالة
                          final level = (data['alertLevel'] ?? '')
                              .toString(); // مستوى
                          final value = (data['value'] ?? '')
                              .toString(); // قيمة
                          final ts =
                              data['timestamp'] as Timestamp; // timestamp

                          final colors = _levelColors(
                            level,
                          ); // ألوان حسب المستوى

                          final titleText =
                              (data['title'] ?? '').toString().trim().isNotEmpty
                              ? (data['title'] ?? '').toString()
                              : (value.isNotEmpty
                                    ? '$pollutant • $value'
                                    : pollutant);

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 14,
                            ), // مسافة بين الكروت
                            child: _NotificationCard(
                              title: titleText, // العنوان
                              subtitle: message.isEmpty ? '—' : message, // النص
                              status: level.isEmpty ? 'Alert' : level, // البادج
                              statusColor: colors.statusColor, // لون البادج
                              indicatorColor:
                                  colors.indicatorColor, // لون الشريط
                              titleColor: colors.titleColor, // لون العنوان
                              time: _formatTime(ts), // الوقت
                              onDelete: () async {
                                await FirebaseFirestore.instance
                                    .collection('alerts')
                                    .doc(doc.id)
                                    .delete();
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

// Widget عنوان القسم (Today/Yesterday/This week)
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title}); // constructor

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15, // حجم
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title; // العنوان
  final String subtitle; // النص
  final String status; // مستوى التنبيه
  final Color statusColor; // لون خلفية البادج
  final Color indicatorColor; // لون الشريط + نص البادج
  final Color titleColor; // لون العنوان
  final String time; // وقت
  final Future<void> Function() onDelete;

  const _NotificationCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.indicatorColor,
    required this.titleColor,
    required this.time,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18), // زوايا
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // ظل خفيف
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // محاذاة أعلى
        children: [
          Container(
            width: 5, // عرض الشريط
            height: 110,
            decoration: BoxDecoration(
              color: indicatorColor, // لون حسب المستوى
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
            ),
          ),

          // محتوى الكارد
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                14,
                10,
                12,
              ), // padding داخلي
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // أعلى
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700, // Bold
                            color: titleColor,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8), // مسافة
                      // بادج الحالة (Moderate/Unhealthy)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ), // padding
                        decoration: BoxDecoration(
                          color: statusColor, // خلفية
                          borderRadius: BorderRadius.circular(12), // زوايا
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            color: indicatorColor,
                            fontWeight: FontWeight.w700, // bold
                          ),
                        ),
                      ),

                      const SizedBox(width: 6), // مسافة

                      IconButton(
                        onPressed: () => onDelete(), // حذف
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.grey[500],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8), // مسافة
                  // وصف التنبيه
                  Text(
                    subtitle, // الرسالة
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.45, // تباعد أسطر
                    ),
                  ),

                  const SizedBox(height: 12), // مسافة
                  // الوقت أسفل يمين
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // يمين
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4), // مسافة
                      Text(
                        time,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
