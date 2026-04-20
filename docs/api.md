# API Map

## Authentication

- `POST /api/auth/login/`
- `POST /api/auth/refresh/`
- `POST /api/auth/logout/`
- `GET /api/auth/me/`
- `GET /api/auth/sessions/`

## Camera

- `POST /api/camera/anpr/recognize/`

## Parking

- `GET /api/parking/vehicles/`
- `POST /api/parking/vehicles/quick-register/`
- `GET /api/parking/zones/`
- `GET /api/parking/slots/`
- `GET /api/parking/sessions/`
- `GET /api/parking/sessions/active/`
- `GET /api/parking/sessions/overview/`
- `POST /api/parking/sessions/entry/`
- `POST /api/parking/sessions/exit/`
- `POST /api/parking/sessions/{id}/force_exit/`

## Billing

- `GET /api/billing/pricing/`
- `GET /api/billing/pricing/current/`
- `GET /api/billing/pricing/history/`
- `POST /api/billing/pricing/`
- `GET /api/billing/payments/`
- `POST /api/billing/payments/cash/`
- `GET /api/billing/cash-shifts/`
- `POST /api/billing/cash-shifts/open/`
- `POST /api/billing/cash-shifts/close/`

## Analytics

- `GET /api/analytics/dashboard/`
- `GET /api/analytics/alerts/`
- `POST /api/analytics/alerts/refresh/`
- `POST /api/analytics/chat/`

## Audit and Config

- `GET /api/audit/logs/`
- `GET /api/config/settings/`

