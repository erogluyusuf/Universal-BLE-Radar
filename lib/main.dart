import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:sensors_plus/sensors_plus.dart';

// --- RENK PALETİ ---
const Color kBgColor = Color(0xFF000000);
const Color kCardColor = Color(0xFF1C1C1E);
const Color kPrimaryGreen = Color(0xFF32D74B);
const Color kCriticalRed = Color(0xFFFF453A);
const Color kNeutralGrey = Color(0xFF8E8E93);
// Derleyici hatasını önlemek için bunları const kullanmadan aşağıda çağıracağız
const Color kTextPrimary = Colors.white;
const Color kTextSecondary = Color(0xFF8E8E93);

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SentinelApp());
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBgColor,
        primaryColor: kPrimaryGreen,
        cardColor: kCardColor,
      ),
      home: const RadarScreen(),
    );
  }
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});
  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  // --- CORE DEĞİŞKENLER ---
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  ScanResult? _targetDevice;
  double? _heading = 0;

  // --- HESAPLAMA ---
  double _smoothedRssi = -100;
  Timer? _feedbackTimer;
  double _lastRssi = -100;

  // --- UI DURUMLARI ---
  IconData _directionIcon = Icons.accessibility_new;
  Color _directionColor = kNeutralGrey;
  String _directionText = "Yönü bulmak için yürüyün";
  double _motionIntensity = 0;

  final Map<int, String> _vendorMap = {
    76: "Apple Inc.", 117: "Samsung", 6: "Microsoft", 224: "Google", 89: "Nordic"
  };

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() async {
    await [Permission.location, Permission.bluetoothScan, Permission.bluetoothConnect].request();

    if (Platform.isAndroid && await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      await FlutterBluePlus.turnOn();
    }
    _toggleScan(forceStart: true);

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
        if (_targetDevice != null) {
          try {
            final target = results.firstWhere((r) => r.device.remoteId == _targetDevice?.device.remoteId);
            _updateHotColdLogic(target);
          } catch (_) {}
        }
      }
    });

    userAccelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() {
          _motionIntensity = event.x.abs() + event.y.abs() + event.z.abs();
        });
      }
    });

    FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading);
    });
  }

  void _updateHotColdLogic(ScanResult result) {
    int currentRssi = result.rssi;

    if (_smoothedRssi == -100) _smoothedRssi = currentRssi.toDouble();
    _smoothedRssi = (_smoothedRssi * 0.7) + (currentRssi * 0.3);

    if (_smoothedRssi > -45) {
      _directionIcon = Icons.check_circle;
      _directionColor = kPrimaryGreen;
      _directionText = "HEDEF BURADA!";
      _triggerHaptic(50);
      return;
    }

    if (_motionIntensity < 1.2) {
      _directionIcon = Icons.directions_walk;
      _directionColor = kNeutralGrey;
      _directionText = "Yön tayini için yürüyün...";
      return;
    }

    if (_smoothedRssi > _lastRssi + 1.5) {
      _directionIcon = Icons.arrow_upward;
      _directionColor = kPrimaryGreen;
      _directionText = "DOĞRU YÖN\nYaklaşıyorsun";
      _triggerHaptic(100);
    } else if (_smoothedRssi < _lastRssi - 1.5) {
      _directionIcon = Icons.arrow_downward;
      _directionColor = kCriticalRed;
      _directionText = "YANLIŞ YÖN\nArkanı Dön";
      _triggerHaptic(300);
    }

    _lastRssi = _smoothedRssi;
  }

  void _triggerHaptic(int duration) async {
    if (_feedbackTimer != null && _feedbackTimer!.isActive) return;
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () async {
      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: duration);
    });
  }

  double _calculateDistance(double rssi) {
    double ratio = rssi * 1.0 / -59;
    if (ratio < 1.0) return pow(ratio, 10).toDouble();
    return (0.89976) * pow(ratio, 7.7095) + 0.111;
  }

  String _getName(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    final mData = r.advertisementData.manufacturerData;
    if (mData.isNotEmpty && _vendorMap.containsKey(mData.keys.first)) {
      return "${_vendorMap[mData.keys.first]} Cihazı";
    }
    return "Bilinmeyen Cihaz";
  }

  void _toggleScan({bool forceStart = false}) async {
    try {
      if (_isScanning && !forceStart) {
        await FlutterBluePlus.stopScan();
        setState(() => _isScanning = false);
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(minutes: 15),
          continuousUpdates: true,
        );
        setState(() => _isScanning = true);
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final closeDevices = _scanResults.where((r) => r.rssi > -65).toList();
    final farDevices = _scanResults.where((r) => r.rssi <= -65).toList();
    closeDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    farDevices.sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // DÜZELTME: const kaldırıldı
                      Text("Sentinel", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: kTextPrimary)),
                      _isScanning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryGreen))
                          : IconButton(icon: const Icon(Icons.refresh, color: kPrimaryGreen), onPressed: () => _toggleScan(forceStart: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                if (closeDevices.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text("YAKIN MESAFE", style: TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: closeDevices.length,
                      itemBuilder: (context, index) => _buildCircleItem(closeDevices[index]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  // DÜZELTME: const kaldırıldı
                  child: Text("DİĞER SİNYALLER", style: TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: farDevices.length,
                    itemBuilder: (context, index) => _buildListItem(farDevices[index]),
                  ),
                ),
              ],
            ),
          ),

          if (_targetDevice != null) _buildFinderScreen(),
        ],
      ),
    );
  }

  Widget _buildCircleItem(ScanResult r) {
    return GestureDetector(
      onTap: () => _startTracking(r),
      child: Container(
        width: 80, margin: const EdgeInsets.only(right: 15),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kPrimaryGreen, width: 3), color: kCardColor),
            child: const Icon(Icons.radar, color: kPrimaryGreen),
          ),
          const SizedBox(height: 8),
          // DÜZELTME: const kaldırıldı
          Text(_getName(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: kTextPrimary)),
        ]),
      ),
    );
  }

  Widget _buildListItem(ScanResult r) {
    return ListTile(
      onTap: () => _startTracking(r),
      leading: const Icon(Icons.bluetooth, color: Colors.grey),
      title: Text(_getName(r), style: const TextStyle(color: Colors.white)),
      subtitle: Text(r.device.remoteId.str, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      trailing: Text("${r.rssi} dBm", style: const TextStyle(color: Colors.grey)),
    );
  }

  void _startTracking(ScanResult r) {
    FlutterBluePlus.stopScan().then((_) {
      FlutterBluePlus.startScan(continuousUpdates: true);
    });
    setState(() {
      _targetDevice = r;
      _smoothedRssi = -100;
      _lastRssi = -100;
      _directionText = "Yönü bulmak için yürüyün";
      _directionColor = kNeutralGrey;
      _directionIcon = Icons.directions_walk;
    });
  }

  Widget _buildFinderScreen() {
    final currentMatch = _scanResults.firstWhere(
            (r) => r.device.remoteId == _targetDevice?.device.remoteId, orElse: () => _targetDevice!
    );
    double dist = _calculateDistance(_smoothedRssi);
    String distStr = dist < 0.5 ? "0.1m" : "${dist.toStringAsFixed(1)}m";

    String mac = currentMatch.device.remoteId.str;
    String uuids = currentMatch.advertisementData.serviceUuids.join(", ");
    if (uuids.isEmpty) uuids = "Yok";

    return Container(
      color: Colors.black,
      width: double.infinity, height: double.infinity,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () {
                      _feedbackTimer?.cancel();
                      setState(() => _targetDevice = null);
                    },
                  ),
                  Column(children: [
                    // DÜZELTME: const kaldırıldı
                    Text("HEDEF", style: TextStyle(color: kTextSecondary, fontSize: 10, letterSpacing: 2)),
                    Text(_getName(currentMatch), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Spacer(),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _directionColor.withOpacity(0.1),
                  border: Border.all(color: _directionColor, width: 2)
              ),
              padding: const EdgeInsets.all(40),
              child: Icon(_directionIcon, size: 120, color: _directionColor),
            ),
            const SizedBox(height: 30),

            Text(distStr, style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: _directionColor, height: 1)),
            const SizedBox(height: 10),
            Text(_directionText, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: _directionColor, fontWeight: FontWeight.bold)),

            const Spacer(),

            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("SİNYAL VERİSİ", style: TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white10),
                _buildRow("MAC", mac),
                _buildRow("RSSI", "${currentMatch.rssi} dBm"),
                _buildRow("UUIDs", uuids),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      // DÜZELTME: const kaldırıldı
      Text(label, style: TextStyle(color: kTextSecondary, fontSize: 12)),
      Expanded(child: Text(val, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
    ]));
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }
}