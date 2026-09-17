import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/app_currency.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';

class PdfReportService {
  /// Loads Arabic Cairo fonts with local asset caching and Google Fonts fallback
  static Future<pw.ThemeData> _loadArabicTheme() async {
    pw.Font fontRegular;
    pw.Font fontBold;

    try {
      final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      fontRegular = pw.Font.ttf(regularData);
      fontBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('[PdfReportService] Error loading local Cairo font assets: $e');
      try {
        fontRegular = await PdfGoogleFonts.cairoRegular();
        fontBold = await PdfGoogleFonts.cairoBold();
      } catch (e2) {
        debugPrint('[PdfReportService] Error loading Cairo from GoogleFonts: $e2');
        throw Exception('فشل تحميل الخط العربي (Cairo): $e2');
      }
    }

    return pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );
  }

  // ================= Bidi PDF Formatting Helpers =================

  /// Builds a directionality-safe amount row to prevent Arabic Bidi number/symbol flipping
  static pw.Widget _buildAmountText(
    double amount,
    AppCurrency currency, {
    pw.TextStyle? style,
    bool showDecimals = false,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            CurrencyFormatter.formatAmount(amount, showDecimals: showDecimals),
            textDirection: pw.TextDirection.ltr,
            style: style,
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            currency.symbol,
            textDirection: pw.TextDirection.ltr,
            style: style,
          ),
        ],
      ),
    );
  }

  /// Builds a labeled row
  static pw.Widget _buildLabeledRow(
    String label,
    String value, {
    pw.TextStyle? labelStyle,
    pw.TextStyle? valueStyle,
    bool valueIsLtr = false,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: labelStyle),
          pw.SizedBox(width: 4),
          pw.Text(
            value,
            textDirection: valueIsLtr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
            style: valueStyle ?? labelStyle,
          ),
        ],
      ),
    );
  }

  // ================= 1. Monthly Financial Report =================

  /// Generates a multi-page PDF document for the Monthly Financial & Budget Report
  static Future<Uint8List> generateMonthlyReportBytes({
    required DateTime month,
    required List<TransactionModel> allTransactions,
    List<CategoryModel> categories = const [],
    AppCurrency? currency,
  }) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    // Filter transactions for target month and currency (excluding wallet transfers)
    final monthlyTransactions = allTransactions.where((t) {
      if (t.isWalletTransfer) return false;
      if (t.date.year != month.year || t.date.month != month.month) return false;
      if (currency != null && t.currency != currency) return false;
      return true;
    }).toList();

    // Identify active currencies
    final targetCurrencies = currency != null
        ? [currency]
        : (monthlyTransactions.map((t) => t.currency).toSet().toList());

    if (targetCurrencies.isEmpty) {
      targetCurrencies.add(AppCurrency.yer);
    }

    final primaryColor = PdfColor.fromHex('#0D9488'); // Teal
    final incomeColor = PdfColor.fromHex('#10B981'); // Green
    final expenseColor = PdfColor.fromHex('#EF4444'); // Red
    final textColor = PdfColor.fromHex('#0F172A');
    final subtextColor = PdfColor.fromHex('#64748B');
    final monthNameAr = DateFormatter.formatMonthYear(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'التقرير المالي الشهري والميزانية',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'تطبيق ميزانيتي لإدارة المصاريف والميزانية',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'الفترة: $monthNameAr',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    _buildLabeledRow(
                      'تاريخ الطباعة: ',
                      DateFormatter.formatDate(DateTime.now()),
                      labelStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueIsLtr: true,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'تم استخراج التقرير بواسطة تطبيق ميزانيتي',
                  style: pw.TextStyle(fontSize: 8, color: subtextColor),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: subtextColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          for (final cur in targetCurrencies) {
            final curTx = monthlyTransactions.where((t) => t.currency == cur).toList();
            final totalIncome = curTx
                .where((t) => t.type == TransactionType.income)
                .fold(0.0, (sum, t) => sum + t.amount);
            final totalExpense = curTx
                .where((t) => t.type == TransactionType.expense)
                .fold(0.0, (sum, t) => sum + t.amount);
            final netSavings = totalIncome - totalExpense;

            // Section currency header if multiple currencies
            if (targetCurrencies.length > 1) {
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 10, bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F1F5F9'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'العملة: ${cur.nameAr} (${cur.symbol})',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                ),
              );
            }

            // Summary Cards (Income, Expense, Net, Count)
            widgets.add(
              pw.Row(
                children: [
                  // Total Income
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F0FDF4'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('إجمالي الدخل', style: pw.TextStyle(fontSize: 9, color: incomeColor)),
                          pw.SizedBox(height: 4),
                          _buildAmountText(
                            totalIncome,
                            cur,
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: incomeColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Total Expense
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FFF1F2'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#FECDD3')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('إجمالي المصروفات', style: pw.TextStyle(fontSize: 9, color: expenseColor)),
                          pw.SizedBox(height: 4),
                          _buildAmountText(
                            totalExpense,
                            cur,
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: expenseColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Net Balance
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            netSavings >= 0 ? 'صافي الوفر' : 'العجز المالي',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: netSavings >= 0 ? incomeColor : expenseColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildAmountText(
                            netSavings.abs(),
                            cur,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: netSavings >= 0 ? incomeColor : expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Transactions Count
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('عدد العمليات', style: pw.TextStyle(fontSize: 9, color: subtextColor)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${curTx.length} عملية',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            widgets.add(pw.SizedBox(height: 16));

            // Breakdown by Category Table
            widgets.add(
              pw.Text(
                'تفصيل المصروفات والدخل حسب التصنيف:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textColor),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            // Group by category
            final Map<String, List<TransactionModel>> catMap = {};
            for (final t in curTx) {
              final key = t.categoryName.isNotEmpty ? t.categoryName : 'بدون تصنيف';
              catMap.putIfAbsent(key, () => []).add(t);
            }

            final sortedCategories = catMap.keys.toList()
              ..sort((a, b) {
                final sumA = catMap[a]!.fold(0.0, (s, t) => s + t.amount);
                final sumB = catMap[b]!.fold(0.0, (s, t) => s + t.amount);
                return sumB.compareTo(sumA);
              });

            if (sortedCategories.isEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'لا توجد عمليات مسجلة خلال هذا الشهر',
                    style: pw.TextStyle(fontSize: 10, color: subtextColor),
                  ),
                ),
              );
            } else {
              int rowIdx = 1;
              final tableData = <List<String>>[];

              for (final catName in sortedCategories) {
                final txs = catMap[catName]!;
                final isExpense = txs.first.type == TransactionType.expense;
                final catTotal = txs.fold(0.0, (s, t) => s + t.amount);
                final baseTotal = isExpense ? totalExpense : totalIncome;
                final percentage = baseTotal > 0 ? (catTotal / baseTotal * 100) : 0.0;

                tableData.add([
                  rowIdx.toString(),
                  catName,
                  isExpense ? 'مصروف' : 'دخل',
                  txs.length.toString(),
                  '${CurrencyFormatter.formatAmount(catTotal)} ${cur.symbol}',
                  '${percentage.toStringAsFixed(1)}%',
                ]);
                rowIdx++;
              }

              widgets.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.6),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
                  headerHeight: 24,
                  cellHeight: 22,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: textColor,
                  ),
                  cellStyle: pw.TextStyle(
                    fontSize: 8.5,
                    color: textColor,
                  ),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.center,
                  },
                  headers: ['#', 'التصنيف', 'النوع', 'العمليات', 'الإجمالي', 'النسبة'],
                  data: tableData,
                ),
              );
            }

            widgets.add(pw.SizedBox(height: 20));
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // ================= 2. Category-Specific Report =================

  /// Generates a PDF document for a single category with its full transaction details
  static Future<Uint8List> generateCategoryReportBytes({
    required CategoryModel category,
    required DateTime month,
    required List<TransactionModel> categoryTransactions,
    AppCurrency? currency,
  }) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    final targetCurrency = currency ?? (categoryTransactions.isNotEmpty ? categoryTransactions.first.currency : AppCurrency.yer);
    final isExpense = category.isExpense;
    final incomeColor = PdfColor.fromHex('#10B981');
    final expenseColor = PdfColor.fromHex('#EF4444');
    final primaryColor = isExpense ? expenseColor : incomeColor;
    final textColor = PdfColor.fromHex('#0F172A');
    final subtextColor = PdfColor.fromHex('#64748B');
    final monthNameAr = DateFormatter.formatMonthYear(month);

    // Filter transactions for this specific category, month, and currency
    final filteredTransactions = categoryTransactions.where((t) {
      if (t.isWalletTransfer) return false;
      if (t.date.year != month.year || t.date.month != month.month) return false;
      if (currency != null && t.currency != currency) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalAmount = filteredTransactions.fold(0.0, (s, t) => s + t.amount);
    final budget = category.getBudgetForCurrency(targetCurrency);
    final hasBudget = budget > 0 && isExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'كشف حساب تصنيف: ${category.name}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'النوع: ${isExpense ? "مصروفات" : "إيرادات / دخل"} - تطبيق ميزانيتي',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'الشهر: $monthNameAr',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    _buildLabeledRow(
                      'تاريخ الطباعة: ',
                      DateFormatter.formatDate(DateTime.now()),
                      labelStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueIsLtr: true,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'تصنيف: ${category.name} | تطبيق ميزانيتي',
                  style: pw.TextStyle(fontSize: 8, color: subtextColor),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: subtextColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          // Summary Statistics Cards
          widgets.add(
            pw.Row(
              children: [
                // Total Spent / Received
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: isExpense ? PdfColor.fromHex('#FFF1F2') : PdfColor.fromHex('#F0FDF4'),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                        color: isExpense ? PdfColor.fromHex('#FECDD3') : PdfColor.fromHex('#BBF7D0'),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isExpense ? 'إجمالي المنفق في التصنيف' : 'إجمالي الدخل المحصل',
                          style: pw.TextStyle(fontSize: 9, color: primaryColor),
                        ),
                        pw.SizedBox(height: 4),
                        _buildAmountText(
                          totalAmount,
                          targetCurrency,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),

                // Transactions Count
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('عدد العمليات', style: pw.TextStyle(fontSize: 9, color: subtextColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${filteredTransactions.length} عملية',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),

                // Budget Limit Card if set
                if (hasBudget) ...[
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('سقف الميزانية الشهري', style: pw.TextStyle(fontSize: 9, color: subtextColor)),
                          pw.SizedBox(height: 4),
                          _buildAmountText(
                            budget,
                            targetCurrency,
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: totalAmount > budget ? PdfColor.fromHex('#FFF1F2') : PdfColor.fromHex('#F0FDF4'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(
                          color: totalAmount > budget ? PdfColor.fromHex('#FECDD3') : PdfColor.fromHex('#BBF7D0'),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            totalAmount > budget ? 'تجاوز الميزانية بمقدار' : 'المتبقي من السقف',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: totalAmount > budget ? expenseColor : incomeColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildAmountText(
                            (budget - totalAmount).abs(),
                            targetCurrency,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: totalAmount > budget ? expenseColor : incomeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 18));

          // Transactions Table Title
          widgets.add(
            pw.Text(
              'سجل العمليات التفصيلي خلال شهر $monthNameAr:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
          );
          widgets.add(pw.SizedBox(height: 8));

          if (filteredTransactions.isEmpty) {
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Text(
                  'لا توجد عمليات مسجلة لهذا التصنيف في هذا الشهر',
                  style: pw.TextStyle(fontSize: 11, color: subtextColor),
                ),
              ),
            );
          } else {
            final tableData = <List<String>>[];
            int idx = 1;

            for (final t in filteredTransactions) {
              tableData.add([
                idx.toString(),
                DateFormatter.formatDate(t.date),
                t.title.isNotEmpty ? t.title : category.name,
                (t.notes != null && t.notes!.trim().isNotEmpty) ? t.notes!.trim() : '-',
                '${CurrencyFormatter.formatAmount(t.amount)} ${t.currency.symbol}',
              ]);
              idx++;
            }

            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.6),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
                headerHeight: 26,
                cellHeight: 22,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9.5,
                  color: textColor,
                ),
                cellStyle: pw.TextStyle(
                  fontSize: 8.5,
                  color: textColor,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerLeft,
                },
                headers: ['#', 'التاريخ', 'البيان', 'الملاحظات', 'المبلغ'],
                data: tableData,
              ),
            );

            // Total Summary Row Container
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'الإجمالي الكلي (${filteredTransactions.length} عملية):',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor),
                    ),
                    _buildAmountText(
                      totalAmount,
                      targetCurrency,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // ================= 3. Interactive Modal UI for Print & Share =================

  /// Displays an interactive modal sheet allowing user to Preview/Print or Share the PDF
  static Future<void> showReportModal(
    BuildContext context, {
    required String title,
    required String filename,
    required Future<Uint8List> Function() onGenerateBytes,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isGenerating = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryTeal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'تصدير وطباعة تقرير بتنسيق PDF احترافي مع دعم كامل للغة العربية',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (isGenerating) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('جاري إنشاء التقرير المالي وتنسيقه...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Option 1: Preview & Print
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.print_rounded, color: AppColors.primaryTeal),
                        ),
                        title: const Text('معاينة وطباعة التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('فتح عارض الطباعة لحفظه كملف PDF أو إرساله للطابعة', style: TextStyle(fontSize: 11)),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            setSheetState(() => isGenerating = true);
                            final bytes = await onGenerateBytes();
                            navigator.pop();
                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async => bytes,
                              name: filename,
                            );
                          } catch (e) {
                            debugPrint('[PdfReportService] Error printing report: $e');
                            if (ctx.mounted) setSheetState(() => isGenerating = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ أثناء إعداد التقرير: $e'),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        },
                      ),

                      const Divider(height: 12),

                      // Option 2: Share via external apps
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_rounded, color: Colors.deepPurple),
                        ),
                        title: const Text('مشاركة ملف التقرير (Share)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('إرسال ملف الـ PDF عبر واتساب، تيليجرام أو تطبيقات المشاركة', style: TextStyle(fontSize: 11)),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            setSheetState(() => isGenerating = true);
                            final bytes = await onGenerateBytes();
                            navigator.pop();
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: filename,
                            );
                          } catch (e) {
                            debugPrint('[PdfReportService] Error sharing report: $e');
                            if (ctx.mounted) setSheetState(() => isGenerating = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ أثناء مشاركة التقرير: $e'),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
