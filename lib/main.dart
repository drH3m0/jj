import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(AttendanceApp());

class AttendanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QRGeneratorPage(),
    );
  }
}

// Database helper class
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'attendance.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_name TEXT,
        roll_number TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<void> insertAttendance(String studentName, String rollNumber) async {
    final db = await database;
    await db.insert('attendance', {
      'student_name': studentName,
      'roll_number': rollNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

// QR Code Generator Page
class QRGeneratorPage extends StatefulWidget {
  @override
  _QRGeneratorPageState createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  String? _qrData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate QR Code for Students'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Student Name'),
            ),
            TextField(
              controller: _rollNoController,
              decoration: InputDecoration(labelText: 'Roll Number'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _qrData =
                      '${_nameController.text} - ${_rollNoController.text}';
                });
              },
              child: Text('Generate QR Code'),
            ),
            SizedBox(height: 20),
            _qrData != null
                ? QrImage(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 200.0,
                  )
                : Container(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QRScannerPage(),
                  ),
                );
              },
              child: Text('Scan QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}

// QR Code Scanner Page
class QRScannerPage extends StatefulWidget {
  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? scannedData;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(scannedData != null
                  ? 'Scanned: $scannedData'
                  : 'Scan a code'),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        scannedData = scanData.code;
      });
      // تسجيل الحضور بناءً على البيانات التي تم مسحها
      final parts = scannedData?.split(' - ');
      if (parts != null && parts.length == 2) {
        final name = parts[0];
        final rollNo = parts[1];
        await DatabaseHelper().insertAttendance(name, rollNo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance recorded for $name')),
        );
      }
    });
  }
}
