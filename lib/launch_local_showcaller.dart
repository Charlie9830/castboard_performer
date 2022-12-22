import 'package:castboard_performer/server/Server.dart';
import 'package:url_launcher/url_launcher.dart';

void launchLocalShowcaller() {
  launchUrl(Uri.http('localhost:$kServerPort'));
}
