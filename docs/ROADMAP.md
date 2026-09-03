# Roadmap — PlateMate Flutter

Strategic direction: Transitioning from a static meal planner to an active, AI-assisted nutrition diary with expert reporting.

## Phase 4: AI Food Vision & Factual Nutrition Logging (Completed)
- [x] **Database Schema Extension:** Added nutritional macro fields to `day_plans` (`calories`, `protein`, `fats`, `carbs`, `fiber`, `completed_at`, `user_note`, `ai_breakdown`).
- [x] **Secure AI Backend:** Integrated Cloudflare Workers AI & Supabase Edge Function (`analyze-food`) for fast (5–8s), accurate food detection and macro estimation.
- [x] **Camera & Compression Pipeline:** Multi-photo upload (1–3 photos) with local compression (1024px, JPEG quality 65, <200 KB) and context notes.
- [x] **Confirmation Dialog:** Centered dialogs with macro breakdown, ingredient parsing, and manual adjustment.
- [x] **Fact-over-Plan Logic:** Overrides planned slot display with logged nutrition badges, breakdown viewer, and daily actual totals.

## Phase 5: Historical Analytics & Professional Export
- [ ] **Flexible Range History:** Enable historical browsing across arbitrary timeframes (7 days, 10 days, 30 days).
- [ ] **PDF Report Generator:** Generate polished nutritional summary PDFs for dietitians (daily averages, macro ratios, fiber adequacy, meal timelines).
- [ ] **Data Portability (JSON Export):** Single-click JSON backup export for third-party LLM dietary analysis and personal archives.
- [ ] **Cloud Photo Storage (Optional):** Evaluate image retention policies vs. Supabase Storage quotas.