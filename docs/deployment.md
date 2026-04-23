# Deployment

## Requirements

Backend:

- Python 3.12.x
- `pip` and a virtual environment tool
- PostgreSQL for production
- Tesseract OCR installed in the runtime image or provided by a sidecar service

Frontend:

- Flutter SDK 3.3 or newer
- A modern browser for local testing
- Netlify or another static host for the web build

Project dependencies:

- Backend Python packages from `requirements.txt`
- Frontend Dart packages from `frontend/pubspec.yaml`

## Backend on Railway

Railway can deploy the Django backend directly from the repository root. The root [`Dockerfile`](../Dockerfile) builds the runtime image, and the root [`railway.json`](../railway.json) keeps migrations and healthcheck configuration.

This repo pins Python to 3.12 in [`.python-version`](../.python-version) so Railway does not drift onto Python 3.13 and break packages that do not yet ship compatible wheels.

You do not need a separate build script for the backend unless you want to override the defaults in the Railway dashboard.

### Backend Environment Variables

Required:

- `DEBUG=False`
- `SECRET_KEY`
- `ALLOWED_HOSTS`
- `DATABASE_URL` (must point to PostgreSQL in production; SQLite is only for local development)
- `DJANGO_TIME_ZONE`
- `CORS_ALLOWED_ORIGINS`
- `CSRF_TRUSTED_ORIGINS`
- `AUTO_CREATE_DEFAULT_SUPERUSER=True`
- `DEFAULT_SUPERUSER_USERNAME=admin`
- `DEFAULT_SUPERUSER_PASSWORD=admin12345`
- `DEFAULT_SUPERUSER_EMAIL=admin@example.com`

Recommended for production:

- `DATABASE_SSL_REQUIRE=True`
- `SECURE_SSL_REDIRECT=True`
- `STATIC_URL=/static/`
- `MEDIA_URL=/media/`

### Manual Bootstrap

If you want to create or reset the admin account manually, use the bootstrap command without an interactive prompt:

```bash
DJANGO_SUPERUSER_USERNAME=admin \
DJANGO_SUPERUSER_EMAIL=admin@example.com \
DJANGO_SUPERUSER_PASSWORD=change-this-password \
python manage.py bootstrap_superuser
```

If the username already exists, pass `--force` to reset that account.

Railway-specific note:

- Railway injects `RAILWAY_PUBLIC_DOMAIN` for each service, and the backend automatically adds that host and origin when it is present.
- Railway healthchecks originate from `healthcheck.railway.app`, and the backend allows that host automatically so deploys can pass the readiness check.
- The `/health/` and `/api/health/` endpoints are exempt from SSL redirects so Railway can still get a `200` even if `SECURE_SSL_REDIRECT=True`.
- `collectstatic` runs in the runtime container startup with minimal verbosity so the live container has the generated admin assets before Gunicorn serves requests.
- Gunicorn runs at warning level to avoid filling the logs with routine startup chatter.
- Railway will prefer the root Dockerfile automatically, which bypasses the Railpack build path that was failing with the secret-resolution error.
- The app attempts to create the default admin during WSGI/ASGI startup, but it only does so once and skips cleanly if the account already exists.
- If your frontend stays on Netlify or another host, add that production origin to `CORS_ALLOWED_ORIGINS` and `CSRF_TRUSTED_ORIGINS` too.

Optional object storage:

- `USE_S3_STORAGE=False`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_STORAGE_BUCKET_NAME`
- `AWS_S3_REGION_NAME`
- `AWS_S3_ENDPOINT_URL`

Optional email settings:

- `DEFAULT_FROM_EMAIL`
- `SUPPORT_EMAIL`

## Flutter Web on Netlify

Build:

```bash
cd frontend
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=https://your-backend.up.railway.app/api
```

The browser client uses `shared_preferences` for session and offline state, so it does not need a local SQLite database. The API base URL must be supplied at build time for a production web deploy.

If you deploy through Netlify, add `API_BASE_URL` as a site environment variable and let `frontend/scripts/netlify-build.sh` install Flutter stable and pass it into the build. The build now disables the Flutter service worker so browser deploys reflect the latest code without old cached bundles hanging around. For local development, the app falls back to `http://127.0.0.1:8001/api` when you run it without a release build-time define.

### Netlify Site Settings

- Base directory: not required when using the root `netlify.toml`
- Build command: `bash frontend/scripts/netlify-build.sh`
- Publish directory: `frontend/build/web`
- Environment variable: `API_BASE_URL=https://smart-parking-backend-production-18b7.up.railway.app/api`

If you use a custom Netlify domain, add that domain to the backend `CORS_ALLOWED_ORIGINS` and `CSRF_TRUSTED_ORIGINS` Railway variables before you deploy.

SPA fallback:

- `/* /index.html 200`

### Frontend Environment Variables

- `API_BASE_URL`

## Production Notes

- Enable HTTPS on both services
- Rotate secrets periodically
- Keep PostgreSQL managed
- Use object storage for media if image volume grows
- Add generated migrations before schema evolution in a long-lived production environment
- Install Tesseract in the runtime environment or route OCR through a containerized sidecar if the base platform does not provide the binary
