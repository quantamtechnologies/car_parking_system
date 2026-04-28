import 'package:intl/intl.dart';

import '../models.dart';
import 'receipt_printer_stub.dart'
    if (dart.library.html) 'receipt_printer_web.dart' as receipt_printer_impl;

Future<bool> printTransactionReceipt(TransactionRecord transaction) {
  final entry = transaction.entryTime;
  final exit = transaction.exitTime;
  final entryLabel =
      entry == null ? 'N/A' : DateFormat('dd MMM yyyy, hh:mm a').format(entry);
  final exitLabel =
      exit == null ? 'N/A' : DateFormat('dd MMM yyyy, hh:mm a').format(exit);
  final confirmedAt = transaction.payment?.confirmedAt;
  final confirmedLabel = confirmedAt == null
      ? 'N/A'
      : DateFormat('dd MMM yyyy, hh:mm a').format(confirmedAt);
  final durationLabel = _durationLabel(transaction.durationMinutes);

  final html = '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Receipt ${_escape(transaction.receiptNumber.isEmpty ? transaction.plateNumber : transaction.receiptNumber)}</title>
    <style>
      @page { size: A4; margin: 16mm; }
      body {
        margin: 0;
        background: #ffffff;
        color: #000000;
        font-family: Arial, Helvetica, sans-serif;
      }
      .page {
        max-width: 760px;
        margin: 0 auto;
        padding: 24px;
      }
      .receipt {
        border: 1px solid #000000;
        padding: 24px;
      }
      h1 {
        margin: 0 0 8px;
        font-size: 28px;
      }
      .subtitle {
        margin: 0 0 24px;
        font-size: 14px;
      }
      .section {
        margin-top: 18px;
      }
      .section-title {
        font-size: 13px;
        font-weight: 700;
        text-transform: uppercase;
        margin-bottom: 10px;
      }
      .row {
        display: flex;
        justify-content: space-between;
        gap: 16px;
        padding: 7px 0;
        border-bottom: 1px solid #d4d4d4;
        font-size: 15px;
      }
      .row:last-child {
        border-bottom: 0;
      }
      .label {
        color: #111111;
        font-weight: 700;
      }
      .value {
        color: #000000;
        text-align: right;
      }
      .total {
        margin-top: 20px;
        padding-top: 14px;
        border-top: 2px solid #000000;
        display: flex;
        justify-content: space-between;
        font-size: 20px;
        font-weight: 700;
      }
      .footnote {
        margin-top: 24px;
        font-size: 13px;
      }
      @media print {
        .page {
          padding: 0;
        }
      }
    </style>
  </head>
  <body>
    <div class="page">
      <div class="receipt">
        <h1>Smart Parking Receipt</h1>
        <p class="subtitle">Black text on white background, ready for A4 or POS-style printing.</p>
        <div class="section">
          <div class="section-title">Vehicle Details</div>
          ${_rowHtml('Receipt ID', transaction.receiptNumber.isEmpty ? 'Pending' : transaction.receiptNumber)}
          ${_rowHtml('Plate Number', transaction.plateNumber)}
          ${_rowHtml('Vehicle Type', transaction.vehicleTypeLabelText)}
          ${_rowHtml('Owner Name', transaction.ownerName)}
          ${_rowHtml('Phone Number', transaction.phoneNumber)}
        </div>
        <div class="section">
          <div class="section-title">Parking Details</div>
          ${_rowHtml('Entry Time', entryLabel)}
          ${_rowHtml('Exit Time', exitLabel)}
          ${_rowHtml('Duration', durationLabel)}
          ${_rowHtml('Payment Confirmed', confirmedLabel)}
        </div>
        <div class="section">
          <div class="section-title">Payment Details</div>
          ${_rowHtml('Amount Paid', money(transaction.amountPaid))}
          ${_rowHtml('Payment Method', transaction.paymentMethod)}
          ${_rowHtml('Payment Status', transaction.paymentStatus)}
        </div>
        <div class="total">
          <span>Total Paid</span>
          <span>${_escape(money(transaction.amountPaid))}</span>
        </div>
        <div class="footnote">Thank you for using Smart Parking.</div>
      </div>
    </div>
  </body>
</html>
''';

  return receipt_printer_impl.printHtmlDocument(html);
}

String _rowHtml(String label, String value) {
  return '<div class="row"><span class="label">${_escape(label)}</span><span class="value">${_escape(value)}</span></div>';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _durationLabel(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '${remaining}m';
  if (remaining == 0) return '${hours}h';
  return '${hours}h ${remaining}m';
}
