# Agent Skills

## Localization

ARB files live in `arb/`. Generated localization output lives in `lib/l10n/` and is produced through `flutter_intl`.

Supported locales:

- `en`
- `zh_CN`
- `ja`
- `ru`

Access patterns:

- In widgets with `BuildContext`: use `context.appLocalizations.key` and import `common.dart`.
- In controllers, providers, and non-widget code: use `currentAppLocalizations.key` and import `app_localizations.dart`.

When moving hardcoded UI text into localization:

1. Add keys to every supported ARB file.
2. Keep key names stable and descriptive.
3. Regenerate localization output.
4. Recheck touched call sites for missing imports and fallback English text.

## Flutter UI Work

Follow existing Material You and Surfboard-like UI conventions. Prefer existing widgets, providers, and helpers over adding new styling systems.

For widget work:

- Use existing state providers and notifiers where possible.
- Keep `child:` last in widget constructors.
- Prefer `const` constructors and final locals.
- Add focused widget tests when user-facing behavior changes.

## Provider and State Work

Use Riverpod generated providers consistently with the existing `lib/providers/` structure.

Provider test defaults:

- Use `ProviderContainer` directly when no widget tree is needed.
- Dispose containers after tests.
- Use generated notifier methods instead of reaching into implementation details.

## Core and Platform Work

Route core calls through `CoreController` and `CoreHandlerInterface`. Do not call Android FFI or desktop socket implementations directly from feature code unless the surrounding code already owns that platform boundary.

When changing platform-specific behavior:

- Check the relevant manager in `lib/manager/`.
- Keep desktop and mobile paths explicit.
- Add tests for shared Dart logic, and manually verify native behavior when automated coverage is not practical.
