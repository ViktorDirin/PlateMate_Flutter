# Roadmap — PlateMate Flutter

Strategic direction: Transitioning from a static meal planner to an active, AI-assisted nutrition diary with expert reporting.

## Phase 4: AI Food Vision & Factual Nutrition Logging (Current Sprint)
- [ ] **Database Schema Extension:** Add nutritional macro fields to `day_plans` (`calories`, `protein`, `fats`, `carbs`, `fiber`, `logged_at`, `ai_notes`).
- [ ] **Secure AI Backend:** Implement a Supabase Edge Function to securely call Google Gemini Flash API with user-provided photos without exposing API keys.
- [ ] **Camera & Compression Pipeline:** Allow users to capture 1–3 meal photos, compress locally (~200 KB), and attach optional contextual text notes (e.g., dressings, hidden ingredients).
- [ ] **Confirmation Bottom Sheet:** Display parsed macros, identified ingredients, and allow manual adjustments before confirming the log.
- [ ] **Fact-over-Plan Logic:** Override planned meal display and calculations with actual logged nutrition data.

## Phase 5: Historical Analytics & Professional Export
- [ ] **Flexible Range History:** Enable historical browsing across arbitrary timeframes (7 days, 10 days, 30 days).
- [ ] **PDF Report Generator:** Generate polished nutritional summary PDFs for dietitians (daily averages, macro ratios, fiber adequacy, meal timelines).
- [ ] **Data Portability (JSON Export):** Single-click JSON backup export for third-party LLM dietary analysis and personal archives.
- [ ] **Cloud Photo Storage (Optional):** Evaluate image retention policies vs. Supabase Storage quotas.