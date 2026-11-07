import 'package:web/web.dart' as web;

/// Opens a game page full screen in this browser tab.
void openWebPage(String path) => web.window.location.assign(path);
