import 'package:castboard_player/ConfigViewer.dart';
import 'package:castboard_player/Player.dart';
import 'package:castboard_player/RouteNames.dart';
import 'package:castboard_player/server/Server.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(AppRoot());
}

Server server;

class AppRoot extends StatefulWidget {
  AppRoot({Key key}) : super(key: key);

  @override
  _AppRootState createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();

    server = Server(
      address: '0.0.0.0',
      port: 8080,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Castboard Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
        accentColor: Colors.amber,
      ),
      initialRoute: RouteNames.configViewer,
      routes: {
        RouteNames.player: (_) => Player(),
        RouteNames.configViewer: (_) => ConfigViewer(),
      },
    );
  }

  void initializeServer() async {
    if (server != null) {
      await server.initalize();
      print('Server Ready');
    }
  }

  @override
  void dispose() {
    if (server != null) {
      server.shutdown();
    }
    super.dispose();
  }
}
