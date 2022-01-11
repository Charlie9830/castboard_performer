import 'package:castboard_player/ApplicationSubtitle.dart';
import 'package:castboard_player/ApplicationTitle.dart';
import 'package:castboard_player/PackageInfoDisplay.dart';
import 'package:castboard_player/versionCodename.dart';
import 'package:flutter/material.dart';

class LoadingSplash extends StatelessWidget {
  final String status;
  const LoadingSplash({Key? key, this.status = 'Starting Up'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Positioned(
                  top: 16,
                  left: 16,
                  child:
                      Hero(tag: 'application-title', child: ApplicationTitle()),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                        tag: 'application-subtitle',
                        child: ApplicationSubtitle()),
                    SizedBox(height: 24),
                    SizedBox(
                        width: 400,
                        child: LinearProgressIndicator(
                          color: Colors.orangeAccent,
                        )),
                    SizedBox(height: 16),
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
          Positioned(left: 24, bottom: 24, child: PackageInfoDisplay()),
          Positioned(right: 24, bottom: 24, child: Text(kVersionCodename))
        ],
      ),
    );
  }
}
