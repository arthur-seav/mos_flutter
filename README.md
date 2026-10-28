# MOS Coffee — Customer App

Flutter customer app for the **Mobile Ordering System (MOS)**, SV34 Mobile Application II, Team 4.
The requirements and design are in the SA document `Mobile-Ordering-System_2.0` (kept outside this repo, in `MOS/Documentation/`).

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.41.6 (stable) |
| Dart | 3.11.4 |
| Android | 10 (API 29) or above, per NFR-08 |

## Run

```bash
flutter pub get
flutter run              # pick an Android emulator / device
flutter test             # unit and widget tests
flutter analyze          # lints
```

To preview in a browser: `flutter run -d chrome`.

## Packages

| Package | Why |
|---|---|
| `flutter_riverpod` 3.3.x | State management. 3.3.x is the newest line that supports Dart 3.11. |
| `go_router` 17.x | Routing, bottom tabs, redirect to login when there is no session. |
| `email_validator` | Email format check. |
| `intl` | Price formatting (`$3.50`). |
| `phone_numbers_parser` | Phone number check (Dart port of Google's libphonenumber). |

## Project structure

Folders are split by **layer** first, then by feature inside each layer.

```
lib/
├── main.dart            # entry point; chooses mock or API repositories (NFR-09)
├── app.dart             # MaterialApp + theme + router
├── app_routes.dart      # route paths
├── router.dart          # all routes + login redirect (go_router)
├── screens/             # full pages: they read controllers and draw, no logic
│   ├── auth/  home/  menu/  orders/  account/   # menu/ includes customize_drink_screen
│   └── shell/           # bottom navigation (Home / Menu / Orders / Profile)
├── controllers/         # logic: Riverpod providers and Notifiers, no widgets
│   ├── auth/  home/  menu/  cart/
│   └── common/          # SubmitStateMixin (loading / error for form buttons)
├── widgets/             # pieces of screens
│   ├── common/          # used by several features (buttons, fields, empty state...)
│   ├── auth/  menu/     # used by one feature's screens (menu widgets are also on Home)
├── data/
│   ├── models/          # User, Product, Category, MenuCatalog, Money, DrinkOption,
│   │                    # DrinkSelection (BR-01..03), CartItem ... (SA data dictionary)
│   ├── repositories/    # abstract interfaces the UI depends on (NFR-09)
│   ├── mock/            # in-memory implementations used until the backend exists
│   └── repository_providers.dart
├── theme/               # SA 4.1 design guidelines: colors, text styles, ThemeData, scroll behaviour
└── utils/               # form validators
```

`test/` mirrors the same folders.

### How the layers talk

`Screen` → `AuthController` (Riverpod `Notifier`) → `AuthRepository` interface → `MockAuthRepository` today, `ApiAuthRepository` later.

- Screens read state with `ref.watch(authControllerProvider)` and call actions through `ref.read(authControllerProvider.notifier)`.
- `main.dart` picks the repository with `ProviderScope(overrides: ...)`; tests pass a zero-latency mock the same way. Switching to the real API does not touch any screen.
- The router watches the session: with no session only the auth pages open; once signed in (or guest) the auth pages send you to Home.

### Shared modules

| Module | Purpose |
|---|---|
| `theme/app_colors.dart` | The 14 theme colors from SA 4.1.2. Never write hex codes in widgets. |
| `theme/app_text_styles.dart` | The 8 text styles from SA 4.1.1. |
| `theme/app_theme.dart` | Turns the two files above into `ThemeData`, so plain Material widgets match the Figma design. |
| `theme/app_scroll_behavior.dart` | Turns off Android's "stretch" effect when a list is pulled past its end. |
| `utils/validators.dart` | Email / phone / password / name checks for every form. |
| `controllers/common/submit_state.dart` | Loading and error state for a form's submit button (`AsyncValue`). |
| `widgets/common/labeled_text_field.dart` | Label + icon text field; can also show a server error under the field. |
| `widgets/common/loading_button.dart` | Main button with a spinner while busy. |
| `widgets/common/error_banner.dart` | Red box for a form-level error. |
| `widgets/common/or_divider.dart` | The "— or —" line between two actions. |
| `widgets/common/square_icon_button.dart` | White square icon button: back, search, cart. |
| `widgets/common/empty_state.dart` | "Nothing here" / "Could not load" message with an optional button. |
| `data/models/money.dart` | Prices as whole cents, so totals never have floating-point errors. |
| `widgets/common/selectable_pill.dart` | Rounded choice button: category chips and drink options. |
| `widgets/common/quantity_selector.dart` | "− 1 +" on the drink page (and the cart next). |
| `widgets/menu/` | Drink picture, add button / sold-out tag, category chips, search box, drink card and row (also used by Home). |
| `widgets/auth/` | Auth-page pieces: back button, title, status page (success / verifying), footer link. |

## Demo accounts (mock data)

All use the password `password123`. Accounts you create and passwords you reset last until the app is closed.

| Account | Result |
|---|---|
| `dara@example.com` or `012 345 678` | Customer, signs in |
| `098 765 432` | Customer (phone only), signs in |
| `inactive@example.com` | Deactivated, refused |
| `staff@mos.coffee` | Staff, refused: staff use the admin dashboard (FR-05) |

The demo menu has 4 categories and 17 drinks. **Mocha is sold out**, to show TC-09.
Drink options follow the test cases: Espresso is hot only (TC-10), Caramel Latte opens with the Figma defaults (TC-11), Americano has no default size (TC-12) and Large +$0.50 (TC-15), Latte is $3.00 with Large +$1.00 (TC-14).

To try **Forgot password**, use `012 345 678` or `098 765 432`; any other number gives "Account not found." (TC-06).

## Open questions for the SA document

- **Ice level for hot drinks (BR-01).** The data dictionary has no way to say "this group only applies to iced drinks". The app adds two fields: `OptionGroup.needsIcedDrink` (true for Ice level) and `DrinkOption.isIced` (true for Iced). The backend needs the same, or a fixed rule.
- **Short option names in cart lines.** Ice level and sweetness both use "Less / Regular / Extra". The app adds `OptionGroup.summaryNoun` ("ice", "sugar") so cart and order lines read "Less ice · Regular sugar".
- **Options a drink does not offer (TC-10: Espresso is Hot only).** `product_options` is described as a price override only. The app also reads it as "the options this drink offers" when a drink has rows for a group.

## Fonts

Fraunces and DM Sans are bundled in `assets/fonts/` (SIL Open Font License 1.1) so the app looks the same offline.

## Git workflow

`main` only holds verified code. Each feature is built on `feature/<name>`, verified, then merged through a pull request.
