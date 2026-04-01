# Changelog

All notable user-facing changes to this project should be recorded here.

## v1.4.0

- Added a third `Expiry` tab for tracking household food items with storage location, notes, quantity labels, and expiry dates.
- Added per-item reminder scheduling at fixed times before expiry and wired local notification scheduling for supported mobile/desktop platforms.

## v1.3.5

- Week plan dishes now open the same cooking log popup as the dish list when marked done, and they only save as cooked after that dialog is completed.

## v1.3.4

- Moved the full grocery trip workflow into its own file so the main family app shell and the grocery-planning flow can evolve independently.

## v1.3.3

- Split the largest storage and settings sections out of `main.dart` so future work can evolve the app shell and data layer without one giant edit surface.

## v1.3.2

- Added a desktop-focused Supabase setup checklist in `docs/` so the full project, auth, SQL, and local run configuration flow is easy to resume outside mobile.

## v1.3.1

- Added mobile Supabase deep-link app configuration for iOS and Android and documented a shorter `--dart-define-from-file` setup flow for local Supabase-enabled builds.

## v1.3.0

- Added `mind`-style automatic local JSON backups with a settings toggle, recent snapshot retention, and restore-from-backup support alongside the existing manual import/export tools.

## v1.2.0

- Moved account and sync controls into a full settings page behind the top-right cog while keeping `Dishes` and `Groceries` as the only top-level tabs.

## v1.1.1

- Standardized the in-app changelog version pill styling.
