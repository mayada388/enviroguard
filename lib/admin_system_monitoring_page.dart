import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSystemMonitoringPage extends StatelessWidget {
  const AdminSystemMonitoringPage({super.key});

  static const Color primaryColor = Color(0xFF32345F);
  static const Color backgroundColor = Color(0xFFF7F7FB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'System Monitoring',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Edge Device Card 
              _buildEdgeDeviceCard(),

              const SizedBox(height: 10),

              //  Sensors 
              const Text(
                'Sensors',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildSensorsTable(),

              const SizedBox(height: 16),

              // Alert Logs 
              const Text(
                'Alert Logs',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildAlertsTable(),
            ],
          ),
        ),
      ),
    );
  }

  //  EDGE DEVICE CARD 
  Widget _buildEdgeDeviceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('edge_devices')
          .doc('raspberry') 
          .snapshots(),
      builder: (context, snapshot) {
        String statusText = 'Loading...';
        Color statusColor = const Color(0xFFAAAAAA);

        if (snapshot.hasError) {
          statusText = 'Error';
          statusColor = const Color(0xFFD65B66);
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          statusText = 'Loading...';
        } else if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'Unknown').toString();

          if (status.toLowerCase() == 'online') {
            statusText = 'Online';
            statusColor = const Color(0xFF3BAF63);
          } else if (status.toLowerCase() == 'offline') {
            statusText = 'Offline';
            statusColor = const Color(0xFFD65B66);
          } else {
            statusText = status;
            statusColor = const Color(0xFFAAAAAA);
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Edge Device',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F8EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //  SENSORS TABLE 
  Widget _buildSensorsTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity, // يخلي الجدول ياخذ عرض الكرت كامل
        child: SingleChildScrollView(
          scrollDirection: Axis
              .horizontal, // لو الشاشة ضيقة يصير فيه سحب يمين ويسار بدل ما تنقص الأعمدة
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sensors')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading sensors');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Loading sensors...'),
                );
              }

              final docs = snapshot.data!.docs;

              return DataTable(
                columnSpacing: 18,
                headingRowHeight: 32,
                dataRowHeight: 32,
                headingTextStyle: const TextStyle(
                  color: Color(0xFF2F8AD8),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) => const Color(0xFFEAF4FF),
                ),
                columns: const [
                  DataColumn(label: Text('Sensor ID')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Location')),
                  DataColumn(
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Last Update'),
                    ),
                  ),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final sensorId = doc.id; 
                  final sensorType = (data['sensorType'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();
                  final location =
                      (data['locationId'] ?? '').toString(); // taibah_university
                  final lastUpdate = _formatTime(data['lastUpdate']);

                  final statusColor =
                      status.toLowerCase() == 'active'
                          ? const Color(0xFF3BAF63)
                          : const Color(0xFFD65B66);

                  return DataRow(
                    cells: [
                      DataCell(Text(sensorId,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(sensorType,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      DataCell(Text(location,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(lastUpdate,
                          style: const TextStyle(fontSize: 11))),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  //  ALERTS TABLE 
  Widget _buildAlertsTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .orderBy('timestamp', descending: true)
                .limit(5) // آخر 5 تنبيهات
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading alerts');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Loading alerts...'),
                );
              }

              final docs = snapshot.data!.docs;

              return DataTable(
                columnSpacing: 30,
                headingRowHeight: 32,
                dataRowHeight: 32,
                headingTextStyle: const TextStyle(
                  color: Color(0xFF2F8AD8),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) => const Color(0xFFEAF4FF),
                ),
                columns: const [
                  DataColumn(label: Text('Alert Type')),
                  DataColumn(label: Text('Sensor ID')),
                  DataColumn(label: Text('Time')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString();
                  final sensorId =
                      (data['sensorId'] ?? '-').toString(); // يتعامل مع null
                  final time = _formatTime(data['timestamp']);

                  return DataRow(
                    cells: [
                      DataCell(
                          Text(title, style: const TextStyle(fontSize: 11))),
                      DataCell(
                          Text(sensorId, style: const TextStyle(fontSize: 11))),
                      DataCell(
                          Text(time, style: const TextStyle(fontSize: 11))),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        
      ),
    );
  }

  // HELPERS 
  static String _formatTime(dynamic value) {
    if (value == null) return '-';

    
    if (value is Timestamp) {
      final dt = value.toDate();
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:$minute $period';
    }

    
    if (value is String) {
      return value;
    }

    return value.toString();
  }
}