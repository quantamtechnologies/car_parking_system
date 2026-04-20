# Deployment

## Requirements

Backend:

- Python 3.11 or newer
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

## Backend on Render

Required commands:

```bash
pip install -r requirements.txt
gunicorn project.wsgi:application
```

Recommended pre-deploy command:

```bash
python manage.py migrate --run-syncdb --noinput && python manage.py collectstatic --noinput
```

### Backend Environment Variables

Required:

- `DEBUG=False`
- `SECRET_KEY`
- `ALLOWED_HOSTS`
- `DATABASE_URL` (must point to PostgreSQL in production; SQLite is only for local development)
- `DJANGO_TIME_ZONE`
- `CORS_ALLOWED_ORIGINS`
- `CSRF_TRUSTED_ORIGINS`

Recommended for production:

- `DATABASE_SSL_REQUIRE=True`
- `SECURE_SSL_REDIRECT=True`
- `STATIC_URL=/static/`
- `MEDIA_URL=/media/`

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
flutter build web --release --dart-define=API_BASE_URL=https://your-render-backend.onrender.com/api
```

The browser client uses `shared_preferences` for session and offline state, so it does not need a local SQLite database. The API base URL must be supplied at build time for a production web deploy.

If you deploy through Netlify, add `API_BASE_URL` as a site environment variable and let `frontend/netlify.toml` pass it into the build. For local development, the app falls back to `http://127.0.0.1:8001/api` when you run it without a release build-time define.

Publish directory:

- `build/web`

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
