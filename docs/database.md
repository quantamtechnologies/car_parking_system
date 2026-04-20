# PostgreSQL Schema

## `accounts_user`

- `id`
- `username`
- `role`
- `phone_number`
- `employee_code`
- `is_force_password_change`
- auth fields inherited from `AbstractUser`

## `accounts_sessionlog`

- `user_id`
- `login_at`
- `logout_at`
- `is_active`
- `refresh_jti`
- `ip_address`
- `device_info`

## `parking_vehicle`

- `plate_number`
- `vehicle_type`
- `owner_name`
- `phone_number`
- `is_active`

## `parking_parkingzone`

- `name`
- `zone_type`
- `priority`
- `is_active`

## `parking_parkingslot`

- `zone_id`
- `code`
- `status`
- `is_manual_only`

## `parking_parkingsession`

- `vehicle_id`
- `slot_id`
- `entry_by_id`
- `exit_by_id`
- `entry_scan_id`
- `exit_scan_id`
- `entry_time`
- `exit_time`
- `status`
- `pricing_snapshot`
- `duration_minutes`
- `base_fee`
- `rate_per_hour`
- `grace_period_minutes`
- `extra_charges`
- `penalty_amount`
- `daily_max_cap`
- `total_fee`
- `amount_paid`
- `manual_override_by_id`
- `manual_override_reason`

## `billing_pricingpolicy`

- `name`
- `base_fee`
- `hourly_rate`
- `grace_period_minutes`
- `overdue_penalty`
- `daily_max_cap`
- `special_rules`
- `is_active`
- `version`
- `effective_from`
- `effective_to`

## `billing_cashshift`

- `cashier_id`
- `opened_by_id`
- `closed_by_id`
- `status`
- `opened_at`
- `closed_at`
- `opening_cash`
- `expected_cash`
- `actual_cash`
- `difference`

## `billing_payment`

- `session_id`
- `cashier_id`
- `cash_shift_id`
- `method`
- `status`
- `amount_due`
- `amount_tendered`
- `change_due`
- `receipt_number`
- `notes`
- `confirmed_at`

## `camera_ocrscan`

- `image`
- `original_filename`
- `source`
- `raw_text`
- `candidate_plates`
- `detected_plate`
- `confirmed_plate`
- `confidence`
- `is_confirmed`
- `manual_entry`

## `analytics_anomalyalert`

- `code`
- `title`
- `description`
- `severity`
- `status`
- `category`
- `actual_value`
- `threshold_value`
- `evidence`

## `audit_auditlog`

- `actor_id`
- `action`
- `entity_type`
- `entity_id`
- `before_data`
- `after_data`
- `metadata`
- `reason`
- `ip_address`

