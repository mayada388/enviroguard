import 'package:flutter/material.dart';

class AdminSystemMonitoringPage extends StatelessWidget {
  const AdminSystemMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF32345F);
    const backgroundColor = Color(0xFFF7F7FB);

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
              // ====== Edge Device Card ======
              Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFE5F8EC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Online',
                        style: TextStyle(
                          color: Color(0xFF3BAF63),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  ],
                ),
              ),

              // ====== Sensors Table ======
              const Text(
                'Sensors',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
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
                child: DataTable(
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
                    DataColumn(label: Text('Last Update')),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        const DataCell(Text('SEN-001', style: TextStyle(fontSize: 11))),
                        const DataCell(Text('O₃', style: TextStyle(fontSize: 11))),
                        const DataCell(
                          Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD65B66),
                            ),
                          ),
                        ),
                        const DataCell(Text('Campus', style: TextStyle(fontSize: 11))),
                        const DataCell(Text('10:00 AM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                    DataRow(
                      cells: const [
                        DataCell(Text('SEN-002', style: TextStyle(fontSize: 11))),
                        DataCell(Text('SO₂', style: TextStyle(fontSize: 11))),
                        DataCell(
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3BAF63),
                            ),
                          ),
                        ),
                        DataCell(Text('Campus', style: TextStyle(fontSize: 11))),
                        DataCell(Text('5:00 PM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                    DataRow(
                      cells: const [
                        DataCell(Text('SEN-003', style: TextStyle(fontSize: 11))),
                        DataCell(Text('CO₂', style: TextStyle(fontSize: 11))),
                        DataCell(
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3BAF63),
                            ),
                          ),
                        ),
                        DataCell(Text('Campus', style: TextStyle(fontSize: 11))),
                        DataCell(Text('8:00 PM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                    DataRow(
                      cells: const [
                        DataCell(Text('SEN-004', style: TextStyle(fontSize: 11))),
                        DataCell(Text('PM10', style: TextStyle(fontSize: 11))),
                        DataCell(
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3BAF63),
                            ),
                          ),
                        ),
                        DataCell(Text('Campus', style: TextStyle(fontSize: 11))),
                        DataCell(Text('9:00 AM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                    DataRow(
                      cells: const [
                        DataCell(Text('SEN-005', style: TextStyle(fontSize: 11))),
                        DataCell(Text('PM2.5', style: TextStyle(fontSize: 11))),
                        DataCell(
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3BAF63),
                            ),
                          ),
                        ),
                        DataCell(Text('Campus', style: TextStyle(fontSize: 11))),
                        DataCell(Text('11:00 AM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                  ],
                ),
              ),

              // ====== Alert Logs Table ======
              const Text(
                'Alert Logs',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
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
                child: DataTable(
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
                    DataColumn(label: Text('Alert Type')),
                    DataColumn(label: Text('Sensor ID')),
                    DataColumn(label: Text('Time')),
                  ],
                  rows: const [
                    DataRow(
                      cells: [
                        DataCell(Text('CO₂ Threshold Exceeded',
                            style: TextStyle(fontSize: 11))),
                        DataCell(Text('SEN-003', style: TextStyle(fontSize: 11))),
                        DataCell(Text('11:00 AM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                    DataRow(
                      cells: [
                        DataCell(
                            Text('PM2.5 High Level', style: TextStyle(fontSize: 11))),
                        DataCell(Text('SEN-005', style: TextStyle(fontSize: 11))),
                        DataCell(Text('8:00 PM', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}