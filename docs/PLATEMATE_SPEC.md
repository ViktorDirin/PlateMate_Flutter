# PlateMate — Technical Specification & Feature Blueprint

## 1. Product Concept & Goals
**PlateMate** is an offline-first mobile meal-planning application built with **Flutter (Dart)** and **Supabase**. 
The app is designed for precise, fast daily nutrition tracking with instant cold-start loading[cite: 8], smart time inputs[cite: 8], interactive meal constructors[cite: 8], and multi-profile cloud sync without audio-focus interruption[cite: 8].

---

## 2. Design System & UI/UX Guidelines

### 2.1 Theme & Color Palette (Forced Dark Mode)
- **Primary Background:** `#12181f` (Deep dark slate)[cite: 8]
- **Card & Container Surfaces:** `#1e293b` (Contrasting graphite)[cite: 8]
- **Neon Primary Accent:** `#00f0ff` / `#38bdf8` (Cyan blue)[cite: 8]
- **Typography:** Google Fonts *Outfit* with high-contrast white/light-grey text[cite: 8]
- **Icons:** Material 3 / Cupertino Icons styled with neon accents[cite: 8]

### 2.2 Layout & Usability Constraints
- **One-Handed Navigation:** Large interactive touch targets, bottom-heavy action zones[cite: 8].
- **Strict Viewport Locks:** Horizontal screen scrolling is strictly disabled[cite: 8]. Vertical scrolling is confined inside list containers[cite: 8].
- **Keyboard Protection:** Modals and input sheets auto-shift to the upper third of the viewport upon keyboard presentation to keep inputs visible[cite: 8].
- **Audio Isolation:** Background sync threads run in strict isolation to prevent interrupting active background media playback on the device[cite: 8].

---

## 3. Screen-by-Screen Specifications

### Screen 1: Diet Profile Manager (`DietListScreen`)
- **Diet Cards:** Lists distinct diet plans (e.g., "Vik's Diet", "Grey's Diet")[cite: 8].
- **Priority Default ("Star" System):**
  - Tapping the "Star" icon marks a diet as default (`isDefault: true`)[cite: 8].
  - On application cold start, if a default diet exists, Screen 1 is bypassed immediately, routing the user straight to Screen 2[cite: 8].
- **Navigation:** Back button on Screen 2 returns to this profile selection list[cite: 8].

### Screen 2: Daily Schedule & Fasting Monitor (`DietDetailScreen`)
- **Header:**
  - Active Diet title with back navigation[cite: 8].
  - **Live Cloud Sync Indicator:**
    - Green: Fully synchronized with Supabase[cite: 8].
    - Yellow: Background sync in progress[cite: 8].
    - Red: Offline mode / sync error[cite: 8].
- **Day Navigation Bar:** Quick toggle buttons for "Today", "Tomorrow", and a calendar picker for arbitrary historical/future dates[cite: 8].
- **Live Fasting Timer:** A real-time ticking counter (HH:MM) calculating and displaying elapsed time since the latest recorded meal of the day[cite: 8].
- **Fixed Meal Categories:**
  - **Breakfast**[cite: 8]
  - **Lunch**[cite: 8]
  - **Dinner**[cite: 8]
- **Smart Time Input Formatter:**
  - Entering continuous numeric digits (e.g., "930" or "1420") automatically formats on-the-fly to valid time strings "09:30" or "14:20"[cite: 8].

### Screen 3: Meal Catalog & Ingredient Builder (`MealLibraryScreen`)
- **Category Tabs:** Filter and view catalog items segmented by Breakfast, Lunch, and Dinner[cite: 8].
- **Drag-and-Drop Reordering:** Long-press on meal cards (`ReorderableListView`) to adjust priority within categories[cite: 8].
- **Ingredient Constructor:**
  - Expandable inline accordion for each meal[cite: 8].
  - Add/remove ingredient rows: Name, Quantity, Unit (`gr`, `pcs`, `ml`)[cite: 8].
  - Sandboxed input state using `PageStorageBucket` and `ValueKey` to eliminate focus/scroll jitter during scrolling[cite: 8].

---

## 4. Synchronization Strategy (Hybrid Loading)
1. **Instant UI Render:** App reads local cache via `HydratedBloc` on cold start (Time to Interactive < 300ms)[cite: 8].
2. **Asynchronous Cloud Pull:** Dispatches background fetch to Supabase `diet_plans`[cite: 8].
3. **Timestamp Resolution:** Merges states using `updatedAt`[cite: 8].
4. **Targeted Updates:** Local mutations immediately commit to local storage and issue targeted `UPDATE` queries strictly filtered by the active `diet_id`[cite: 8].

---

## 5. Development Guidelines for AI Assistant
- All explanations and architectural discussions in **Russian**.
- Code, UI strings, and code comments in **English**.
- All terminal commands and Antigravity prompts MUST be delivered in separate, easily copyable **Markdown code blocks**.