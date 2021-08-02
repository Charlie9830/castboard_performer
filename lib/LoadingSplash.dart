import 'package:flutter/material.dart';

class LoadingSplash extends StatelessWidget {
  final String status;
  const LoadingSplash({Key? key, this.status = 'Starting Up'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                  tag: 'title',
                  child: Text('Castboard',
                      style: Theme.of(context).textTheme.headline1)),
              SizedBox(
                  width: 512,
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
        ),
      ),
    );
  }
}
