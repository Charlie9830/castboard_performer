import 'package:castboard_performer/models/understudy_session_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UnderstudySessionDisplay extends StatelessWidget {
  final List<UnderstudySessionModel> sessions;
  const UnderstudySessionDisplay({Key? key, this.sessions = const []})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Understudies"),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          Text("None connected", style: Theme.of(context).textTheme.bodySmall),
        if (sessions.isNotEmpty)
          Card(
            child: ListView(
              shrinkWrap: true,
              children: sessions
                  .map((session) => ListTile(
                        dense: true,
                        leading: Tooltip(
                          message:
                              session.active ? 'Connected' : 'Disconnected',
                          child: session.active
                              ? const Icon(Icons.smart_display,
                                  color: Colors.green)
                              : const Icon(Icons.tv_off, color: Colors.yellow),
                        ),
                        title: Text(session.userAgent.isNotEmpty
                            ? session.userAgent
                            : 'Display'),
                        subtitle: Text(
                            _formatConnectionTime(session.connectionTimestamp)),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  String _formatConnectionTime(DateTime timestamp) {
    final formatter = DateFormat('MMMd');
    return 'Joined ${formatter.format(timestamp)} at ${timestamp.hour}:${timestamp.minute}';
  }
}
