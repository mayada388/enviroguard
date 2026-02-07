import 'package:flutter/material.dart';
import 'notifications_page.dart';
import 'login_page.dart';

// استوردي صفحات الكنترول بنل الحقيقية (عدّلي الأسماء لو مختلفة)
import 'admin_system_monitoring_page.dart';
import 'admin_manage_sensors_page.dart';
import 'admin_set_thresholds_page.dart';

/// أنواع الخيارات في قائمة Control Panel
enum _AdminMenuAction {
  systemMonitoring,
  manageSensors,
  setThresholds,
  logout,
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final Color primaryColor = const Color(0xFF32345F);
  final Color backgroundColor = const Color(0xFFF9F9FB);

  // 🔹 الموقع المختار (الآن واحد بس، بعدين تقدري تزودي)
  String selectedLocation = 'Taibah University';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================== 1. الهيدر ==================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: AssetImage('assets/avatar.png'),
                  ),
                  const SizedBox(width: 15),

                  // -------- النصوص على اليسار --------
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
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            // 🔽 هنا صار Location كـ Dropdown بدل نص ثابت
                            DropdownButton<String>(
                              value: selectedLocation,
                              underline: const SizedBox(), // يشيل الخط اللي تحت
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Taibah University',
                                  child: Text('Taibah University'),
                                ),
                                // مستقبلاً : تقدري تزودي مواقع ثانية هنا
                                // DropdownMenuItem(
                                //   value: 'Another Location',
                                //   child: Text('Another Location'),
                                // ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedLocation = value;
                                });
                                // لاحقاً: تربطي هذا الإختيار مع API / Firebase
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // -------- الجزء اليمين: Control Panel (نص أحمر) + الجرس --------
                  Row(
                    children: [
                      // أولاً: زر Control Panel كنص أحمر
                      PopupMenuButton<_AdminMenuAction>(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'Control Panel',
                            style: TextStyle(
                              color: Color(0xFFD65B66), // أحمر
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem<_AdminMenuAction>(
                            enabled: false,
                            child: Text(
                              'Control Panel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem<_AdminMenuAction>(
                            value: _AdminMenuAction.systemMonitoring,
                            child: Text('System Monitoring'),
                          ),
                          PopupMenuItem<_AdminMenuAction>(
                            value: _AdminMenuAction.manageSensors,
                            child: Text('Manage Sensors'),
                          ),
                          PopupMenuItem<_AdminMenuAction>(
                            value: _AdminMenuAction.setThresholds,
                            child: Text('Set Thresholds'),
                          ),
                          PopupMenuItem<_AdminMenuAction>(
                            value: _AdminMenuAction.logout,
                            child: Text('Logout'),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case _AdminMenuAction.systemMonitoring:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminSystemMonitoringPage(),
                                ),
                              );
                              break;

                            case _AdminMenuAction.manageSensors:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminManageSensorsPage(),
                                ),
                              );
                              break;

                            case _AdminMenuAction.setThresholds:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminSetThresholdsPage(),
                                ),
                              );
                              break;

                            case _AdminMenuAction.logout:
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                                (route) => false,
                              );
                              break;
                          }
                        },
                      ),

                      // ثانياً: زر الإشعارات (يكون على اليمين)
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
              ),

              const SizedBox(height: 25),

              // ================== 2. كرت جودة الهواء ==================
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
                        const Text(
                          'Moderate',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE9B35F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Main Pollutant: PM2.5\nUpdated: 3:00 PM',
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
                            value: 0.85,
                            strokeWidth: 10,
                            backgroundColor: const Color(0xFFF1F1F1),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFE9B35F),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '85',
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

              const SizedBox(height: 20),

              // ================== 3. كرت التحذير ==================
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEBED),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFF2A7AD).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD65B66),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'High concentration of PM2.5 detected (80 µg/m³). '
                        'Air quality is Unhealthy consider wearing a mask.',
                        style: TextStyle(
                          color: Color(0xFFD65B66),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFFD65B66),
                      ),
                      onPressed: () {
                        // ممكن لاحقاً تخفين الرسالة
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ================== 4. Metrological Data ==================
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
                  _MetCard(
                    icon: Icons.compress,
                    title: 'Pressure',
                    value: '720 hpa',
                  ),
                  _MetCard(
                    icon: Icons.thermostat,
                    title: 'Temperature',
                    value: '29°',
                  ),
                  _MetCard(
                    icon: Icons.air,
                    title: 'Wind speed',
                    value: '12km/h',
                  ),
                  _MetCard(
                    icon: Icons.water_drop_outlined,
                    title: 'Humidity',
                    value: '2,3',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ================== 5. Air Pollutants Levels ==================
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

              // ================== 6. Forecasts ==================
              const _SectionTitle(
                title: 'Forecasts',
                icon: Icons.show_chart,
              ),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildChartBackground(
                      const [
                        _Bar(value: 35, color: Colors.green, label: '3 PM'),
                        _Bar(value: 48, color: Colors.green, label: '4 PM'),
                        _Bar(
                            value: 58,
                            color: Color(0xFFFEE9A0),
                            label: '5 PM'),
                        _Bar(
                            value: 82,
                            color: Color(0xFFD65B66),
                            label: '6 PM'),
                        _Bar(
                            value: 72,
                            color: Color(0xFFE9B35F),
                            label: '7 PM'),
                      ],
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
                      const [
                        _Bar(value: 42, color: Colors.green, label: '3 PM'),
                        _Bar(value: 36, color: Colors.green, label: '4 PM'),
                        _Bar(
                            value: 65,
                            color: Color(0xFFFEE9A0),
                            label: '5 PM'),
                        _Bar(
                            value: 50,
                            color: Color(0xFFFEE9A0),
                            label: '6 PM'),
                        _Bar(
                            value: 62,
                            color: Color(0xFFFEE9A0),
                            label: '7 PM'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ================== 7. Download Report ==================
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

  static Widget _buildChartBackground(List<Widget> bars) {
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      height: 1,
                      color: Color(0xFFF1F1F1),
                    ),
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

// ================== Widgets مساعدة ==================

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
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF32345F),
        ),
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
          Icon(
            icon,
            color: Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
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
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}