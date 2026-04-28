import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<bool> printHtmlDocument(String htmlDocument) async {
  final printWindow = html.window.open('', '_blank', 'noopener,noreferrer');
  if (printWindow == null) {
    return false;
  }

  final document = js_util.getProperty<Object?>(printWindow, 'document');
  if (document == null) {
    return false;
  }

  js_util.callMethod<void>(document, 'open', const []);
  js_util.callMethod<void>(document, 'write', <Object>[htmlDocument]);
  js_util.callMethod<void>(document, 'close', const []);

  await Future<void>.delayed(const Duration(milliseconds: 250));
  js_util.callMethod<void>(printWindow, 'focus', const []);
  js_util.callMethod<void>(printWindow, 'print', const []);
  return true;
}
