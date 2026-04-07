import 'package:flutter/material.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

// State للصفحة (عشان نتحكم بزر التوليد Loading)
class _NotificationsPageState extends State<NotificationsPage> {
  bool _isGenerating = false; // يمنع ضغط الزر أكثر من مرة

  // الملوثات اللي بنولد لها تنبيهات (لازم تكون نفس doc IDs في thresholds و alert_templates)
  static const List<String> pollutantIds = ['PM2_5', 'PM10', 'O3', 'CO', 'SO2'];

  //  زر توليد التنبيهات (بديل عن Cloud Functions) 
  Future<void> _generateAlertsForAllUsers() async {
    if (_isGenerating) return; // إذا شغال لا تعيد

    setState(() => _isGenerating = true); 

    try {
      final firestore = FirebaseFirestore.instance; 

      // نجيب كل اليوزرز
      final usersSnap = await firestore.collection('users').get(); // قراءة كل المستخدمين

      if (usersSnap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users found.')),
        );
        return;
      }

      // كاش للـ thresholds (عشان ما نقرأها لكل يوزر)
      final Map<String, Map<String, dynamic>> thresholdsByPid = {}; // thresholds لكل pollutantId
      for (final pid in pollutantIds) {
        final thDoc = await firestore.collection('thresholds').doc(pid).get(); // thresholds/{pid}
        final th = thDoc.data(); // بيانات الثريش هولد
        if (th != null) thresholdsByPid[pid] = th; 
      }

      //كاش للـ templates (عشان ما نقرأها لكل alert)
      final Map<String, Map<String, dynamic>> templateCache = {}; // templateCache[docId] = data
      Future<Map<String, dynamic>> getTemplate(String pid, String level) async {
        final docId = '${pid}_${level.toLowerCase()}'; // مثال: PM2_5_unhealthy
        if (templateCache.containsKey(docId)) return templateCache[docId]!; // رجّع من الكاش
        final doc = await firestore.collection('alert_templates').doc(docId).get(); // alert_templates/{docId}
        final data = doc.data() ?? <String, dynamic>{}; // لو ما فيه يرجع فاضي
        templateCache[docId] = data; // خزّن بالكاش
        return data; // رجع
      }

      //  كاش لبيانات الهواء لكل Location (عشان لو 50 يوزر بنفس اللوكيشن ما نكرر القراءة)
      final Map<String, Map<String, dynamic>?> airCache = {}; // airCache[locationId] = air_quality_data doc

      //  نجهز batch (أفضل من writes كثيرة)
      final batch = firestore.batch(); // Batch write

      int created = 0; // عدد alerts المتولدة
      int skippedSameLevel = 0; // كم Alert انمنع لأنه نفس المستوى السابق
      int skippedNoLocation = 0; // يوزر ما عنده locationId
      int skippedNoAirDoc = 0; // location ما لها air doc

      //  نمشي على كل يوزر
      for (final u in usersSnap.docs) {
        final userUid = u.id; // uid = docId للـ users
        final uData = u.data(); // بيانات اليوزر
        final locationId = (uData['locationId'] ?? '').toString(); // locationId من users

        //  Quiet Hours 
// لو quietHours enabled والوقت الحالي داخل الفترة -> لا نولد تنبيهات لهذا اليوزر الآن

final qh = uData['quietHours'];
if (qh is Map) {
  final enabled = (qh['enabled'] == true);

  // start: {hour: x, minute: y}
final quietStart = _readTime(qh['start']);
final quietEnd   = _readTime(qh['end']);

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

    // إذا الفترة تعبر منتصف الليل (مثلاً 22:00 -> 07:00)
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

  // لو الفترة تعبر منتصف الليل
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
//  End Quiet Hours 



        // إذا ما عنده لوكيشن نتجاهله
        if (locationId.isEmpty) {
          skippedNoLocation++;
          continue;
        }

        //  نقرأ air_quality_data/{locationId} (من الكاش أو من Firestore)
        Map<String, dynamic>? air;
        if (airCache.containsKey(locationId)) {
          air = airCache[locationId]; // رجع من الكاش
        } else {
          final airDoc = await firestore.collection('air_quality_data').doc(locationId).get(); // air_quality_data/{locationId}
          air = airDoc.data(); // بيانات الهواء
          airCache[locationId] = air; // خزّن بالكاش
        }

        // إذا ما فيه بيانات هواء لهذا اللوكيشن
        if (air == null) {
          skippedNoAirDoc++;
          continue;
        }

        //  نقرأ alertState الحالي للمنع من التكرار
        final Map<String, dynamic> alertState =
            (uData['alertState'] is Map) ? Map<String, dynamic>.from(uData['alertState']) : {}; // alertState كامل

        final Map<String, dynamic> locState =
            (alertState[locationId] is Map) ? Map<String, dynamic>.from(alertState[locationId]) : {}; // alertState الخاص باللوكيشن

        //  لكل ملوث
        for (final pid in pollutantIds) {

  // التفضيلات الشخصية
  final personalAlerts = uData['personalAirAlerts'];
  if (personalAlerts is Map) {
    final wantsThisPollutant = personalAlerts[pid];
    if (wantsThisPollutant == false) {
      continue;
    }
  }

  //  اقرأ القيمة من air_quality_data
final value = _toDouble(air[pid]);
if (value == null) continue;

//  اقرأ thresholds الخاصة بالـ pid
final th = thresholdsByPid[pid];
if (th == null) continue;

//  احسب مستوى التنبيه (Moderate / Unhealthy / null)
final level = _computeLevel(value, th);
if (level == null) continue; // طبيعي -> لا تنبيه

//  اقرأ آخر level مخزن (عشان منع التكرار)
final Map<String, dynamic> pidState =
    (locState[pid] is Map) ? Map<String, dynamic>.from(locState[pid]) : {};

final lastLevel = (pidState['level'] ?? '').toString();

//  منع التكرار: إذا نفس المستوى السابق لا نرسل
if (lastLevel.toLowerCase() == level.toLowerCase()) {
  skippedSameLevel++;
  continue;
}

          // template
          final tpl = await getTemplate(pid, level); // title/message من alert_templates
          final title = (tpl['title'] ?? '${_displayPollutant(pid)} $level').toString(); // عنوان افتراضي إذا ما فيه
          final message = (tpl['message'] ?? '${_displayPollutant(pid)} is $level.').toString(); // رسالة افتراضية إذا ما فيه

          // اكتب alert جديد
          final alertRef = firestore.collection('alerts').doc(); // doc جديد
          batch.set(alertRef, {
            'userUid': userUid, // لمن هذا التنبيه
            'locationId': locationId, // موقعه
            'pollutantId': pid, // ID مهم للمنطق (PM2_5..)
            'pollutantType': _displayPollutant(pid), // اسم للعرض (PM2.5..)
            'value': value, // القيمة الحالية
            'alertLevel': level, // Moderate / Unhealthy
            'title': title, // عنوان من template
            'message': message, // رسالة من template
            'timestamp': Timestamp.now(), 
          });

          // حدّث alertState عند اليوزر (عشان منع التكرار المرة الجاية)
          final userRef = firestore.collection('users').doc(userUid); // users/{uid}
          batch.set(
            userRef,
            {
              'alertState': {
                locationId: {
                  pid: {
                    'level': level, // آخر مستوى
                    'lastSentAt': FieldValue.serverTimestamp(), // وقت الإرسال
                    'value': value, // آخر قيمة (اختياري)
                  }
                }
              }
            },
            SetOptions(merge: true), // دمج بدون حذف باقي بيانات اليوزر
          );

          created++; // عدّاد
        }
      }

      //  نفذ كل الكتابات مرة وحدة
      await batch.commit(); // commit للـ batch

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
      // أي خطأ
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // رجّع الزر طبيعي
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // تحويل أي قيمة لـ double
  double? _toDouble(dynamic v) {
    if (v == null) return null; // لو null
    if (v is num) return v.toDouble(); // لو رقم
    return double.tryParse(v.toString()); // لو نص نحاول نحوله
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
    if (maxSafe == null || maxModerate == null) return null; // إذا ناقص شيء

    if (value > maxModerate) return 'Unhealthy'; // أعلى من moderate = Unhealthy
    if (value > maxSafe) return 'Moderate'; // أعلى من safe = Moderate
    return null; // طبيعي -> لا تنبيه
  }

  // تحويل pollutantId لاسم عرض
  String _displayPollutant(String pid) {
    switch (pid) {
      case 'PM2_5':
        return 'PM2.5';
      case 'PM10':
        return 'PM10';
      case 'O3':
        return 'O3';
      case 'CO':
        return 'CO';
      case 'SO2':
        return 'SO2';
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
    return '$hour:$minute $ampm'; // صيغة العرض
  }

  // تقسيم الأقسام Today/Yesterday/This week
  String _groupLabel(DateTime dt) {
    final now = DateTime.now(); // الآن
    final today = DateTime(now.year, now.month, now.day); // تاريخ اليوم بدون وقت
    final d = DateTime(dt.year, dt.month, dt.day); // تاريخ العنصر بدون وقت
    final diff = today.difference(d).inDays; // الفرق بالأيام

    if (diff == 0) return 'Today'; // اليوم
    if (diff == 1) return 'Yesterday'; // أمس
    return 'This week'; // غيرها (نعرضها كـ This week)
  }

  // ألوان حسب مستوى التنبيه
  ({Color statusColor, Color indicatorColor, Color titleColor}) _levelColors(String level) {
    final l = level.toLowerCase(); // lower case للمقارنة

    if (l.contains('unhealthy') || l.contains('hazard') || l.contains('danger')) {
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

  // فلتر: اعرض فقط آخر 7 أيام (لكن لا نحذف من الداتا بيز)
  bool _isWithinLast7Days(Timestamp ts) {
    final dt = ts.toDate(); // تاريخ التنبيه
    final now = DateTime.now(); // الآن
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF32345F)), // رجوع
          onPressed: () => Navigator.pop(context), // يرجع
        ),
        title: const Text(
          'Notifications', // عنوان
          style: TextStyle(color: Color(0xFF32345F), fontWeight: FontWeight.w500), // ستايل
        ),
        centerTitle: true, // وسط
        actions: [
          IconButton(
            tooltip: 'Generate alerts for all users', // تلميح
            icon: _isGenerating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_alert, color: Color(0xFF32345F)), // أيقونة
            onPressed: _isGenerating ? null : _generateAlertsForAllUsers, // زر يولد
          ),
        ],
      ),

      body: uid == null
          ? const Center(
              child: Text('Please login first.', style: TextStyle(color: Colors.grey)),
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
                  return const Center(child: CircularProgressIndicator()); // تحميل
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }

                final allDocs = snapshot.data?.docs ?? []; // كل الدوكس

                // فلترة 7 أيام + تجاهل أي doc ما فيه timestamp صحيح
                final docs = <QueryDocumentSnapshot>[];
                for (final d in allDocs) {
                  final data = d.data() as Map<String, dynamic>; // data
                  final ts = data['timestamp']; // timestamp
                  if (ts is! Timestamp) continue; // إذا مو جاهز
                  if (!_isWithinLast7Days(ts)) continue; // إذا أقدم من 7 أيام
                  docs.add(d); // أضفه للقائمة
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
                  );
                }

                // تجميع الأقسام Today/Yesterday/This week
                final Map<String, List<QueryDocumentSnapshot>> grouped = {}; // grouped map
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>; // data
                  final ts = data['timestamp'] as Timestamp; // timestamp
                  final label = _groupLabel(ts.toDate()); // label
                  grouped.putIfAbsent(label, () => []); // إذا ما موجود
                  grouped[label]!.add(d); // أضف
                }

                // ترتيب الأقسام
                final sectionOrder = ['Today', 'Yesterday', 'This week']; // ترتيب ثابت
                final sections = <String>[
                  for (final s in sectionOrder)
                    if (grouped.containsKey(s) && grouped[s]!.isNotEmpty) s // فقط الموجود
                ];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), // padding زي الصورة
                  itemCount: sections.length, // عدد الأقسام
                  itemBuilder: (context, index) {
                    final section = sections[index]; // اسم القسم
                    final items = grouped[section] ?? []; // عناصره

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // محاذاة
                      children: [
                        _SectionHeader(title: section), // عنوان القسم
                        const SizedBox(height: 8), // مسافة
                        ...items.map((doc) {
                          final data = doc.data() as Map<String, dynamic>; // data

                          final pollutant = (data['pollutantType'] ?? '-').toString(); // اسم ملوث للعرض
                          final message = (data['message'] ?? '').toString(); // رسالة
                          final level = (data['alertLevel'] ?? '').toString(); // مستوى
                          final value = (data['value'] ?? '').toString(); // قيمة
                          final ts = data['timestamp'] as Timestamp; // timestamp

                          final colors = _levelColors(level); // ألوان حسب المستوى

                          // عنوان الكارد (زي الصورة: عنوان كبير + مستوى يمين)
                          final titleText = (data['title'] ?? '').toString().trim().isNotEmpty
                              ? (data['title'] ?? '').toString()
                              : (value.isNotEmpty ? '$pollutant • $value' : pollutant);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14), // مسافة بين الكروت
                            child: _NotificationCard(
                              title: titleText, // العنوان
                              subtitle: message.isEmpty ? '—' : message, // النص
                              status: level.isEmpty ? 'Alert' : level, // البادج
                              statusColor: colors.statusColor, // لون البادج
                              indicatorColor: colors.indicatorColor, // لون الشريط
                              titleColor: colors.titleColor, // لون العنوان
                              time: _formatTime(ts), // الوقت
                              onDelete: () async {
                                //زر حذف للتجربةا
                                await FirebaseFirestore.instance.collection('alerts').doc(doc.id).delete();
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 18), // مسافة بعد القسم
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
  final String title; // عنوان القسم
  const _SectionHeader({required this.title}); // constructor

  @override
  Widget build(BuildContext context) {
    return Text(
      title, // النص
      style: TextStyle(
        fontSize: 15, // حجم
        color: Colors.grey[600], // لون رمادي
        fontWeight: FontWeight.w500, // وزن
      ),
    );
  }
}

// Widget كرت التنبيه (UI مطابق للصورة)
class _NotificationCard extends StatelessWidget {
  final String title; // العنوان
  final String subtitle; // النص
  final String status; // مستوى التنبيه
  final Color statusColor; // لون خلفية البادج
  final Color indicatorColor; // لون الشريط + نص البادج
  final Color titleColor; // لون العنوان
  final String time; // وقت
  final Future<void> Function() onDelete; // حذف للتجربة

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
        color: Colors.white, // خلفية بيضاء
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
          // الشريط اليسار
          Container(
            width: 5, // عرض الشريط
            height: 110, // ارتفاع ثابت يمنع infinite height
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
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12), // padding داخلي
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // محاذاة يسار
                children: [
                  // سطر العنوان + بادج + حذف
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // أعلى
                    children: [
                      // العنوان
                      Expanded(
                        child: Text(
                          title, // النص
                          style: TextStyle(
                            fontSize: 14, // حجم
                            fontWeight: FontWeight.w700, // Bold
                            color: titleColor, // لون حسب المستوى
                          ),
                        ),
                      ),

                      const SizedBox(width: 8), // مسافة

                      // بادج الحالة (Moderate/Unhealthy)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // padding
                        decoration: BoxDecoration(
                          color: statusColor, // خلفية
                          borderRadius: BorderRadius.circular(12), // زوايا
                        ),
                        child: Text(
                          status, // نص الحالة
                          style: TextStyle(
                            fontSize: 11, // حجم
                            color: indicatorColor, // لون
                            fontWeight: FontWeight.w700, // bold
                          ),
                        ),
                      ),

                      const SizedBox(width: 6), // مسافة

                      //  زر حذف للتجربة فقط 
                      IconButton(
                        onPressed: () => onDelete(), // حذف
                        icon: const Icon(Icons.delete_outline, size: 18), // أيقونة
                        color: Colors.grey[500], // لون
                        padding: EdgeInsets.zero, // بدون padding
                        constraints: const BoxConstraints(), // يمنع تمدد
                      ),
                    ],
                  ),

                  const SizedBox(height: 8), // مسافة

                  // وصف التنبيه
                  Text(
                    subtitle, // الرسالة
                    style: TextStyle(
                      fontSize: 12, // حجم
                      color: Colors.grey[700], // رمادي
                      height: 1.45, // تباعد أسطر
                    ),
                  ),

                  const SizedBox(height: 12), // مسافة

                  // الوقت أسفل يمين
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // يمين
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[400]), // أيقونة
                      const SizedBox(width: 4), // مسافة
                      Text(
                        time, // الوقت
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]), // ستايل
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