# Changelog — PlateMate Flutter

All notable changes, implemented sprints, and architectural milestones.

## [v1.0.0] - Released & Verified (Sprint 1 - 4)

### Sprint 1: Data Seeding & Shopping List Core
- Added support for subaddressing email aliases (`user+alias@gmail.com`).
- Implemented robust starter meal library and slot configs seeding via Supabase for new users.
- Added native system sharing (`share_plus`) for the generated shopping list.
- Implemented clear-cart confirmation modal preventing accidental deletions.

### Sprint 2: Meal Time Tracking & Fasting Monitor
- Implemented `is_completed` meal check status persistence in Supabase.
- Added custom time selection via native `TimePicker` for completed meals.
- Implemented dynamic "Last meal: Xh Ym ago" real-time counter in the planner header.
- Implemented cascading deletes (`ON DELETE CASCADE`) in PostgreSQL to ensure clean account resets.

### Sprint 3: Native Authentication
- Configured Google Cloud Console project and credentials (Web Client ID & Android Client ID with SHA-1 fingerprint).
- Integrated `google_sign_in` package with Supabase `signInWithIdToken`.
- Added styled dark mode "Continue with Google" button with loading states.
- Verified successful APK release build execution.

### Sprint 4: AI Food Vision, Factual Logging & Meal Management
- Integrated Cloudflare Workers AI (`@cf/meta/llama-3.2-11b-vision-instruct`) with Supabase Edge Function (`analyze-food`) delivering 5–8s response times without queuing timeouts.
- Implemented robust client-side image compression (~48 KB average) supporting both Gallery picker and live Camera capture without EXIF/memory overhead.
- Built centered modal dialogs (`FoodLoggingDialog`, `MealNutritionBreakdownDialog`) for meal capture, confirmation, and detailed ingredient/macro breakdown.
- Implemented Supabase persistence and synchronization for factual nutrition fields (`is_actual`, `actual_meal_name`, `calories`, `protein`, `fats`, `carbs`, `fiber`, `user_note`, `ai_breakdown`).
- Added "Fact-over-Plan" display, macro summary chips, and daily actual totals in Planner screen.
- Added Meal Management actions inside the nutrition breakdown dialog:
  - **Edit:** Inline modification of meal titles, notes, and nutritional macros with immediate daily total recalculation.
  - **Clear Slot:** Confirmation modal to reset a logged meal slot and subtract its values from the day's totals.
  - **Save to Library:** Instant one-click saving of analyzed meals and ingredients into the personal recipes database.
- Enhanced the `Library` tab with "Add to Today" slot picker, allowing instant meal scheduling without repetitive AI photo scans.

### Sprint 5: Goals, Photo Persistence, Dynamic Planner, Export & Library Editing
- **Daily Calorie Target & Progress Bar:** Configurable daily calorie goal with real-time target vs actual progress bar, remaining/overage indicator, and numeric edit dialog.
- **Meal Photo Persistence:** Integrated Supabase Storage `meal_photos` bucket with secure RLS policies, automatic image compression, public URL persistence in `day_plans`, and card thumbnail previews.
- **Dynamic Rolling Date Strip:** Infinite horizontal week navigation (`<` / `>`), automatic week generation around selected dates, and one-tap "Today" jump button.
- **Responsive HTML Report Exporter:** Built `ReportExportService` generating self-contained dark-theme HTML nutrition summaries with user stats, averages, and expandable daily breakdowns.
- **Library Meal Editing:** Interactive `_EditMealDialog` enabling in-place editing of meal names, categories, ingredient lists, and gram weights with real-time macro recalculation via `LocalFoodParser`.
- **Planner Category Sync & Slot Reset:** Context-aware category pre-selection when adding meals from planner slots and full slot clearing for both planned and logged meals.
- **Schema & Test Stability:** Aligned all `day_plans` database column mappings (`plan_date`, `is_actual`, `meal_id`, `photo_url`) and expanded automated test suite to 36 passing tests.