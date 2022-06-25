import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PackageInfoDisplay extends StatefulWidget {
  const PackageInfoDisplay({Key? key}) : super(key: key);

  @override
  PackageInfoDisplayState createState() => PackageInfoDisplayState();
}

class PackageInfoDisplayState extends State<PackageInfoDisplay> {
  String appName = '';
  String version = '';
  String buildNumber = '';
  String buildSignature = '';
  String packageName = '';

  @override
  void initState() {
    super.initState();

    _getInfo();
  }

  @override
  Widget build(BuildContext context) {
    withStyle(String text) =>
        Text(text, style: Theme.of(context).textTheme.caption);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        withStyle(appName),
        withStyle('Version: $version'),
        withStyle('Build Number: $buildNumber'),
        withStyle('Build Signature: $buildSignature'),
        withStyle('Package Name: $packageName'),
      ],
    );
  }

  void _getInfo() async {
    final info = await PackageInfo.fromPlatform();

    setState(() {
      appName = info.appName;
      version = info.version;
      buildNumber = info.buildNumber;
      buildSignature = info.buildSignature;
      packageName = info.packageName;
    });
  }
}
