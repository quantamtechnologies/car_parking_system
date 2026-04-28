import 'dart:html' as html;

Future<bool> printHtmlDocument(String htmlDocument) async {
  final printWindow = html.window.open('', '_blank', 'noopener,noreferrer');
  if (printWindow == null) {
    return false;
  }

  printWindow.document.open();
  printWindow.document.write(htmlDocument);
  printWindow.document.close();

  await Future<void>.delayed(const Duration(milliseconds: 250));
  printWindow.focus();
  printWindow.print();
  return true;
}
