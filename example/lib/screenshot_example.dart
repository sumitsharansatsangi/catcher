import 'dart:io';

import 'package:catcher/catcher.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  final catcher = Catcher(rootWidget: const MyApp(), ensureInitialized: true);
  Directory? externalDir;
  if (Platform.isAndroid) {
    externalDir = await getExternalStorageDirectory();
    debugPrint(externalDir!.path);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    externalDir = await getApplicationDocumentsDirectory();
  }
  if (Platform.isLinux || Platform.isWindows) {
    externalDir = await getDownloadsDirectory();
  }
  var path = '';
  if (externalDir != null) {
    path = externalDir.path;
    debugPrint(path);
  } else {
    debugPrint("Screenshot won't work , sorry");
  }

  final debugOptions = CatcherOptions(
    DialogReportMode(),
    [
      HttpHandler(
        HttpRequestType.post,
        Uri.parse("https://kumpali.com/report/"),
        printLogs: true,
        // enableCustomParameters: true,
        enableStackTrace: true,
        enableApplicationParameters: true,
        enableDeviceParameters: true,
      )
      // EmailManualHandler(
      //   ['email1@email.com', 'email2@email.com'],
      //   emailTitle: 'Sample Title',
      //   emailHeader: 'Sample Header',
      //   printLogs: true,
      // ),
    ],
    // customParameters: <String, dynamic>{
    //   'Test': 'Test12345',
    //   'Test2': 'Test54321',
    // },
    screenshotsPath: path,
  );

  catcher.updateConfig(debugConfig: debugOptions);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Catcher.navigatorKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: CatcherScreenshot(
          catcher: Catcher.getInstance(),
          child: const ChildWidget(),
        ),
      ),
    );
  }
}

class ChildWidget extends StatelessWidget {
  const ChildWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: generateError,
      child: const Text('Generate error'),
    );
  }

  Future<void> generateError() async {
    Catcher.sendTestException();
  }
}
