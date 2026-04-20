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
              _buildEdgeDeviceCard(),
              const SizedBox(height: 10),

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

  // EDGE DEVICE (edge_devices → raspberry)
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

  // SENSORS (sensors: SEN-001..003)
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sensors').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Text('Loading sensors...');
          }

          final docs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowHeight: 32,
              dataRowHeight: 32,
              columns: const [
                DataColumn(label: Text('Sensor ID')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Last Update')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final sensorId = doc.id;
                final type = (data['sensorType'] ?? '').toString();
                final status = (data['status'] ?? '').toString();
                final location = (data['locationId'] ?? '').toString();
                final lastUpdate = _formatTime(data['lastUpdate']);

                final color = status.toLowerCase() == 'active'
                    ? const Color(0xFF3BAF63)
                    : const Color(0xFFD65B66);

                return DataRow(
                  cells: [
                    DataCell(Text(sensorId, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(type, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(status,
                        style: TextStyle(fontSize: 11, color: color))),
                    DataCell(Text(location, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(lastUpdate, style: const TextStyle(fontSize: 11))),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // ALERTS (alerts structure you gave)
  Widget _buildAlertsTable() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Text('Loading alerts...');
          }

          final docs = snapshot.data!.docs;

          return DataTable(
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Value')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Time')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return DataRow(
                cells: [
                  DataCell(Text((data['title'] ?? '').toString())),
                  DataCell(Text((data['pollutantType'] ?? '').toString())),
                  DataCell(Text((data['value'] ?? '').toString())),
                  DataCell(Text((data['locationId'] ?? '').toString())),
                  DataCell(Text(_formatTime(data['timestamp']))),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  static String _formatTime(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return value.toString();
  }
}