# Sentinel: Advanced BLE Signal Intelligence & Tracking System

![Project Status](https://img.shields.io/badge/Status-Stable-success)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)
![License](https://img.shields.io/badge/License-MIT-purple)

**Sentinel** is a high-performance mobile security utility designed for real-time detection, analysis, and tracking of Bluetooth Low Energy (BLE) devices. Unlike standard scanners, Sentinel leverages sensor fusion algorithms (RSSI + Accelerometer + Magnetometer) to provide heuristic directional tracking and detailed signal forensics without requiring specialized hardware like UWB.

##  Key Capabilities

###  Spectral Radar Surveillance
* **Continuous Spectrum Scanning:** Utilizes aggressive scan modes to capture ephemeral BLE advertisements in real-time.
* **Proximity Sorting:** Automatically categorizes devices into dynamic range zones (Immediate, Near, Far) for rapid threat assessment.
* **Vendor Identification:** Integrated OUI database to instantly identify manufacturers (Apple, Samsung, Microsoft, Nordic, etc.) based on raw payload analysis.

###  Heuristic Precision Finding
A proprietary tracking interface designed for locating specific targets in complex environments:
* **Dynamic Trend Analysis:** Monitors RSSI variance relative to user motion intensity to determine directionality.
* **Haptic Feedback Loop:** Provides non-visual cues via variable-frequency vibration patterns as the signal strength increases.
* **Logarithmic Distance Estimation:** Converts raw signal strength (dBm) into estimated physical distance using calibrated path-loss models.

###  Signal Forensics
* **Deep Packet Inspection:** Extracts and visualizes Manufacturer Specific Data, Service UUIDs, and TX Power levels.
* **Jitter Smoothing:** Implements weighted average smoothing algorithms to stabilize signal fluctuations and eliminate noise.

##  Technical Architecture

Sentinel is built on a robust, type-safe architecture ensuring performance and stability:

* **Core Framework:** Flutter & Dart (Null-Safety)
* **Bluetooth Stack:** Low-latency interaction via `flutter_blue_plus`
* **Sensor Fusion:** Real-time motion analysis using `sensors_plus` & `flutter_compass`
* **UI/UX:** High-contrast "Dark Mode" interface optimized for field visibility.

##  Installation & Usage

### Prerequisites
* Android 5.0+ or iOS 12.0+ device.
* Location & Bluetooth permissions (Required for BLE scanning on Android 12+).

### Building from Source
```bash
git clone https://github.com/erogluyusuf/Universal-BLE-Radar.git
cd Universal-BLE-Radar
flutter pub get
flutter run --release
```

### Releases
Pre-compiled APKs are available in the `releases/` directory for immediate deployment.

##  Disclaimer
*Sentinel is intended for educational and legitimate security research purposes only. The developers assume no liability for misuse of this software.*

##  Contribution
Contributions are welcome. Please ensure all pull requests adhere to the existing architectural patterns and include relevant tests.

##  License
Distributed under the MIT License. See `LICENSE` for more information.

---
**Maintained by:** Yusuf Eroğlu
*See beyond the signal.*
