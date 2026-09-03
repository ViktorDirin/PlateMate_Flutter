# Changelog — PlateMate Flutter

All notable changes, implemented sprints, and architectural milestones.

## [v1.0.0] - Released & Verified (Sprint 1 - 3)

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

### Sprint 4: AI Food Vision & Factual Nutrition Logging
- Integrated Cloudflare Workers AI and Supabase Edge Function (`analyze-food`) for fast, accurate meal photo analysis (5–8s).
- Implemented client-side image compression (max 1024px, JPEG quality 65) to stay well under memory limits.
- Built centered modal dialogs (`FoodLoggingDialog`, `MealNutritionBreakdownDialog`) for meal capture, confirmation, and detailed macro breakdown.
- Implemented Supabase persistence and synchronization for factual nutrition fields (`is_actual`, `actual_meal_name`, `calories`, `protein`, `fats`, `carbs`, `fiber`, `user_note`, `ai_breakdown`).
- Added "Fact-over-Plan" display, macro summary chips, and daily actual totals in Planner screen.