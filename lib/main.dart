import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_blue/flutter_blue.dart';

// =============================================================================
// C O N S T
// =============================================================================
const backgroundColor = Colors.white;
const primaryColor = Color(0xffceecd6);
const darkPrimaryColor = Color(0xff07393e);
const secondaryColor = Color(0xfffee39e);
const darkSecondaryColor = Color(0xfff6d74f);

// const backgrdColor = Color(0xfffcfaed);
// const primaryColor = Color(0xffaad6b3);
// const darkPrimaryColor = Color(0xff8bc497);
// const lightPrimaryColor = Color(0xffd8eddc);
// const secondaryColor = Color(0xfff8b4b5);
// const ligthSecondaryColor = Color(0xfffcdcdd);

const accentColor = Color(0xfff87b79);
const darkAccentColor = Color(0xffd55a5c);
const lightAccentColor = Color(0xfffbc3c2);

// =============================================================================
// M A I N
// =============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp firebaseApp = await Firebase.initializeApp();

  runApp(
    MaterialApp(
      title: 'Smatch home',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'Smatch home', app: firebaseApp),
    ),
  );
}

// =============================================================================
// C L A S S  MyHomePage
// =============================================================================
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title, this.app}) : super(key: key);

  final String title;
  final FirebaseApp app;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// =============================================================================
// C L A S S  _MyHomePageState
// =============================================================================
class _MyHomePageState extends State<MyHomePage> {
  // ---------------------------------------------------------------------------
  // P R O P E R T I E S
  // ---------------------------------------------------------------------------
  /// Interger or floating temperature value read from the Firebase backend.
  num _firebaseTemperature;
  // List<int> _thingyTemperature = <int>[];

  DatabaseError _firebaseError;
  DatabaseReference _tempFirebaseRef;
  StreamSubscription<Event> _instantTempListener;

  FlutterBlue _flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> _bleDevices = <BluetoothDevice>[];
  List<BluetoothService> _bleServices = <BluetoothService>[];
  BluetoothDevice _pinetimeDevice;
  // BluetoothDevice _thingyDevice;
  BluetoothCharacteristic _pinetimeTempCharact;

  // ---------------------------------------------------------------------------
  // M E T H O D S
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  /// Add a BLE device to the BLE devices list
  _addBleDeviceToList(final BluetoothDevice newBleDevice) {
    if (!_bleDevices.contains(newBleDevice)) {
      _bleDevices.add(newBleDevice);
    }

    // The new device is the Thingy board
    // if (newBleDevice.name == 'Thingy') {
    //   _bleDeviceConnection(newBleDevice);
    // }

    // The new device is the Pinetime
    if (newBleDevice.id.toString() == 'DF:BC:09:34:54:51') {
      _bleDeviceConnection(newBleDevice);
    }
  }

  // ---------------------------------------------------------------------------
  /// Connect to a BLE device
  _bleDeviceConnection(final BluetoothDevice bleDevice) async {
    _flutterBlue.stopScan();

    // Connection and services discovery
    try {
      await bleDevice.connect();
    } catch (e) {
      if (e.code != 'already_connected') {
        throw e;
      }
    } finally {
      _bleServices = await bleDevice.discoverServices();
    }

    // Thingy part
    // if (bleDevice.name == 'Thingy') {
    //   setState(
    //     () {
    //       _thingyDevice = bleDevice;
    //     },
    //   );

    //   // Listen the state of connection
    //   _thingyDevice.state.listen(
    //     (event) {
    //       print(event.toString());
    //       if (event.toString() == 'BluetoothDeviceState.disconnected') {
    //         setState(
    //           () {
    //             _thingyDevice = null;
    //             _thingyTemperature.clear();

    //             _flutterBlue.startScan();
    //           },
    //         );
    //       }
    //     },
    //   );

    //   // Characteritics discovery
    //   for (BluetoothService service in _bleServices) {
    //     for (BluetoothCharacteristic charact in service.characteristics) {
    //       // Thingy Temperature Characteristic within the Thingy Environment Service
    //       if (charact.uuid.toString() ==
    //           'ef680201-9b35-4933-9b10-52ffa9740042') {
    //         charact.value.listen(
    //           (value) {
    //             setState(
    //               () {
    //                 _thingyTemperature =
    //                     value; // value => [int part, float part]
    //               },
    //             );
    //           },
    //         );

    //         await charact.setNotifyValue(true);
    //       }
    //     }
    //   }
    // }

    // Pinetime part
    if (bleDevice.id.toString() == 'DF:BC:09:34:54:51') {
      setState(
        () {
          _pinetimeDevice = bleDevice;
        },
      );

      // Listen the state of connection
      _pinetimeDevice.state.listen(
        (event) {
          print(event.toString());
          if (event.toString() == 'BluetoothDeviceState.disconnected') {
            setState(
              () {
                _pinetimeDevice = null;

                _flutterBlue.startScan();
              },
            );
          }
        },
      );

      // Characteritics discovery
      for (BluetoothService service in _bleServices) {
        for (BluetoothCharacteristic charact in service.characteristics) {
          print(charact.uuid.toString());

          // Pinetime New Alert Characteristic (0x2A46) within the Alert Notification Service (0x1811)
          if (charact.uuid.toString() ==
              '00002a46-0000-1000-8000-00805f9b34fb') {
            _pinetimeTempCharact = charact;
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  /// Send to Pinetime the temperature from Firebase
  void _sendToPinetime(num value) async {
    if (_pinetimeDevice != null) {
      // Write the number of new alerts (0x00, 0x01),
      // then write a space character (0x20) due to the PineTime behavior,
      // and write the temperature value in ASCII character format.
      List<int> tempMsg = [0x00, 0x01, 0x20];
      tempMsg.addAll(value.toString().codeUnits);

      await _pinetimeTempCharact.write(tempMsg);
    }
  }

  // ---------------------------------------------------------------------------
  /// Initial state method.
  @override
  void initState() {
    super.initState();

    // Firebase part
    _tempFirebaseRef = FirebaseDatabase.instance
        .reference()
        .child('temperature')
        .child('instant');

    _tempFirebaseRef.keepSynced(true);

    _instantTempListener = _tempFirebaseRef.onValue.listen((Event event) {
      _firebaseError = null;

      setState(() {
        _firebaseTemperature = event.snapshot.value;
      });

      _sendToPinetime(_firebaseTemperature);
    }, onError: (Object o) {
      final DatabaseError error = o;

      setState(() {
        _firebaseError = error;
      });
      print(_firebaseError);
    });

    // BLE part
    _flutterBlue.connectedDevices.asStream().listen(
      (List<BluetoothDevice> devices) {
        for (BluetoothDevice device in devices) {
          _addBleDeviceToList(device);
        }
      },
    );

    _flutterBlue.scanResults.listen(
      (List<ScanResult> scanResults) {
        for (ScanResult result in scanResults) {
          _addBleDeviceToList(result.device);
        }
      },
    );

    _flutterBlue.startScan();
  }

  // ---------------------------------------------------------------------------
  /// Dispose method.
  @override
  void dispose() {
    super.dispose();
    _instantTempListener.cancel();

    // if (_thingyDevice != null) {
    //   _thingyDevice.disconnect();
    //   _thingyDevice = null;
    // }

    if (_pinetimeDevice != null) {
      _pinetimeDevice.disconnect();
      _pinetimeDevice = null;
    }
  }

  // ---------------------------------------------------------------------------
  /// Build method.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkPrimaryColor,
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(
            color: primaryColor,
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            children: [
              Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      _firebaseTemperature != null
                          ? Icons.cloud_outlined
                          : Icons.cloud_off_sharp,
                      color: _firebaseTemperature != null
                          ? primaryColor
                          : darkAccentColor,
                    ),
                    SizedBox(
                      width: 5.0,
                    ),
                    // Icon(
                    //   Icons.cast,
                    //   color: _thingyDevice != null
                    //       ? primaryColor
                    //       : darkAccentColor,
                    // ),
                    // SizedBox(
                    //   width: 5.0,
                    // ),
                    Icon(
                      Icons.watch,
                      color: _pinetimeDevice != null
                          ? primaryColor
                          : darkAccentColor,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: darkPrimaryColor,
                      width: 3,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Firebase temperature
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.thermostat_outlined,
                            color: primaryColor,
                            size: 30,
                          ),
                          Text(
                            _firebaseTemperature != null
                                ? '$_firebaseTemperature°C'
                                : '--.-',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Thingy temperature
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   crossAxisAlignment: CrossAxisAlignment.center,
                      //   children: [
                      //     Icon(
                      //       Icons.thermostat_outlined,
                      //       color: primaryColor,
                      //       size: 30,
                      //     ),
                      //     Text(
                      //       _thingyTemperature.isEmpty != true
                      //           ? _thingyTemperature.join('.') + '°C'
                      //           : '--.-',
                      //       style: TextStyle(
                      //         color: primaryColor,
                      //         fontSize: 24.0,
                      //         fontWeight: FontWeight.bold,
                      //       ),
                      //     ),
                      //   ],
                      // ),
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
