import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wakelock/wakelock.dart';

late final SharedPreferences preferences;

const applications = {
  "youtube": "111299001912",
  "spotify": "3201606009684",
};

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
      theme: ThemeData(primarySwatch: Colors.purple),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        dividerColor: Colors.purple,
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

    Wakelock.enable();

    final name = base64Encode("dark-remote".codeUnits);

    print("connecting...");
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

        if (newToken != null) {
          print("got new token $newToken");
          preferences.setString("token", newToken);
        }
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
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text("YouTube", textAlign: TextAlign.center),
                  onTap: () async {
                    final res = await Dio().post(
                      "http://192.168.0.95:8001/api/v2/applications/" +
                          applications["youtube"]!,
                    );

                    inspect(res.data);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text("Spotify", textAlign: TextAlign.center),
                  onTap: () async {
                    final res = await Dio().post(
                      "http://192.168.0.95:8001/api/v2/applications/" +
                          applications["spotify"]!,
                    );

                    inspect(res.data);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text("HDMI", textAlign: TextAlign.center),
                  onTap: () => _pressKey("KEY_HDMI"),
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onVerticalDragStart: (_) => _dragDelta = Offset.zero,
                    onVerticalDragUpdate: (d) {
                      _dragDelta = _dragDelta! + d.delta;

                      const threshold = 30.0;

                      if (_dragDelta!.distance > threshold) {
                        final dir =
                            (_dragDelta!.direction / pi * 2 + 0.5).floor();
                        switch (dir) {
                          case -1:
                            _pressKey("KEY_VOLUP");
                            _dragDelta = _dragDelta!.translate(0, threshold);
                            break;
                          case 1:
                            _pressKey("KEY_VOLDOWN");
                            _dragDelta = _dragDelta!.translate(0, -threshold);
                            break;
                        }
                      }
                    },
                    onVerticalDragEnd: (_) => _dragDelta = null,
                    onVerticalDragCancel: () => _dragDelta = null,
                    onTap: () => _pressKey("KEY_MUTE"),
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onPanStart: (_) => _dragDelta = Offset.zero,
                    onPanUpdate: (d) {
                      _dragDelta = _dragDelta! + d.delta;

                      const threshold = 60.0;

                      if (_dragDelta!.distance > threshold) {
                        final dir =
                            (_dragDelta!.direction / pi * 2 + 0.5).floor();
                        switch (dir) {
                          case 2:
                          case -2:
                            _pressKey("KEY_LEFT");
                            _dragDelta = _dragDelta!
                                .translate(threshold, -_dragDelta!.dy);
                            break;
                          case -1:
                            _pressKey("KEY_UP");
                            _dragDelta = _dragDelta!
                                .translate(-_dragDelta!.dx, threshold);
                            break;
                          case 0:
                            _pressKey("KEY_RIGHT");
                            _dragDelta = _dragDelta!
                                .translate(-threshold, -_dragDelta!.dy);
                            break;
                          case 1:
                            _pressKey("KEY_DOWN");
                            _dragDelta = _dragDelta!
                                .translate(-_dragDelta!.dx, -threshold);
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
          ),
          const Divider(),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    child: const Center(child: Icon(Icons.arrow_back)),
                    onTap: () => _pressKey("KEY_RETURN"),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    child: const Center(child: Icon(Icons.home_outlined)),
                    onTap: () => _pressKey("KEY_HOME"),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    child: const Center(child: Icon(Icons.pause)),
                    onTap: () => _pressKey("KEY_ENTER"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pressKey(Object key) {
    print("pressing $key");

    HapticFeedback.lightImpact();

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
