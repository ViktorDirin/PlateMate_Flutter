# Roadmap — PlateMate Flutter

Strategic direction: Transitioning from a static meal planner to an active, AI-assisted nutrition diary with expert reporting.

## Phase 4: AI Food Vision & Factual Nutrition Logging (Completed)
- [x] **Database Schema Extension:** Added nutritional macro fields to `day_plans` (`calories`, `protein`, `fats`, `carbs`, `fiber`, `completed_at`, `user_note`, `ai_breakdown`).
- [x] **Secure AI Backend:** Integrated Cloudflare Workers AI (`@cf/meta/llama-3.2-11b-vision-instruct`) & Supabase Edge Function (`analyze-food`) for fast (5–8s), accurate food detection and macro estimation.
- [x] **Camera & Compression Pipeline:** Multi-source image capture (Camera & Gallery) with local compression (1024px, JPEG quality 65, ~48 KB) and context notes.
- [x] **Confirmation & Nutrition Dialogs:** Centered dialogs with macro breakdown, ingredient parsing, and live manual adjustment.
- [x] **Fact-over-Plan Logic:** Overrides planned slot display with logged nutrition badges, breakdown viewer, and daily actual totals.
- [x] **Meal Lifecycle Management:** In-dialog Edit (macro & name recalculation), Clear Slot (with dynamic daily total updates), and Save to Library.
- [x] **Library Quick-Log Integration:** Ability to view saved favorites in Library and schedule them directly to any slot ("Add to Today") without re-scanning.

## Phase 5: Historical Analytics, Storage & Export
- [ ] **Flexible Range History:** Enable historical browsing across arbitrary timeframes (7 days, 10 days, 30 days).
- [ ] **Cloud Photo Storage (Optional):** Upload and persist compressed food thumbnails in Supabase Storage (`meal_photos`).
- [ ] **PDF Report Generator:** Generate polished nutritional summary PDFs for dietitians (daily averages, macro ratios, fiber adequacy, meal timelines).
- [ ] **Data Portability (JSON Export):** Single-click JSON backup export for third-party LLM dietary analysis and personal archives.