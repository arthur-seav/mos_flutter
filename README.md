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
| `dotted_border` | The dashed "Add more items" outline in the cart (Flutter has no dashed border). |
| `email_validator` | Email format check. |
| `intl` | Price formatting (`$3.50`). |
| `phone_numbers_parser` | Phone number check (Dart port of Google's libphonenumber). |
| `pretty_qr_code` | Draws the KHQR code on the payment page and in the saved picture. |
| `gal` | "Save QR to photos": writes the picture to the phone's photo library (Android / iOS; no web support, so the button is hidden on web). |
| `screenshot` 3.0.x | Draws the saved KHQR picture (logo, QR, order, drinks, dates) off screen, without showing it on the page. Last release May 2024, but it works with the Flutter 3.41 render API and is widely used; Flutter itself can only capture widgets that are on screen. |

Written by hand: card number (Luhn), expiry and CVV checks in `utils/card_validators.dart`. `credit_card_validator` was last released in 2023 for Dart 2, and `flutter_credit_card` brings its own card UI and native code that the Figma design does not need.

## Project structure

Folders are split by **layer** first, then by feature inside each layer.

```
lib/
├── main.dart            # entry point; chooses mock or API repositories (NFR-09)
├── app.dart             # MaterialApp + theme + router
├── app_routes.dart      # route paths
├── router.dart          # all routes + login redirect (go_router)
├── screens/             # full pages: they read controllers and draw, no logic
│   ├── auth/  home/  menu/  cart/  orders/  account/   # menu/ includes customize_drink_screen
│   └── shell/           # bottom navigation (Home / Menu / Orders / Profile)
├── controllers/         # logic: Riverpod providers and Notifiers, no widgets
│   ├── auth/  home/  menu/  cart/
│   └── common/          # SubmitStateMixin (loading / error for form buttons)
├── widgets/             # pieces of screens
│   ├── common/          # used by several features (buttons, fields, empty state...)
│   ├── auth/  menu/  cart/   # used by one feature's screens (menu widgets are also on Home)
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
| `widgets/common/quantity_selector.dart` | "− 1 +" on the drink page and in the cart. |
| `widgets/common/count_badge.dart` | Caramel count badge on the Home cart button ("9+" above 9). |
| `widgets/cart/` | Cart line card and the Menu cart bar. |
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
Drink options follow the test cases: Espresso is hot only (TC-10), Caramel Latte opens with the Figma defaults (TC-11), Americano has Large +$0.50 (TC-15), Latte is $3.00 with Large +$1.00 (TC-14). Every drink has a default in each required group, so TC-12 ("Please choose a size.") is checked in the tests with a repository that leaves the size default empty (`default_option_id` is nullable).
Espresso has **Shots** instead of a cup size (BR-01): Single -$0.50, Double (default), Triple +$0.50; "Extra shot" stays in the add-ons for a 4th shot.
Size and shot buttons show the price against the current choice ("Small -$0.50 · Medium +$0.00 · Large +$0.50"); the data keeps each option's own extra price (BR-03).

The cart stays in the app until checkout (SA §3.5). Before checkout the app asks which drinks sold out and removes them (BR-05). `MockMenuRepository.markSoldOut(id)` stands in for staff marking a drink sold out, for TC-17 in the tests.

**Checkout and payment (mock).** The demo store is open 7:00 AM – 9:00 PM every day, and the schedule panel offers the next 6 pickup times: the first at least 5 minutes ahead, rounded up to a 5-minute mark, then every 10 minutes, none after 8:00 PM (BR-07, TC-19). At 10:41 that is 10:50, 11:00 … 11:40. Payments work like a gateway's test mode:

| Method | What happens |
|---|---|
| KHQR | Paid 5 seconds after the QR code appears (TC-21). The QR expires after 5 minutes. |
| Card ending 4242 (saved for Dara) | Paid. |
| Card `4000 0000 0000 0002` (add it on the card page) | Declined, to show TC-22. |

The mock backend works out every price from the menu and ignores any amount the app could send (TC-23). Guests are asked to log in when they tap "Go to checkout" in the cart (BR-06, TC-18); signing in or creating an account there takes them on to checkout with the cart kept, and a link straight to checkout or a payment page sends a guest to login first.

**Save QR to photos** (KHQR page) saves a picture, not just the code: the logo, order number, amount, QR code, when it expires, when the order was made, the pickup time and the drinks with their prices. Dates are written in full ("Thu, 29 Oct 2026"), and the file is named `MOS-KHQR-order<id>-<yyyyMMdd-HHmm>`, so an old picture can be told apart. The button only shows on Android / iOS (not on web). After pulling, run `flutter pub get` and restart the app fully: hot reload does not load the new native plugin.

To try **Forgot password**, use `012 345 678` or `098 765 432`; any other number gives "Account not found." (TC-06).

## Open questions for the SA document

- **Ice level for hot drinks (BR-01).** The data dictionary has no way to say "this group only applies to iced drinks". The app adds two fields: `OptionGroup.needsIcedDrink` (true for Ice level) and `DrinkOption.isIced` (true for Iced). The backend needs the same, or a fixed rule.
- **Short option names in cart lines.** Ice level and sweetness both use "Less / Regular / Extra". The app adds `OptionGroup.summaryNoun` ("ice", "sugar") so cart and order lines read "Less ice · Regular sugar".
- **Negative extra prices.** Espresso's Single shot is -$0.50 from the default Double. `options.extra_price` is NUMERIC, so this fits, but the data dictionary only says "0 if free"; it should say discounts are allowed.
- **ASAP ready time.** Checkout says "Ready in about 10 min" (Figma). There is no field for it; the app adds `StoreSettings.asapPrepMin`.
- **Card holder name.** Figma shows the holder's name on a saved card; `saved_cards` has no column for it. The app keeps `SavedCard.holderName`.
- **Why a payment failed.** The failure screen says why ("Your card was declined.", "The QR code expired…"). `payments` has no column for it; the app reads `Payment.failureReason` from the gateway's reply.
- **Options a drink does not offer (TC-10: Espresso is Hot only).** `product_options` is described as a price override only. The app also reads it as "the options this drink offers" when a drink has rows for a group.

## Deviations from SA 2.0

- **Pickup lead time (BR-07).** SA 2.0 says a scheduled slot must be at least 30 minutes after the order (`store_settings.min_prep_min`, default 30). The demo store uses **5 minutes**, with slots every 10 minutes (Arthur's decision, 2026-10-29). Only the mock data changed: the app reads both values from `store_settings`, so a store set to 30 / 15 behaves as SA 2.0 says (tested in `test/data/pickup_schedule_test.dart`). The schedule panel shows the next 6 times instead of the whole day; SA 2.0 does not fix a number. The SA document should be updated, or the store reset to 30.

## Fonts

Fraunces and DM Sans are bundled in `assets/fonts/` (SIL Open Font License 1.1) so the app looks the same offline.

## Git workflow

`main` only holds verified code. Each feature is built on `feature/<name>`, verified, then merged through a pull request.
