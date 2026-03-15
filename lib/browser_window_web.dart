// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool get supportsTextFileDownload => true;

bool openRouteInNewWindow(String route, {String windowName = 'grocery-trip'}) {
  final Uri target = Uri.base.replace(fragment: route);
  html.window.open(target.toString(), windowName);
  return true;
}

bool openExternalUrl(String url, {String windowName = '_blank'}) {
  html.window.open(url, windowName);
  return true;
}

bool downloadTextFile({required String filename, required String contents}) {
  final html.Blob blob = html.Blob(<String>[
    contents,
  ], 'text/plain;charset=utf-8');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
