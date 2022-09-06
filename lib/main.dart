import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

late final SharedPreferences preferences;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) =>
              host == "192.168.0.95";
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  preferences = await SharedPreferences.getInstance();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebSocketChannel socket;

  Offset? _dragDelta;

  @override
  void initState() {
    super.initState();

    final name = base64Encode("dark-remote".codeUnits);

    socket = WebSocketChannel.connect(
      Uri(
        scheme: "wss",
        host: "192.168.0.95",
        port: 8002,
        path: "/api/v2/channels/samsung.remote.control",
        queryParameters: {
          "name": name,
          "token": preferences.getString("token"),
        },
      ),
    );

    socket.stream.listen((event) {
      print(event);

      try {
        final json = jsonDecode(event);
        final newToken = json["data"]["token"];

        print("got new token $newToken");
        preferences.setString("token", newToken);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dark Remote"),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () {
              _pressKey("KEY_POWER");
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text("Back"),
                onTap: () => _pressKey("KEY_RETURN"),
              ),
              ListTile(
                title: const Text("Home"),
                onTap: () => _pressKey("KEY_HOME"),
              ),
              ListTile(
                title: const Text("Play / Pause"),
                onTap: () => _pressKey("KEY_HDMI"),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => _dragDelta = Offset.zero,
              onPanUpdate: (d) {
                _dragDelta = _dragDelta! + d.delta;

                const threshold = 80.0;

                if (_dragDelta!.distance > threshold) {
                  HapticFeedback.selectionClick();

                  final dir = (_dragDelta!.direction / pi * 2 + 0.5).floor();
                  switch (dir) {
                    case 2:
                    case -2:
                      _pressKey("KEY_LEFT");
                      _dragDelta = _dragDelta!.translate(threshold, 0);
                      break;
                    case -1:
                      _pressKey("KEY_UP");
                      _dragDelta = _dragDelta!.translate(0, threshold);
                      break;
                    case 0:
                      _pressKey("KEY_RIGHT");
                      _dragDelta = _dragDelta!.translate(-threshold, 0);
                      break;
                    case 1:
                      _pressKey("KEY_DOWN");
                      _dragDelta = _dragDelta!.translate(0, -threshold);
                      break;
                  }
                }
              },
              onPanEnd: (_) => _dragDelta = null,
              onPanCancel: () => _dragDelta = null,
              onTap: () => _pressKey("KEY_ENTER"),
            ),
          ),
        ],
      ),
    );
  }

  void _pressKey(String key) {
    print("pressing $key");

    socket.sink.add(jsonEncode(
      {
        "method": "ms.remote.control",
        "params": {
          "Cmd": "Click",
          "DataOfCmd": key,
          "Option": "false",
          "TypeOfRemote": "SendRemoteKey"
        }
      },
    ));
  }
}
