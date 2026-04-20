# Smart Parking POS

Production-ready smart parking and POS scaffold with:

- Flutter mobile/tablet POS app and responsive web dashboard
- Django REST API backend
- PostgreSQL schema and pricing history
- Camera-assisted ANPR flow with OpenCV + Tesseract on the server
- Render deployment for the backend
- Netlify deployment for the Flutter web dashboard

## Repository Layout

```text
.
├── apps/                 # Django domain apps
├── project/              # Django project settings and URLs
├── frontend/            # Flutter app
├── docs/                # Architecture, schema, API, deployment notes
├── requirements.txt
├── render.yaml
└── .env.example
```

## Core Modules

- Authentication and role control: admin, cashier, security
- Vehicle entry and exit workflows
- Human-in-the-loop plate recognition
- Parking slot management and zone support
- Admin-controlled pricing and historical rate snapshots
- Cash payment confirmation and shift reconciliation
- Analytics, anomaly detection, and chatbot queries
- Audit logging for every high-value action

## API Overview

- `POST /api/auth/login/`
- `POST /api/auth/refresh/`
- `POST /api/auth/logout/`
- `GET /api/auth/me/`
- `POST /api/camera/anpr/recognize/`
- `POST /api/parking/sessions/entry/`
- `POST /api/parking/sessions/exit/`
- `GET /api/parking/sessions/overview/`
- `GET /api/parking/sessions/active/`
- `POST /api/billing/payments/cash/`
- `GET /api/billing/pricing/current/`
- `GET /api/analytics/dashboard/`
- `GET /api/analytics/alerts/`
- `POST /api/analytics/chat/`

See [docs/api.md](docs/api.md) for the full route map.

## Deployment

- Backend: Render, using `gunicorn project.wsgi:application`
- Web dashboard: Netlify, using Flutter web build output
- Database: Render PostgreSQL or another managed PostgreSQL instance. SQLite is only a local-development fallback and should not be used for deployment.

See [docs/deployment.md](docs/deployment.md).

## Local Environment

Copy `.env.example` to `.env` and set the real values.

For the Flutter web build, run it from `frontend/` and pass the API URL at compile time:

```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

If `API_BASE_URL` is missing in a release build, the app shows a deployment warning instead of silently pointing at localhost.

## Production Notes

- Use HTTPS everywhere
- Keep `SECRET_KEY` and `DATABASE_URL` out of source control
- Rebuild `collectstatic` on deploy
- Generate Django migrations before schema changes go live
- Keep Tesseract installed on the runtime image or a separate OCR service
- Use S3-compatible object storage for ANPR media if you do not want uploads on the local filesystem
