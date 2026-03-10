bool get supportsTextFileDownload => false;

bool openRouteInNewWindow(String route, {String windowName = 'grocery-trip'}) {
  return false;
}

bool downloadTextFile({required String filename, required String contents}) {
  return false;
}
