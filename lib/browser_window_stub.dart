bool get supportsTextFileDownload => false;

bool openRouteInNewWindow(String route, {String windowName = 'grocery-trip'}) {
  return false;
}

bool openExternalUrl(String url, {String windowName = '_blank'}) {
  return false;
}

bool downloadTextFile({required String filename, required String contents}) {
  return false;
}
