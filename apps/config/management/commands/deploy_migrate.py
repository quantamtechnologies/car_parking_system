from __future__ import annotations

from time import monotonic, sleep

from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.db import DEFAULT_DB_ALIAS, OperationalError, connections


class Command(BaseCommand):
    help = "Wait for the database and run production migrations safely."

    def add_arguments(self, parser):
        parser.add_argument(
            "--database",
            default=DEFAULT_DB_ALIAS,
            help="Database alias to migrate. Defaults to the primary database.",
        )
        parser.add_argument(
            "--timeout",
            type=float,
            default=120.0,
            help="Maximum number of seconds to wait for the database before failing.",
        )
        parser.add_argument(
            "--interval",
            type=float,
            default=2.0,
            help="Seconds to wait between connection attempts.",
        )
        parser.add_argument(
            "--migrate-retries",
            type=int,
            default=3,
            help="How many times to retry the migration command after the database is reachable.",
        )

    def handle(self, *args, **options):
        database_alias = options["database"]
        timeout = max(0.0, float(options["timeout"]))
        interval = max(0.1, float(options["interval"]))
        migrate_retries = max(1, int(options["migrate_retries"]))

        self._wait_for_database(database_alias, timeout=timeout, interval=interval)
        self._run_migrations(database_alias, retries=migrate_retries, interval=interval)

    def _wait_for_database(self, database_alias: str, *, timeout: float, interval: float) -> None:
        connection = connections[database_alias]
        deadline = monotonic() + timeout
        attempt = 0

        while True:
            attempt += 1
            try:
                connection.close()
                connection.ensure_connection()
                self.stdout.write(
                    self.style.SUCCESS(f"Database {database_alias!r} is reachable.")
                )
                return
            except OperationalError as exc:
                now = monotonic()
                if now >= deadline:
                    raise CommandError(
                        f"Database {database_alias!r} was not reachable within {timeout:.0f} seconds: {exc}"
                    ) from exc

                wait_seconds = min(interval, max(0.0, deadline - now))
                self.stdout.write(
                    self.style.WARNING(
                        f"Waiting for database {database_alias!r} (attempt {attempt}): {exc}. "
                        f"Retrying in {wait_seconds:.0f} seconds..."
                    )
                )
                sleep(wait_seconds)

    def _run_migrations(self, database_alias: str, *, retries: int, interval: float) -> None:
        for attempt in range(1, retries + 1):
            try:
                call_command(
                    "migrate",
                    database=database_alias,
                    run_syncdb=True,
                    interactive=False,
                    verbosity=0,
                )
                self.stdout.write(self.style.SUCCESS("Database migrations completed successfully."))
                return
            except OperationalError as exc:
                if attempt >= retries:
                    raise CommandError(
                        f"Database migrations failed after {retries} attempts: {exc}"
                    ) from exc

                connections[database_alias].close()
                self.stdout.write(
                    self.style.WARNING(
                        f"Migration attempt {attempt} failed: {exc}. "
                        f"Retrying in {interval:.0f} seconds..."
                    )
                )
                sleep(interval)
