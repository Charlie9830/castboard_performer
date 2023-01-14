import 'package:castboard_performer/constants.dart';

/// Returns true if the provided [port] number is within the allowed range.
bool validateServerPort(int port) {
  return port >= kLowestPort && port <= kHightestPort;
}
