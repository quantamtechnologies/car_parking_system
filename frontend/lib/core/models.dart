import 'package:intl/intl.dart';

String _asString(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;
int _asInt(dynamic value, [int fallback = 0]) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
double _asDouble(dynamic value, [double fallback = 0]) => value is double
    ? value
    : double.tryParse(value?.toString() ?? '') ?? fallback;
List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.role,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phoneNumber = '',
    this.employeeCode = '',
    this.isSuperuser = false,
  });

  final int id;
  final String username;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String employeeCode;
  final bool isSuperuser;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: _asInt(json['id']),
        username: _asString(json['username']),
        role: _asString(json['role']),
        firstName: _asString(json['first_name']),
        lastName: _asString(json['last_name']),
        email: _asString(json['email']),
        phoneNumber: _asString(json['phone_number']),
        employeeCode: _asString(json['employee_code']),
        isSuperuser: json['is_superuser'] == true,
      );

  bool get isAdmin => isSuperuser || role.trim().toUpperCase() == 'ADMIN';

  String get displayRole => isAdmin ? 'ADMIN' : role.trim();

  String get displayName => [firstName, lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ')
          .trim()
          .isNotEmpty
      ? [firstName, lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ')
          .trim()
      : username;
}

class OcrResult {
  const OcrResult({
    required this.id,
    required this.detectedPlate,
    required this.confidence,
    required this.candidatePlates,
    required this.manualEntryRequired,
    required this.imageUrl,
    required this.rawText,
  });

  final int id;
  final String detectedPlate;
  final double confidence;
  final List<String> candidatePlates;
  final bool manualEntryRequired;
  final String imageUrl;
  final String rawText;

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        id: _asInt(json['id']),
        detectedPlate: _asString(json['detected_plate']),
        confidence: _asDouble(json['confidence']),
        candidatePlates: _asStringList(json['candidate_plates']),
        manualEntryRequired: json['manual_entry_required'] == true,
        imageUrl: _asString(json['image_url']),
        rawText: _asString(json['raw_text']),
      );
}

class ParkingSessionSummary {
  const ParkingSessionSummary({
    required this.id,
    required this.status,
    required this.plateNumber,
    required this.vehicleType,
    required this.ownerName,
    required this.phoneNumber,
    required this.slotCode,
    required this.zoneName,
    required this.totalFee,
    required this.amountPaid,
    required this.entryTime,
    required this.exitTime,
    required this.durationMinutes,
    required this.baseFee,
    required this.ratePerHour,
    required this.gracePeriodMinutes,
    required this.extraCharges,
    required this.penaltyAmount,
    required this.dailyMaxCap,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String status;
  final String plateNumber;
  final String vehicleType;
  final String ownerName;
  final String phoneNumber;
  final String slotCode;
  final String zoneName;
  final double totalFee;
  final double amountPaid;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int durationMinutes;
  final double baseFee;
  final double ratePerHour;
  final int gracePeriodMinutes;
  final double extraCharges;
  final double penaltyAmount;
  final double? dailyMaxCap;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ParkingSessionSummary.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map<String, dynamic>? ?? const {});
    final slot = (json['slot'] as Map<String, dynamic>? ?? const {});
    final zone = (slot['zone'] as Map<String, dynamic>? ?? const {});
    return ParkingSessionSummary(
      id: _asInt(json['id']),
      status: _asString(json['status']),
      plateNumber: _asString(vehicle['plate_number']),
      vehicleType: _asString(vehicle['vehicle_type'], 'CAR'),
      ownerName: _asString(vehicle['owner_name']),
      phoneNumber: _asString(vehicle['phone_number']),
      slotCode: _asString(slot['code']),
      zoneName: _asString(zone['name']),
      totalFee: _asDouble(json['total_fee']),
      amountPaid: _asDouble(json['amount_paid']),
      entryTime: DateTime.tryParse(_asString(json['entry_time'])),
      exitTime: DateTime.tryParse(_asString(json['exit_time'])),
      durationMinutes: _asInt(json['duration_minutes']),
      baseFee: _asDouble(json['base_fee']),
      ratePerHour: _asDouble(json['rate_per_hour']),
      gracePeriodMinutes: _asInt(json['grace_period_minutes']),
      extraCharges: _asDouble(json['extra_charges']),
      penaltyAmount: _asDouble(json['penalty_amount']),
      dailyMaxCap: json['daily_max_cap'] == null
          ? null
          : _asDouble(json['daily_max_cap']),
      createdAt: DateTime.tryParse(_asString(json['created_at'])),
      updatedAt: DateTime.tryParse(_asString(json['updated_at'])),
    );
  }

  String get displayVehicleType => vehicleTypeLabel(vehicleType);

  String get ownerDisplay =>
      ownerName.trim().isEmpty ? 'No owner name added' : ownerName;

  String get phoneDisplay =>
      phoneNumber.trim().isEmpty ? 'No phone number added' : phoneNumber;

  bool get isActiveLike =>
      status.toUpperCase() == 'ACTIVE' ||
      status.toUpperCase() == 'PENDING_PAYMENT';
}

String vehicleTypeLabel(String value) {
  switch (value.toUpperCase()) {
    case 'SUV':
      return 'SUV';
    case 'VAN':
      return 'Van';
    case 'TRUCK':
      return 'Truck';
    case 'BIKE':
      return 'Motorbike';
    case 'OTHER':
      return 'Other';
    case 'CAR':
    default:
      return 'Car';
  }
}

class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.plateNumber,
    required this.vehicleType,
    required this.ownerName,
    required this.phoneNumber,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String plateNumber;
  final String vehicleType;
  final String ownerName;
  final String phoneNumber;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VehicleRecord.fromJson(Map<String, dynamic> json) => VehicleRecord(
        id: _asInt(json['id']),
        plateNumber: _asString(json['plate_number']),
        vehicleType: _asString(json['vehicle_type'], 'CAR'),
        ownerName: _asString(json['owner_name']),
        phoneNumber: _asString(json['phone_number']),
        isActive: json['is_active'] == true,
        createdAt: DateTime.tryParse(_asString(json['created_at'])),
        updatedAt: DateTime.tryParse(_asString(json['updated_at'])),
      );

  String get displayVehicleType => vehicleTypeLabel(vehicleType);

  String get ownerDisplay =>
      ownerName.trim().isEmpty ? 'No owner name added' : ownerName;

  String get phoneDisplay =>
      phoneNumber.trim().isEmpty ? 'No phone number added' : phoneNumber;
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.carsPerDay,
    required this.revenuePerDay,
    required this.averageCarsPerDay,
    required this.occupancyRate,
    required this.activeSessions,
    required this.pendingPayments,
    required this.openCashShifts,
    required this.alerts,
    required this.peakHours,
    required this.staffPerformance,
  });

  final int carsPerDay;
  final double revenuePerDay;
  final double averageCarsPerDay;
  final double occupancyRate;
  final int activeSessions;
  final int pendingPayments;
  final int openCashShifts;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> peakHours;
  final List<Map<String, dynamic>> staffPerformance;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) =>
      DashboardMetrics(
        carsPerDay: _asInt(json['cars_per_day']),
        revenuePerDay: _asDouble(json['revenue_per_day']),
        averageCarsPerDay: _asDouble(json['average_cars_per_day']),
        occupancyRate: _asDouble(json['occupancy_rate']),
        activeSessions: _asInt(json['active_sessions']),
        pendingPayments: _asInt(json['pending_payments']),
        openCashShifts: _asInt(json['open_cash_shifts']),
        alerts: (json['alerts'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        peakHours: (json['peak_hours'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        staffPerformance: (json['staff_performance'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

class AlertItem {
  const AlertItem({
    required this.code,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.category,
    required this.actualValue,
    required this.thresholdValue,
  });

  final String code;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String category;
  final String actualValue;
  final String thresholdValue;

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        code: _asString(json['code']),
        title: _asString(json['title']),
        description: _asString(json['description']),
        severity: _asString(json['severity']),
        status: _asString(json['status']),
        category: _asString(json['category']),
        actualValue: _asString(json['actual_value']),
        thresholdValue: _asString(json['threshold_value']),
      );
}

class PricingPolicyDto {
  const PricingPolicyDto({
    required this.id,
    required this.name,
    required this.baseFee,
    required this.hourlyRate,
    required this.gracePeriodMinutes,
    required this.overduePenalty,
    required this.dailyMaxCap,
    required this.specialRules,
    required this.isActive,
    required this.version,
  });

  final int id;
  final String name;
  final double baseFee;
  final double hourlyRate;
  final int gracePeriodMinutes;
  final double overduePenalty;
  final double? dailyMaxCap;
  final Map<String, dynamic> specialRules;
  final bool isActive;
  final int version;

  factory PricingPolicyDto.fromJson(Map<String, dynamic> json) =>
      PricingPolicyDto(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        baseFee: _asDouble(json['base_fee']),
        hourlyRate: _asDouble(json['hourly_rate']),
        gracePeriodMinutes: _asInt(json['grace_period_minutes']),
        overduePenalty: _asDouble(json['overdue_penalty']),
        dailyMaxCap: json['daily_max_cap'] == null
            ? null
            : _asDouble(json['daily_max_cap']),
        specialRules: Map<String, dynamic>.from(
            json['special_rules'] as Map? ?? const {}),
        isActive: json['is_active'] == true,
        version: _asInt(json['version']),
      );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.sessionId,
    required this.session,
    required this.cashierId,
    required this.cashShiftId,
    required this.method,
    required this.status,
    required this.amountDue,
    required this.amountTendered,
    required this.changeDue,
    required this.receiptNumber,
    required this.notes,
    required this.confirmedAt,
  });

  final int id;
  final int sessionId;
  final ParkingSessionSummary? session;
  final int cashierId;
  final int? cashShiftId;
  final String method;
  final String status;
  final double amountDue;
  final double amountTendered;
  final double changeDue;
  final String receiptNumber;
  final String notes;
  final DateTime? confirmedAt;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final sessionValue = json['session'];
    final sessionMap = sessionValue is Map<String, dynamic>
        ? sessionValue
        : sessionValue is Map
            ? Map<String, dynamic>.from(sessionValue)
            : null;
    return PaymentRecord(
      id: _asInt(json['id']),
      sessionId: sessionMap == null
          ? _asInt(json['session'])
          : _asInt(sessionMap['id']),
      session: sessionMap == null
          ? null
          : ParkingSessionSummary.fromJson(sessionMap),
      cashierId: _asInt(json['cashier']),
      cashShiftId:
          json['cash_shift'] == null ? null : _asInt(json['cash_shift']),
      method: _asString(json['method']),
      status: _asString(json['status']),
      amountDue: _asDouble(json['amount_due']),
      amountTendered: _asDouble(json['amount_tendered']),
      changeDue: _asDouble(json['change_due']),
      receiptNumber: _asString(json['receipt_number']),
      notes: _asString(json['notes']),
      confirmedAt: DateTime.tryParse(_asString(json['confirmed_at'])),
    );
  }

  String get methodLabel {
    switch (method.toUpperCase()) {
      case 'OVERRIDE':
        return 'Override';
      case 'CASH':
      default:
        return 'Cash';
    }
  }

  String get paymentStatusLabel {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'PAID';
      case 'OVERRIDDEN':
        return 'OVERRIDDEN';
      case 'VOIDED':
        return 'VOIDED';
      default:
        return status.toUpperCase();
    }
  }
}

class TransactionRecord {
  const TransactionRecord({
    required this.session,
    this.payment,
  });

  final ParkingSessionSummary session;
  final PaymentRecord? payment;

  String get plateNumber => session.plateNumber;
  String get vehicleType => session.vehicleType;
  String get vehicleTypeLabelText => session.displayVehicleType;
  String get ownerName => session.ownerDisplay;
  String get phoneNumber => session.phoneDisplay;
  DateTime? get entryTime => session.entryTime;
  DateTime? get exitTime => payment?.session?.exitTime ?? session.exitTime;
  int get durationMinutes {
    final sessionDuration =
        payment?.session?.durationMinutes ?? session.durationMinutes;
    if (sessionDuration > 0) return sessionDuration;
    if (entryTime != null && exitTime != null) {
      return exitTime!.difference(entryTime!).inMinutes;
    }
    return 0;
  }

  double get amount => payment?.amountDue ?? session.totalFee;
  double get amountPaid => payment?.amountDue ?? session.amountPaid;
  String get paymentMethod => payment?.methodLabel ?? 'Cash';
  String get paymentStatus {
    if (payment != null) return payment!.paymentStatusLabel;
    final status = session.status.toUpperCase();
    if (status == 'CLOSED') return 'PAID';
    if (status == 'PENDING_PAYMENT') return 'PENDING';
    return status;
  }

  String get statusLabel {
    final status = session.status.toUpperCase();
    if (status == 'ACTIVE') return 'ACTIVE';
    if (status == 'PENDING_PAYMENT') return 'PENDING';
    return paymentStatus;
  }

  String get receiptNumber => payment?.receiptNumber ?? '';
  bool get hasReceipt => receiptNumber.trim().isNotEmpty;
}

String money(double value) => NumberFormat.currency(symbol: 'R').format(value);
