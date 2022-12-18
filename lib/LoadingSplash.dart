import 'package:castboard_performer/ApplicationSubtitle.dart';
import 'package:castboard_performer/ApplicationTitle.dart';
import 'package:castboard_performer/PackageInfoDisplay.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/material.dart';

class LoadingSplash extends StatelessWidget {
  final String status;
  final bool criticalError;
  const LoadingSplash(
      {Key? key, this.status = 'Starting Up', this.criticalError = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    print(Theme.of(context).scaffoldBackgroundColor);
    return Material(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                const Positioned(
                  top: 16,
                  left: 16,
                  child:
                      Hero(tag: 'application-title', child: ApplicationTitle()),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Hero(
                        tag: 'application-subtitle',
                        child: ApplicationSubtitle()),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: 400,
                        child: LinearProgressIndicator(
                          value: criticalError ? 0 : null,
                          color: Colors.orangeAccent,
                        )),
                    const SizedBox(height: 16),
                    Text(status,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2!
                            .copyWith(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(left: 24, bottom: 24, child: PackageInfoDisplay()),
          const Positioned(right: 24, bottom: 24, child: Text(kVersionCodename))
        ],
      ),
    );
  }
}
