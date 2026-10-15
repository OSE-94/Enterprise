# PeoplePulse

PeoplePulse is a Flutter employee self-service app starter with an original
interface inspired by common HR workflows. It includes a home dashboard,
time-off requests, company updates, and an employee profile.

The app currently uses sample data from `HrService`; connect that service to
your HR backend before using it with real employee information.

## Run locally

Install Flutter, then run these commands from the project root:

```sh
flutter pub get
flutter run -d edge
```

To run the widget tests and static analysis:

```sh
flutter test
flutter analyze
```

## Project structure

- `lib/models/` — employee, leave request, and announcement models
- `lib/providers/` — app state managed with Provider
- `lib/services/` — sample HR data and leave request operations
- `lib/screens/` — dashboard, time off, updates, profile, and app navigation
- `lib/widgets/` — shared UI components
- `web/` — Flutter web entry point and assets
