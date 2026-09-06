import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../blocs/diet_bloc.dart';
import '../models/day_plan.dart';
import '../models/meal.dart';

class ReportExportService {
  /// Generates a self-contained, responsive HTML nutrition report.
  static String generateHtmlReport({
    required DietState state,
    required DateTime startDate,
    required DateTime endDate,
    String? userEmail,
  }) {
    // Normalise start and end dates (inclusive)
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDaysCount = end.difference(start).inDays + 1;

    final List<DateTime> dateRangeList = [];
    for (int i = 0; i < totalDaysCount; i++) {
      dateRangeList.add(start.add(Duration(days: i)));
    }

    final double dailyTarget = state.dailyCalorieTarget > 0 ? state.dailyCalorieTarget : 2000.0;

    // Aggregate statistics
    int loggedDaysCount = 0;
    double totalCaloriesAllDays = 0.0;
    double totalProteinAllDays = 0.0;
    double totalFatsAllDays = 0.0;
    double totalCarbsAllDays = 0.0;
    double totalFiberAllDays = 0.0;

    final StringBuffer daysHtmlBuffer = StringBuffer();

    // Map of active slots sorted by orderIndex
    final activeSlots = state.mealSlots.where((s) => s.isEnabled).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (final day in dateRangeList) {
      final dayPlan = state.dayPlans.firstWhere(
        (p) =>
            p.date.year == day.year &&
            p.date.month == day.month &&
            p.date.day == day.day,
        orElse: () => DayPlan(date: day, slotMeals: const {}),
      );

      double dayCalories = 0.0;
      double dayProtein = 0.0;
      double dayFats = 0.0;
      double dayCarbs = 0.0;
      double dayFiber = 0.0;
      bool hasAnyMeals = false;

      final StringBuffer mealsHtmlBuffer = StringBuffer();

      for (final slot in activeSlots) {
        final isActual = dayPlan.slotIsActual[slot.id] ?? false;
        final isCompleted = dayPlan.slotCompleted[slot.id] ?? false;
        final completedAt = dayPlan.slotCompletedAt[slot.id];
        final photoUrl = dayPlan.slotPhotoUrl[slot.id];
        final note = dayPlan.slotUserNote[slot.id];
        final aiBreakdown = dayPlan.slotAiBreakdown[slot.id];

        String? mealName;
        double? slotCal;
        double? slotProt;
        double? slotFat;
        double? slotCarb;
        double? slotFib;

        if (isActual) {
          hasAnyMeals = true;
          mealName = dayPlan.slotActualMealName[slot.id] ?? slot.name;
          slotCal = dayPlan.slotCalories[slot.id] ?? 0.0;
          slotProt = dayPlan.slotProtein[slot.id] ?? 0.0;
          slotFat = dayPlan.slotFats[slot.id] ?? 0.0;
          slotCarb = dayPlan.slotCarbs[slot.id] ?? 0.0;
          slotFib = dayPlan.slotFiber[slot.id] ?? 0.0;
        } else {
          // Check planned meals
          final mealIds = dayPlan.slotMeals[slot.id] ?? [];
          if (mealIds.isNotEmpty) {
            hasAnyMeals = true;
            final mealId = mealIds.first;
            final plannedMeal = state.mealsLibrary.firstWhere(
              (m) => m.id == mealId,
              orElse: () => Meal(name: 'Meal', category: slot.name, ingredients: const []),
            );
            mealName = plannedMeal.name;
            slotCal = plannedMeal.calories;
            slotProt = plannedMeal.protein;
            slotFat = plannedMeal.fats;
            slotCarb = plannedMeal.carbs;
            slotFib = plannedMeal.fiber;
          }
        }

        if (mealName != null) {
          dayCalories += slotCal ?? 0.0;
          dayProtein += slotProt ?? 0.0;
          dayFats += slotFat ?? 0.0;
          dayCarbs += slotCarb ?? 0.0;
          dayFiber += slotFib ?? 0.0;

          // Build ingredients / breakdown tags
          String breakdownDetailsHtml = '';
          if (aiBreakdown is List && aiBreakdown.isNotEmpty) {
            final itemsHtml = aiBreakdown.map((item) {
              if (item is Map) {
                final name = _escapeHtml(item['name']?.toString() ?? '');
                final weight = item['weight_g']?.toString() ?? '';
                final cal = item['calories']?.toString() ?? '';
                final weightStr = weight.isNotEmpty ? ' (${weight}g)' : '';
                final calStr = cal.isNotEmpty ? ' · $cal kcal' : '';
                return '<span class="breakdown-tag">$name$weightStr$calStr</span>';
              }
              return '';
            }).join('');
            if (itemsHtml.isNotEmpty) {
              breakdownDetailsHtml = '<div class="breakdown-list">$itemsHtml</div>';
            }
          }

          final timeStr = completedAt != null ? DateFormat('h:mm a').format(completedAt) : '';
          final statusBadge = isActual
              ? '<span class="badge badge-actual">Logged (AI)</span>'
              : (isCompleted
                  ? '<span class="badge badge-completed">Eaten</span>'
                  : '<span class="badge badge-planned">Planned</span>');

          final photoThumbnail = (photoUrl != null && photoUrl.isNotEmpty)
              ? '<img class="meal-thumb" src="$photoUrl" alt="Meal photo" loading="lazy" />'
              : '';

          final noteHtml = (note != null && note.trim().isNotEmpty)
              ? '<div class="meal-note">📝 ${_escapeHtml(note)}</div>'
              : '';

          mealsHtmlBuffer.write('''
            <div class="meal-card">
              <div class="meal-card-header">
                <div class="meal-slot-info">
                  <span class="slot-badge">${_escapeHtml(slot.name)}</span>
                  $statusBadge
                  ${timeStr.isNotEmpty ? '<span class="time-badge">⏱ $timeStr</span>' : ''}
                </div>
                <div class="meal-macros">
                  <span class="macro-pill cal">${(slotCal ?? 0).round()} kcal</span>
                  <span class="macro-pill prot">P: ${(slotProt ?? 0).toStringAsFixed(1)}g</span>
                  <span class="macro-pill fat">F: ${(slotFat ?? 0).toStringAsFixed(1)}g</span>
                  <span class="macro-pill carb">C: ${(slotCarb ?? 0).toStringAsFixed(1)}g</span>
                  ${(slotFib ?? 0) > 0 ? '<span class="macro-pill fiber">Fib: ${(slotFib ?? 0).toStringAsFixed(1)}g</span>' : ''}
                </div>
              </div>
              <div class="meal-card-body">
                $photoThumbnail
                <div class="meal-content">
                  <div class="meal-title">${_escapeHtml(mealName)}</div>
                  $breakdownDetailsHtml
                  $noteHtml
                </div>
              </div>
            </div>
          ''');
        }
      }

      if (hasAnyMeals) {
        loggedDaysCount++;
        totalCaloriesAllDays += dayCalories;
        totalProteinAllDays += dayProtein;
        totalFatsAllDays += dayFats;
        totalCarbsAllDays += dayCarbs;
        totalFiberAllDays += dayFiber;
      }

      final dayDiff = (dailyTarget - dayCalories).abs();
      final dayIsOver = dayCalories > dailyTarget;
      final statusClass = hasAnyMeals
          ? (dayIsOver ? 'status-over' : 'status-ok')
          : 'status-empty';
      final statusLabel = hasAnyMeals
          ? (dayIsOver ? '${dayDiff.round()} kcal over goal' : '${dayDiff.round()} kcal remaining')
          : 'No meals logged';

      final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(day);

      daysHtmlBuffer.write('''
        <div class="day-section">
          <div class="day-header">
            <div class="day-title-group">
              <h3 class="day-title">$formattedDate</h3>
              <span class="day-status $statusClass">$statusLabel</span>
            </div>
            <div class="day-summary-macros">
              <span class="macro-chip cal"><strong>${dayCalories.round()}</strong> / ${dailyTarget.round()} kcal</span>
              <span class="macro-chip prot">P: ${dayProtein.toStringAsFixed(1)}g</span>
              <span class="macro-chip fat">F: ${dayFats.toStringAsFixed(1)}g</span>
              <span class="macro-chip carb">C: ${dayCarbs.toStringAsFixed(1)}g</span>
              <span class="macro-chip fiber">Fib: ${dayFiber.toStringAsFixed(1)}g</span>
            </div>
          </div>
          <div class="day-meals">
            ${hasAnyMeals ? mealsHtmlBuffer.toString() : '<div class="empty-day-note">No meals recorded for this day.</div>'}
          </div>
        </div>
      ''');
    }

    final int divisor = loggedDaysCount > 0 ? loggedDaysCount : 1;
    final double avgCalories = totalCaloriesAllDays / divisor;
    final double avgProtein = totalProteinAllDays / divisor;
    final double avgFats = totalFatsAllDays / divisor;
    final double avgCarbs = totalCarbsAllDays / divisor;
    final double avgFiber = totalFiberAllDays / divisor;

    final dateRangeStr =
        '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    final generatedTimestamp =
        DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now());

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PlateMate Nutrition Report ($dateRangeStr)</title>
  <style>
    :root {
      --bg-dark: #090D16;
      --card-bg: #1E293B;
      --card-sub-bg: #0F172A;
      --border-color: #334155;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --accent: #38BDF8;
      --accent-muted: #38BDF8;
      --success: #10B981;
      --warning: #F59E0B;
      --danger: #EF4444;
      --protein-color: #EF4444;
      --fats-color: #EAB308;
      --carbs-color: #38BDF8;
      --fiber-color: #10B981;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg-dark);
      color: var(--text-primary);
      line-height: 1.5;
      padding: 24px 16px;
    }
    .container {
      max-width: 960px;
      margin: 0 auto;
    }
    /* Header Card */
    .header-card {
      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
      border: 1px solid var(--border-color);
      border-radius: 20px;
      padding: 24px;
      margin-bottom: 24px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
    }
    .header-top {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 16px;
      margin-bottom: 16px;
    }
    .brand-title {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      display: flex;
      align-items: center;
      gap: 10px;
      color: var(--accent);
    }
    .brand-title span {
      color: var(--text-primary);
    }
    .date-badge {
      background: rgba(56, 189, 248, 0.15);
      border: 1px solid rgba(56, 189, 248, 0.3);
      color: var(--accent);
      padding: 6px 14px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 600;
    }
    .header-meta {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      color: var(--text-secondary);
      font-size: 13px;
      gap: 10px;
    }
    /* Summary Grid */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
      gap: 12px;
      margin-bottom: 28px;
    }
    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 16px;
      text-align: center;
    }
    .stat-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-secondary);
      margin-bottom: 6px;
    }
    .stat-value {
      font-size: 20px;
      font-weight: 800;
      color: var(--text-primary);
    }
    .stat-sub {
      font-size: 11px;
      color: var(--text-secondary);
      margin-top: 4px;
    }
    .stat-card.cal .stat-value { color: var(--warning); }
    .stat-card.prot .stat-value { color: var(--protein-color); }
    .stat-card.fats .stat-value { color: var(--fats-color); }
    .stat-card.carbs .stat-value { color: var(--carbs-color); }
    .stat-card.fiber .stat-value { color: var(--fiber-color); }

    /* Day Section */
    .section-heading {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--text-primary);
    }
    .day-section {
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 18px;
      padding: 20px;
      margin-bottom: 20px;
    }
    .day-header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 14px;
      margin-bottom: 16px;
    }
    .day-title-group {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 10px;
    }
    .day-title {
      font-size: 16px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .day-status {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
    }
    .status-ok {
      background: rgba(16, 185, 129, 0.15);
      color: var(--success);
      border: 1px solid rgba(16, 185, 129, 0.3);
    }
    .status-over {
      background: rgba(239, 68, 68, 0.15);
      color: var(--danger);
      border: 1px solid rgba(239, 68, 68, 0.3);
    }
    .status-empty {
      background: rgba(148, 163, 184, 0.1);
      color: var(--text-secondary);
      border: 1px solid rgba(148, 163, 184, 0.2);
    }
    .day-summary-macros {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .macro-chip {
      font-size: 12px;
      background: var(--card-sub-bg);
      padding: 4px 8px;
      border-radius: 8px;
      border: 1px solid var(--border-color);
      color: var(--text-secondary);
    }
    .macro-chip.cal { color: var(--warning); font-weight: 600; }
    .macro-chip.prot { color: var(--protein-color); }
    .macro-chip.fat { color: var(--fats-color); }
    .macro-chip.carb { color: var(--carbs-color); }
    .macro-chip.fiber { color: var(--fiber-color); }

    /* Meal Cards */
    .day-meals {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .meal-card {
      background: var(--card-sub-bg);
      border: 1px solid var(--border-color);
      border-radius: 14px;
      padding: 14px;
    }
    .meal-card-header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }
    .meal-slot-info {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
    }
    .slot-badge {
      font-size: 11px;
      font-weight: 700;
      color: var(--accent);
      background: rgba(56, 189, 248, 0.1);
      padding: 2px 8px;
      border-radius: 6px;
      border: 1px solid rgba(56, 189, 248, 0.2);
    }
    .badge {
      font-size: 10px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 4px;
    }
    .badge-actual {
      background: rgba(16, 185, 129, 0.15);
      color: var(--success);
    }
    .badge-completed {
      background: rgba(56, 189, 248, 0.15);
      color: var(--accent);
    }
    .badge-planned {
      background: rgba(148, 163, 184, 0.15);
      color: var(--text-secondary);
    }
    .time-badge {
      font-size: 11px;
      color: var(--text-secondary);
    }
    .meal-macros {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }
    .macro-pill {
      font-size: 11px;
      font-weight: 600;
      padding: 2px 6px;
      border-radius: 4px;
    }
    .macro-pill.cal { background: rgba(245, 158, 11, 0.15); color: var(--warning); }
    .macro-pill.prot { background: rgba(239, 68, 68, 0.15); color: var(--protein-color); }
    .macro-pill.fat { background: rgba(234, 179, 8, 0.15); color: var(--fats-color); }
    .macro-pill.carb { background: rgba(56, 189, 248, 0.15); color: var(--carbs-color); }
    .macro-pill.fiber { background: rgba(16, 185, 129, 0.15); color: var(--fiber-color); }

    .meal-card-body {
      display: flex;
      gap: 14px;
      align-items: flex-start;
    }
    .meal-thumb {
      width: 64px;
      height: 64px;
      border-radius: 10px;
      object-fit: cover;
      border: 1px solid var(--border-color);
      flex-shrink: 0;
    }
    .meal-content {
      flex: 1;
    }
    .meal-title {
      font-size: 15px;
      font-weight: 700;
      color: var(--text-primary);
      margin-bottom: 6px;
    }
    .breakdown-list {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      margin-top: 6px;
    }
    .breakdown-tag {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 11px;
      color: var(--text-secondary);
    }
    .meal-note {
      font-size: 12px;
      color: var(--text-secondary);
      margin-top: 6px;
      font-style: italic;
    }
    .empty-day-note {
      color: var(--text-secondary);
      font-size: 13px;
      font-style: italic;
      padding: 12px 0;
    }
    .footer {
      text-align: center;
      color: var(--text-secondary);
      font-size: 12px;
      margin-top: 36px;
      padding-top: 16px;
      border-top: 1px solid var(--border-color);
    }
    /* Responsive styling */
    @media (max-width: 600px) {
      body { padding: 12px 8px; }
      .header-card { padding: 16px; }
      .day-section { padding: 14px; }
      .stats-grid { grid-template-columns: repeat(2, 1fr); }
      .meal-card-header { flex-direction: column; align-items: flex-start; }
    }
    /* Print Stylesheet */
    @media print {
      body {
        background-color: #FFFFFF !important;
        color: #000000 !important;
      }
      .header-card, .day-section, .stat-card, .meal-card {
        background-color: #FAFAFA !important;
        color: #000000 !important;
        border-color: #CCCCCC !important;
        box-shadow: none !important;
        page-break-inside: avoid;
      }
      .stat-value, .day-title, .meal-title {
        color: #000000 !important;
      }
      .brand-title span { color: #000000 !important; }
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Header -->
    <header class="header-card">
      <div class="header-top">
        <div class="brand-title">
          🥗 <span>PlateMate</span> Nutrition Report
        </div>
        <div class="date-badge">$dateRangeStr</div>
      </div>
      <div class="header-meta">
        <div><strong>User:</strong> ${_escapeHtml(userEmail ?? 'PlateMate User')}</div>
        <div><strong>Target:</strong> ${dailyTarget.round()} kcal / day</div>
        <div><strong>Generated:</strong> $generatedTimestamp</div>
      </div>
    </header>

    <!-- Summary Stats -->
    <section class="stats-grid">
      <div class="stat-card cal">
        <div class="stat-label">Avg Daily Calories</div>
        <div class="stat-value">${avgCalories.round()} <small style="font-size: 12px; font-weight: normal;">kcal</small></div>
        <div class="stat-sub">Goal: ${dailyTarget.round()} kcal</div>
      </div>
      <div class="stat-card prot">
        <div class="stat-label">Avg Protein</div>
        <div class="stat-value">${avgProtein.toStringAsFixed(1)}g</div>
        <div class="stat-sub">${(avgProtein * 4).round()} kcal</div>
      </div>
      <div class="stat-card fats">
        <div class="stat-label">Avg Fats</div>
        <div class="stat-value">${avgFats.toStringAsFixed(1)}g</div>
        <div class="stat-sub">${(avgFats * 9).round()} kcal</div>
      </div>
      <div class="stat-card carbs">
        <div class="stat-label">Avg Carbs</div>
        <div class="stat-value">${avgCarbs.toStringAsFixed(1)}g</div>
        <div class="stat-sub">${(avgCarbs * 4).round()} kcal</div>
      </div>
      <div class="stat-card fiber">
        <div class="stat-label">Avg Fiber</div>
        <div class="stat-value">${avgFiber.toStringAsFixed(1)}g</div>
        <div class="stat-sub">Digestive Health</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Logged Days</div>
        <div class="stat-value">$loggedDaysCount / $totalDaysCount</div>
        <div class="stat-sub">${((loggedDaysCount / totalDaysCount) * 100).round()}% active</div>
      </div>
    </section>

    <!-- Day by Day Breakdown -->
    <div class="section-heading">📅 Day-by-Day Nutrition Log</div>
    ${daysHtmlBuffer.toString()}

    <!-- Footer -->
    <footer class="footer">
      Generated by PlateMate App &bull; Clean Eating & Smart Nutrition Planning
    </footer>
  </div>
</body>
</html>''';
  }

  /// Exports the report to an HTML file and invokes the native system share sheet.
  static Future<void> exportAndShareReport({
    required BuildContext context,
    required DietState state,
    required DateTime startDate,
    required DateTime endDate,
    String? userEmail,
  }) async {
    try {
      final htmlContent = generateHtmlReport(
        state: state,
        startDate: startDate,
        endDate: endDate,
        userEmail: userEmail,
      );

      final tempDir = await getTemporaryDirectory();
      final startStr = DateFormat('yyyyMMdd').format(startDate);
      final endStr = DateFormat('yyyyMMdd').format(endDate);
      final fileName = 'platemate_report_${startStr}_to_$endStr.html';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(htmlContent);

      if (!context.mounted) return;

      final humanStart = DateFormat('MMM d').format(startDate);
      final humanEnd = DateFormat('MMM d, yyyy').format(endDate);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html', name: fileName)],
        subject: 'PlateMate Nutrition Report ($humanStart - $humanEnd)',
        text: 'PlateMate Nutrition Report from $humanStart to $humanEnd',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
