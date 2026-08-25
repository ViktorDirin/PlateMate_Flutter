# PlateMate — Flutter Architecture & Infrastructure State

## 1. Project Overview
**PlateMate** is an offline-first diet planning and meal management mobile application built with **Flutter & Dart**, backed by **Supabase** for cloud synchronization and multi-profile sharing.

---

## 2. Dependencies & Stack (`pubspec.yaml`)
- **`flutter` (SDK):** Core framework (targeting Android native build).
- **`flutter_bloc` & `hydrated_bloc`:** State management with automated local persistence and cold-start state restoration (TTI < 300ms).
- **`path_provider`:** Resolves local device directories for `HydratedStorage` cache.
- **`supabase_flutter`:** Client library for PostgreSQL database CRUD operations and sync.
- **`uuid`:** Generates RFC4122 unique identifiers locally for diets, meals, and ingredients.
- **`intl`:** Date formatting, schedule matching, and calendar operations.
- **`google_fonts`:** Custom dynamic typography (*Outfit* font family).
- **`cupertino_icons`:** Visual icon set.

---

## 3. Project Structure (`lib/`)
```text
lib/
├── main.dart                      # App entry point, Supabase & HydratedStorage initialization
├── core/
│   └── theme.dart                 # Forced Dark Theme (Material 3, Palette: #12181f / #1e293b / #00f0ff)
├── models/
│   └── diet_plan.dart             # Data models (DietPlan, Meal, Ingredient)
├── blocs/
│   └── diet_bloc.dart             # State management, local cache writes, Supabase merge sync
└── ui/
    ├── widgets/
    │   └── time_input_formatter.dart # Auto-formatting time inputs (e.g., "930" -> "09:30")
    └── screens/
        ├── diet_list_screen.dart   # Screen 1: Multi-diet manager & Default "Star" selector
        ├── diet_detail_screen.dart # Screen 2: Daily schedule, Fasting Timer, Meal categories
        └── meal_library_screen.dart# Screen 3: Meal catalog, Ingredient constructor, Drag-and-Drop
```

---

## 4. Data Models Architecture (`lib/models/diet_plan.dart`)

### 4.1 `Ingredient`
- `name`: `String` — Product name.
- `quantity`: `double` / `num` — Amount.
- `unit`: `String` — Unit of measurement (`'gr' | 'pcs' | 'ml'`).

### 4.2 `Meal`
- `id`: `String` — Unique UUID.
- `name`: `String` — Meal title.
- `category`: `String` — Fixed category (`'Breakfast' | 'Lunch' | 'Dinner'`).
- `time`: `String` — Planned time (`'HH:MM'`).
- `date`: `String` — Target calendar date (`'YYYY-MM-DD'`).
- `sortOrder`: `int` — Priority order within category.
- `ingredients`: `List<Ingredient>` — List of component products.

### 4.3 `DietPlan`
- `id`: `String` — Unique UUID for the diet profile (e.g., "Vik's Diet", "Grey's Diet").
- `name`: `String` — Diet profile name.
- `isDefault`: `bool` — Flag for cold-start auto-routing bypass.
- `meals`: `List<Meal>` — Collection of meals and schedule.
- `updatedAt`: `DateTime` / `String` — Timestamp used for conflict-free cloud merge synchronization.

---

## 5. State Management & Sync Flow (`DietBloc`)
1. **Instant Hydration:** On application launch, `HydratedBloc` loads persisted state from local device storage immediately.
2. **Background Sync:** A non-blocking thread issues a fetch request to Supabase table `diet_plans`.
3. **Timestamp Merge:** Compares `updatedAt` timestamps between local and remote records:
   - If remote is newer $\rightarrow$ updates local state.
   - If local is newer $\rightarrow$ pushes local state via isolated `UPDATE` targeted strictly to the active `diet_id`.
4. **State Flags:** Exposes `isSyncing` and `syncFailed` properties to drive the live UI Cloud Sync icon (Green / Yellow / Red).