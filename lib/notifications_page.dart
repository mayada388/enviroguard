import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // لون خلفية هادئ من التصميم
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF32345F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Color(0xFF32345F), fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: const [
          _SectionHeader(title: 'Today'),
          _NotificationTile(
            title: 'Forecast indicates a high concentration of PM2.5',
            subtitle: 'AQI may reach 160 by 6 PM. Air quality will be unhealthy, especially for sensitive groups. Please limit outdoor activities.',
            status: 'Unhealthy',
            statusColor: Color(0xFFF2A7AD), // وردي فاتح
            indicatorColor: Color(0xFFD65B66), // أحمر للخط الجانبي
            time: '40 min ago',
          ),
          
          SizedBox(height: 20),
          _SectionHeader(title: 'Yesterday'),
          _NotificationTile(
            title: 'zone Level Alert',
            subtitle: 'Ozone levels are predicted to rise sharply today. Expect elevated pollution levels, especially in urban areas. The air quality will be hazardous for children and people with respiratory issues.',
            status: 'Moderate',
            statusColor: Color(0xFFFDE9C9), // أصفر فاتح
            indicatorColor: Color(0xFFE9B35F), // برتقالي للخط الجانبي
            time: '1 day ago',
          ),

          SizedBox(height: 20),
          _SectionHeader(title: 'This week'),
          _NotificationTile(
            title: 'Forecast indicates a high concentration of PM10',
            subtitle: 'A dust storm is expected to reach the city by 4 PM. The PM10 levels will surge, causing poor air quality and limiting visibility. Take precautions if you need to travel outside.',
            status: 'Unhealthy',
            statusColor: Color(0xFFF2A7AD),
            indicatorColor: Color(0xFFD65B66),
            time: '5 day ago',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 5),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w400),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Color indicatorColor;
  final String time;

  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.indicatorColor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الخط الجانبي الملون من التصميم
              Container(width: 4, color: indicatorColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD65B66)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                            child: Text(status, style: TextStyle(fontSize: 10, color: indicatorColor, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}