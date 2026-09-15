import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/debt_model.dart';
import '../models/person_model.dart';
import '../models/transaction_model.dart';
import '../models/app_currency.dart';
import '../providers/debt_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';

class PdfStatementService {
  static Future<pw.ThemeData> _loadArabicTheme() async {
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      fontRegular = pw.Font.ttf(regularData);
      fontBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('[PdfStatementService] Error loading local font assets: $e');
      try {
        fontRegular = await PdfGoogleFonts.cairoRegular();
        fontBold = await PdfGoogleFonts.cairoBold();
      } catch (e2) {
        debugPrint('[PdfStatementService] Error loading GoogleFonts: $e2');
        throw Exception('فشل تحميل الخط العربي (Cairo): $e');
      }
    }

    return pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );
  }

  // ================= Bidi PDF Formatting Helpers =================

  /// Builds a separated Row for amounts and currency to prevent Bidi text overlap
  static pw.Widget _buildAmountRow({
    String? label,
    required double amount,
    required AppCurrency currency,
    pw.TextStyle? labelStyle,
    pw.TextStyle? amountStyle,
    pw.TextStyle? currencyStyle,
    pw.MainAxisSize mainAxisSize = pw.MainAxisSize.min,
    pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.start,
    bool showDecimals = false,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: mainAxisAlignment,
        children: [
          if (label != null && label.isNotEmpty) ...[
            pw.Text(label, style: labelStyle),
            pw.SizedBox(width: 6),
          ],
          pw.Text(
            CurrencyFormatter.formatAmount(amount, showDecimals: showDecimals),
            textDirection: pw.TextDirection.ltr,
            style: amountStyle ?? labelStyle,
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            currency.symbol,
            textDirection: pw.TextDirection.ltr,
            style: currencyStyle ?? amountStyle ?? labelStyle,
          ),
        ],
      ),
    );
  }

  /// Builds a separated Row for labeled text to prevent Bidi reversal
  static pw.Widget _buildLabeledTextRow({
    required String label,
    required String value,
    pw.TextStyle? labelStyle,
    pw.TextStyle? valueStyle,
    bool valueIsLtr = false,
    pw.MainAxisSize mainAxisSize = pw.MainAxisSize.min,
    pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.start,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: mainAxisAlignment,
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

  // ================= 1. Debt Single Statement =================

  /// Builds PDF document bytes for a single debt
  static Future<Uint8List> generateDebtStatementBytes(DebtModel debt) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    final isForMe = debt.type == DebtType.forMe;
    final primaryColor = isForMe ? PdfColor.fromHex('#0D9488') : PdfColor.fromHex('#E11D48');
    final secondaryColor = PdfColor.fromHex('#F8FAFC');
    final textColor = PdfColor.fromHex('#0F172A');
    final subtextColor = PdfColor.fromHex('#64748B');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            debt.isSettled ? 'سند براءة ذمة مالية (مسدد بالكامل)' : 'كشف حساب مالي - سند دين',
                            style: pw.TextStyle(
                              fontSize: 17,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'تطبيق ميزانيتي لإدارة المصاريف والديون',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _buildLabeledTextRow(
                            label: 'تاريخ التقرير:',
                            value: DateFormatter.formatDate(DateTime.now()),
                            labelStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                            valueStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                            valueIsLtr: true,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text('العملة:', style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.white)),
                                pw.SizedBox(width: 4),
                                pw.Text(debt.currency.nameAr, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                pw.SizedBox(width: 4),
                                pw.Text('(${debt.currency.symbol})', textDirection: pw.TextDirection.ltr, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 18),

                // Party & Debt Info Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: secondaryColor,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildLabeledTextRow(
                            label: 'الطرف المعني:',
                            value: debt.personName,
                            labelStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textColor),
                            valueStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textColor),
                          ),
                          if (debt.phone != null && debt.phone!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            _buildLabeledTextRow(
                              label: 'رقم الهاتف:',
                              value: debt.phone!,
                              labelStyle: pw.TextStyle(fontSize: 10.5, color: subtextColor),
                              valueStyle: pw.TextStyle(fontSize: 10.5, color: subtextColor),
                              valueIsLtr: true,
                            ),
                          ],
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: debt.isSettled ? PdfColor.fromHex('#10B981') : primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          debt.isSettled ? '✓ خالص ومسدد بالكامل' : debt.type.nameAr,
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 14),

                // 3 Summary Boxes (Total, Paid, Remaining)
                pw.Row(
                  children: [
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
                            pw.Text('إجمالي الدين الأصلي', style: pw.TextStyle(fontSize: 9.5, color: subtextColor)),
                            pw.SizedBox(height: 4),
                            _buildAmountRow(
                              amount: debt.totalAmount,
                              currency: debt.currency,
                              amountStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor),
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
                          color: PdfColor.fromHex('#F0FDF4'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0')),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('المبلغ المسدد', style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#16A34A'))),
                            pw.SizedBox(height: 4),
                            _buildAmountRow(
                              amount: debt.paidAmount,
                              currency: debt.currency,
                              amountStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#16A34A')),
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
                          color: debt.isSettled ? PdfColor.fromHex('#F0FDF4') : PdfColor.fromHex('#FFF1F2'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: debt.isSettled ? PdfColor.fromHex('#BBF7D0') : PdfColor.fromHex('#FECDD3'),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('المبلغ المتبقي', style: pw.TextStyle(fontSize: 9.5, color: debt.isSettled ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#E11D48'))),
                            pw.SizedBox(height: 4),
                            _buildAmountRow(
                              amount: debt.remainingAmount,
                              currency: debt.currency,
                              amountStyle: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: debt.isSettled ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#E11D48'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Table Title
                pw.Text(
                  'سجل الدفعات والتسديدات:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Payments Table
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
                  headerHeight: 26,
                  cellHeight: 24,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: textColor,
                  ),
                  cellStyle: pw.TextStyle(
                    fontSize: 9.5,
                    color: textColor,
                  ),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                  },
                  headers: ['#', 'التاريخ', 'البيان', 'مدين', 'دائن'],
                  data: () {
                    final entries = <Map<String, dynamic>>[];
                    final isForMe = debt.type == DebtType.forMe;

                    // Debt creation entry
                    entries.add({
                      'date': debt.createdAt,
                      'description': 'دين جديد (${debt.type.nameAr})',
                      'debit': isForMe ? debt.totalAmount : 0.0,
                      'credit': !isForMe ? debt.totalAmount : 0.0,
                    });

                    // Payments
                    for (final p in debt.payments) {
                      entries.add({
                        'date': p.date,
                        'description': (p.note != null && p.note!.isNotEmpty) ? p.note! : 'دفعة سداد',
                        'debit': !isForMe ? p.amount : 0.0,
                        'credit': isForMe ? p.amount : 0.0,
                      });
                    }

                    entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

                    double totalDebit = 0.0;
                    double totalCredit = 0.0;
                    for (final e in entries) {
                      totalDebit += (e['debit'] as double);
                      totalCredit += (e['credit'] as double);
                    }
                    final net = totalDebit - totalCredit;

                    final rows = List.generate(entries.length, (i) {
                      final e = entries[i];
                      return [
                        '${i + 1}',
                        DateFormatter.formatDate(e['date'] as DateTime),
                        e['description'].toString(),
                        CurrencyFormatter.formatAmount(e['debit'] as double),
                        CurrencyFormatter.formatAmount(e['credit'] as double),
                      ];
                    });

                    rows.add([
                      '',
                      '',
                      'الإجمالي وصافي الحساب',
                      CurrencyFormatter.formatAmount(totalDebit),
                      CurrencyFormatter.formatAmount(totalCredit),
                    ]);
                    rows.add([
                      '',
                      '',
                      'الصافي (رصيد ${net > 0 ? "لك" : net < 0 ? "عليك" : "خالص"})',
                      '',
                      '${CurrencyFormatter.formatAmount(net.abs())} ${debt.currency.symbol}',
                    ]);

                    return rows;
                  }(),
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'تطبيق ميزانيتي • طور بواسطة م/ نسيم مزاحم',
                      style: pw.TextStyle(fontSize: 9, color: subtextColor),
                    ),
                    pw.Text(
                      debt.isSettled ? 'سند براءة ذمة معتمد من التطبيق' : 'كشف صادر تلقائياً ولا يتطلب ختماً ورقياً',
                      style: pw.TextStyle(fontSize: 9, color: subtextColor),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ================= 2. Person Detailed Ledger Statement =================

  /// Builds PDF document bytes for a Person's comprehensive account statement
  static Future<Uint8List> generatePersonStatementBytes(
    PersonModel person,
    List<DebtModel> debts,
    DebtProvider provider, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    final primaryColor = PdfColor.fromHex('#0D9488');
    final textColor = PdfColor.fromHex('#0F172A');
    final subtextColor = PdfColor.fromHex('#64748B');
    var allPayments = provider.getAllPaymentsForPerson(person.id);

    // Apply date filtering if provided
    if (startDate != null && endDate != null) {
      final sDate = DateTime(startDate.year, startDate.month, startDate.day);
      final eDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      debts = debts.where((d) {
        final dDate = DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
        return dDate.isAtSameMomentAs(sDate) || dDate.isAtSameMomentAs(eDate) ||
               (dDate.isAfter(sDate) && dDate.isBefore(eDate));
      }).toList();

      allPayments = allPayments.where((p) {
        final pDate = DateTime(p.date.year, p.date.month, p.date.day);
        return pDate.isAtSameMomentAs(sDate) || pDate.isAtSameMomentAs(eDate) ||
               (pDate.isAfter(sDate) && pDate.isBefore(eDate));
      }).toList();
    }

    // Active currencies for this person
    final currencies = AppCurrency.values.where((c) {
      return debts.any((d) => d.currency == c) || 
             allPayments.any((p) {
                final debt = provider.findDebtById(p.debtId);
                return debt?.currency == c;
             });
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'كشف حساب مالي تفصيلي (سجل الأستاذ)',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text('الطرف:', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(person.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                  if (person.phone != null && person.phone!.isNotEmpty) ...[
                                    pw.SizedBox(width: 6),
                                    pw.Text('(${person.phone})', textDirection: pw.TextDirection.ltr, style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _buildLabeledTextRow(
                              label: 'تاريخ التقرير:',
                              value: DateFormatter.formatDate(DateTime.now()),
                              labelStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                              valueStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                              valueIsLtr: true,
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'تطبيق ميزانيتي',
                              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // Net Balance Cards per Currency
                  pw.Text(
                    'ملخص الأرصدة الصافية بين الطرفين:',
                    style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: textColor),
                  ),
                  pw.SizedBox(height: 6),

                  pw.Row(
                    children: currencies.isEmpty
                        ? [
                            pw.Text(
                              'لا توجد عمليات مسجلة لهذا الحساب حالياً.',
                              style: pw.TextStyle(fontSize: 10, color: subtextColor),
                            ),
                          ]
                        : currencies.map((cur) {
                            final lent = provider.getRemainingLentForPerson(person.id, cur);
                            final borrowed = provider.getRemainingBorrowedForPerson(person.id, cur);
                            final net = lent - borrowed;
                            final isPositive = net > 0;
                            final isZero = net.abs() < 0.01;

                            return pw.Expanded(
                              child: pw.Container(
                                margin: const pw.EdgeInsets.only(left: 6),
                                padding: const pw.EdgeInsets.all(8),
                                decoration: pw.BoxDecoration(
                                  color: isZero
                                      ? PdfColor.fromHex('#F1F5F9')
                                      : isPositive
                                          ? PdfColor.fromHex('#F0FDF4')
                                          : PdfColor.fromHex('#FFF1F2'),
                                  borderRadius: pw.BorderRadius.circular(8),
                                  border: pw.Border.all(
                                    color: isZero
                                        ? PdfColor.fromHex('#CBD5E1')
                                        : isPositive
                                            ? PdfColor.fromHex('#86EFAC')
                                            : PdfColor.fromHex('#FECDD3'),
                                  ),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Directionality(
                                      textDirection: pw.TextDirection.rtl,
                                      child: pw.Row(
                                        mainAxisSize: pw.MainAxisSize.min,
                                        children: [
                                          pw.Text(
                                            cur.nameAr,
                                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textColor),
                                          ),
                                          pw.SizedBox(width: 4),
                                          pw.Text(
                                            '(${cur.symbol})',
                                            textDirection: pw.TextDirection.ltr,
                                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    if (isZero)
                                      pw.Text(
                                        'الحساب خالص',
                                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor),
                                      )
                                    else
                                      _buildAmountRow(
                                        label: isPositive ? 'لك عنده:' : 'له عندك:',
                                        amount: net.abs(),
                                        currency: cur,
                                        labelStyle: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: isPositive ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#E11D48'),
                                        ),
                                        amountStyle: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: isPositive ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#E11D48'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                  ),

                  pw.SizedBox(height: 20),

                  // Generate a ledger table for each currency
                  if (currencies.isNotEmpty)
                    ...currencies.map((cur) {
                      // 1. Filter debts and payments for this currency
                      final curDebts = debts.where((d) => d.currency == cur).toList();
                      final curPayments = allPayments.where((p) {
                        final debt = debts.firstWhere((d) => d.id == p.debtId, orElse: () => debts.first);
                        return debt.currency == cur;
                      }).toList();

                      // 2. Build ledger entries
                      // Entry format: {date, description, debit, credit}
                      final entries = <Map<String, dynamic>>[];

                      for (final d in curDebts) {
                        final isForMe = d.type == DebtType.forMe;
                        entries.add({
                          'date': d.createdAt,
                          'description': 'دين جديد (${d.type.nameAr})',
                          'debit': isForMe ? d.totalAmount : 0.0,
                          'credit': !isForMe ? d.totalAmount : 0.0,
                        });
                      }

                      for (final p in curPayments) {
                        final debt = debts.firstWhere((d) => d.id == p.debtId);
                        final isForMe = debt.type == DebtType.forMe;
                        // Payment against a "forMe" debt is a credit (they paid us).
                        // Payment against a "onMe" debt is a debit (we paid them).
                        entries.add({
                          'date': p.date,
                          'description': (p.note != null && p.note!.isNotEmpty) ? p.note! : 'دفعة سداد',
                          'debit': !isForMe ? p.amount : 0.0,
                          'credit': isForMe ? p.amount : 0.0,
                        });
                      }

                      // Sort entries by date
                      entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

                      // Calculate totals
                      double totalDebit = 0.0;
                      double totalCredit = 0.0;
                      for (final e in entries) {
                        totalDebit += (e['debit'] as double);
                        totalCredit += (e['credit'] as double);
                      }
                      final net = totalDebit - totalCredit;

                      // Build rows
                      final rows = List.generate(entries.length, (i) {
                        final e = entries[i];
                        return [
                          '${i + 1}',
                          DateFormatter.formatDate(e['date'] as DateTime),
                          e['description'].toString(),
                          CurrencyFormatter.formatAmount(e['debit'] as double),
                          CurrencyFormatter.formatAmount(e['credit'] as double),
                        ];
                      });

                      // Add summary row
                      rows.add([
                        '',
                        '',
                        'الإجمالي وصافي الحساب',
                        CurrencyFormatter.formatAmount(totalDebit),
                        CurrencyFormatter.formatAmount(totalCredit),
                      ]);
                      rows.add([
                        '',
                        '',
                        'الصافي (رصيد ${net > 0 ? "لك" : net < 0 ? "عليك" : "خالص"})',
                        '',
                        '${CurrencyFormatter.formatAmount(net.abs())} ${cur.symbol}',
                      ]);

                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  'سجل حركات العملة:',
                                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: textColor),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text(
                                  cur.nameAr,
                                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text(
                                  '(${cur.symbol})',
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.TableHelper.fromTextArray(
                            border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.7),
                            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
                            headerHeight: 24,
                            cellHeight: 22,
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: textColor),
                            cellStyle: pw.TextStyle(fontSize: 9, color: textColor),
                            cellAlignments: {
                              0: pw.Alignment.center,
                              1: pw.Alignment.centerRight,
                              2: pw.Alignment.centerRight,
                              3: pw.Alignment.centerLeft,
                              4: pw.Alignment.centerLeft,
                            },
                            headers: ['#', 'التاريخ', 'البيان', 'مدين', 'دائن'],
                            data: rows,
                          ),
                          pw.SizedBox(height: 16),
                        ],
                      );
                    }),

                  pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'كشف حساب صادر تلقائياً من تطبيق ميزانيتي • مطور بواسطة م/ نسيم مزاحم',
                    style: pw.TextStyle(fontSize: 8.5, color: subtextColor),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ================= 3. Export / Save / Share Handlers =================

  /// Interactive BottomSheet with Export Options (Print / Save as PDF, Share via WhatsApp/Apps)
  static Future<void> showPdfOptionsBottomSheet({
    required BuildContext context,
    required String title,
    required Future<Uint8List> Function() generateBytes,
    required String filename,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Material(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      if (isGenerating) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryTeal),
                              SizedBox(height: 12),
                              Text('جاري إنشاء وتجهيز ملف الـ PDF...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ] else ...[
                        // 1. Save as PDF via FilePicker
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.download_rounded, color: AppColors.income),
                          ),
                          title: const Text('حفظ كملف PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('تحديد مجلد على الهاتف وحفظ الملف مباشرة', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating PDF for save: $filename');
                              final bytes = await generateBytes();
                              debugPrint('PDF generated successfully, size: ${bytes.length} bytes');

                              String? selectedPath;
                              try {
                                selectedPath = await FilePicker.platform.saveFile(
                                  dialogTitle: 'حفظ كشف الحساب',
                                  fileName: filename,
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  bytes: bytes,
                                );
                              } catch (e) {
                                debugPrint('[PdfStatementService] FilePicker error: $e');
                              }

                              if (selectedPath != null) {
                                final file = File(selectedPath);
                                if (!await file.exists() || await file.length() == 0) {
                                  await file.writeAsBytes(bytes);
                                }
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('تم حفظ ملف الـ PDF بنجاح في:\n$selectedPath'),
                                    backgroundColor: AppColors.income,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                if (ctx.mounted) {
                                  setSheetState(() => isGenerating = false);
                                }
                              }
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء حفظ ملف الـ PDF: $e'),
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                          },
                        ),

                        const Divider(height: 12),

                        // 2. Print via System Print Framework
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded, color: AppColors.primaryTeal),
                          ),
                          title: const Text('طباعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('فتح نافذة الطباعة الرسمية للنظام والمعاينة', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating PDF for print: $filename');
                              final bytes = await generateBytes();
                              debugPrint('PDF generated successfully, size: ${bytes.length} bytes');
                              navigator.pop();
                              await Printing.layoutPdf(
                                onLayout: (PdfPageFormat format) async => bytes,
                                name: filename,
                              );
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء طباعة ملف الـ PDF: $e'),
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                          },
                        ),

                        const Divider(height: 12),

                        // 3. Share PDF
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.share_rounded, color: Colors.deepPurple),
                          ),
                          title: const Text('مشاركة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('إرسال التقرير عبر واتساب، تيليجرام، أو التطبيقات الأخرى', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating PDF for share: $filename');
                              final bytes = await generateBytes();
                              debugPrint('PDF generated successfully for share, size: ${bytes.length} bytes');
                              navigator.pop();
                              await Printing.sharePdf(
                                bytes: bytes,
                                filename: filename,
                              );
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء مشاركة ملف الـ PDF: $e'),
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
              ),
            ),
          );
          },
        );
      },
    );
  }

  /// Helper to trigger debt statement with options
  static Future<void> exportDebtStatement(BuildContext context, DebtModel debt) async {
    final filename = 'كشف_دين_${debt.personName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await showPdfOptionsBottomSheet(
      context: context,
      title: 'خيارات تصدير كشف الدين: ${debt.personName}',
      generateBytes: () => generateDebtStatementBytes(debt),
      filename: filename,
    );
  }

  /// Helper to trigger person ledger statement with options
  static Future<void> exportPersonStatement(
    BuildContext context,
    PersonModel person,
    List<DebtModel> debts,
    DebtProvider provider, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filename = 'كشف_حساب_${person.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await showPdfOptionsBottomSheet(
      context: context,
      title: 'خيارات تصدير كشف الحساب: ${person.name}',
      generateBytes: () => generatePersonStatementBytes(
        person, 
        debts, 
        provider,
        startDate: startDate,
        endDate: endDate,
      ),
      filename: filename,
    );
  }

  // ================= 3. Transactions Statement =================

  static Future<Uint8List> generateTransactionStatementBytes({
    required List<TransactionModel> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    final primaryColor = PdfColor.fromHex('#0D9488');
    final textColor = PdfColor.fromHex('#0F172A');
    final borderColor = PdfColor.fromHex('#CBD5E1');
    final headerBgColor = PdfColor.fromHex('#F1F5F9');

    // Group transactions by currency
    final Map<AppCurrency, List<TransactionModel>> byCurrency = {};
    for (final t in transactions) {
      if (!byCurrency.containsKey(t.currency)) {
        byCurrency[t.currency] = [];
      }
      byCurrency[t.currency]!.add(t);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'سجل العمليات المالية',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    if (startDate != null && endDate != null)
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('من: ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
                          pw.Text(
                            DateFormatter.formatDate(startDate),
                            textDirection: pw.TextDirection.ltr,
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text('إلى: ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
                          pw.Text(
                            DateFormatter.formatDate(endDate),
                            textDirection: pw.TextDirection.ltr,
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                          ),
                        ],
                      )
                    else
                      pw.Text(
                        'لجميع الفترات والتواريخ',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildLabeledTextRow(
                      label: 'تاريخ التقرير:',
                      value: DateFormatter.formatDate(DateTime.now()),
                      labelStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                      valueIsLtr: true,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'تطبيق ميزانيتي',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'تطبيق ميزانيتي - إدارة المصاريف والديون',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];

          if (byCurrency.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 40),
                  child: pw.Text(
                    'لا توجد عمليات في هذا النطاق الزمني',
                    style: pw.TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
              ),
            );
            return widgets;
          }

          for (final entry in byCurrency.entries) {
            final cur = entry.key;
            final list = entry.value;

            list.sort((a, b) => a.date.compareTo(b.date));

            double totalIncome = 0;
            double totalExpense = 0;
            for (final t in list) {
              if (t.isWalletTransfer) continue;
              if (t.type == TransactionType.expense) {
                totalExpense += t.amount;
              } else {
                totalIncome += t.amount;
              }
            }
            final net = totalIncome - totalExpense;

            // عنوان قسم العملة مباشرة في القائمة
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 3.5,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          'عمليات بـ ${cur.nameAr} (${cur.symbol})',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'العدد: ${list.length}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            widgets.add(pw.SizedBox(height: 4));

            // تجهيز بيانات الجدول
            final List<List<String>> tableData = [];
            for (int i = 0; i < list.length; i++) {
              final t = list[i];
              final isExpense = t.type == TransactionType.expense;
              String displayDesc = (t.notes != null && t.notes!.trim().isNotEmpty)
                  ? '${t.title} (${t.notes})'
                  : t.title;
              if (displayDesc.length > 70) {
                displayDesc = '${displayDesc.substring(0, 67)}...';
              }

              tableData.add([
                '${i + 1}',
                DateFormatter.formatDate(t.date),
                t.categoryName,
                displayDesc,
                isExpense ? '-' : CurrencyFormatter.formatAmount(t.amount),
                isExpense ? CurrencyFormatter.formatAmount(t.amount) : '-',
              ]);
            }

            // صف الإجمالي
            tableData.add([
              '',
              '',
              '',
              'الإجمالي',
              CurrencyFormatter.formatAmount(totalIncome),
              CurrencyFormatter.formatAmount(totalExpense),
            ]);

            // صف الصافي
            tableData.add([
              '',
              '',
              '',
              'الصافي (${net >= 0 ? "فائض" : "عجز"})',
              '',
              '${CurrencyFormatter.formatAmount(net.abs())} ${cur.symbol}',
            ]);

            // إضافة الجدول مباشرة كعنصر في القائمة دون أي Container أو Column مقيد
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderColor, width: 0.6),
                headerDecoration: pw.BoxDecoration(color: headerBgColor),
                headerHeight: 22,
                cellHeight: 18,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: textColor),
                cellStyle: pw.TextStyle(fontSize: 8, color: textColor),
                columnWidths: const {
                  0: pw.FixedColumnWidth(22),
                  1: pw.FixedColumnWidth(64),
                  2: pw.FlexColumnWidth(2.2),
                  3: pw.FlexColumnWidth(3.0),
                  4: pw.FlexColumnWidth(1.8),
                  5: pw.FlexColumnWidth(1.8),
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerLeft,
                },
                headers: ['#', 'التاريخ', 'التصنيف', 'البيان', 'مداخيل', 'مصاريف'],
                data: tableData,
              ),
            );

            widgets.add(pw.SizedBox(height: 14));
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> showTransactionExportBottomSheet({
    required BuildContext context,
    required List<TransactionModel> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filename = 'كشف_عمليات_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await showPdfOptionsBottomSheet(
      context: context,
      title: 'خيارات تصدير سجل العمليات',
      generateBytes: () => generateTransactionStatementBytes(
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
      ),
      filename: filename,
    );
  }

  // ================= 4. Comprehensive Debts Statement =================

  /// Builds PDF document bytes for all debts (comprehensive report)
  static Future<Uint8List> generateComprehensiveDebtsStatementBytes({
    required List<DebtModel> debts,
    DebtType? filterType, // null = all, DebtType.forMe = debts for me, DebtType.onMe = debts on me
  }) async {
    final pdf = pw.Document();
    final theme = await _loadArabicTheme();

    final primaryTeal = PdfColor.fromHex('#0D9488');
    final expenseRed = PdfColor.fromHex('#E11D48');
    final textColor = PdfColor.fromHex('#0F172A');
    final subtextColor = PdfColor.fromHex('#64748B');

    // Filter debts based on selected type
    final filteredDebts = filterType == null
        ? debts
        : debts.where((d) => d.type == filterType).toList();

    final debtsForMe = filteredDebts.where((d) => d.type == DebtType.forMe).toList();
    final debtsOnMe = filteredDebts.where((d) => d.type == DebtType.onMe).toList();

    // Group remaining totals by currency
    final Map<AppCurrency, double> totalForMeByCurrency = {};
    for (final d in debtsForMe) {
      totalForMeByCurrency[d.currency] = (totalForMeByCurrency[d.currency] ?? 0.0) + d.remainingAmount;
    }

    final Map<AppCurrency, double> totalOnMeByCurrency = {};
    for (final d in debtsOnMe) {
      totalOnMeByCurrency[d.currency] = (totalOnMeByCurrency[d.currency] ?? 0.0) + d.remainingAmount;
    }

    final allCurrencies = AppCurrency.values.where((c) {
      return (totalForMeByCurrency[c] ?? 0.0) > 0 || (totalOnMeByCurrency[c] ?? 0.0) > 0;
    }).toList();

    String reportTitle = 'كشف الديون الشامل (سجل الذمم المالية)';
    if (filterType == DebtType.forMe) {
      reportTitle = 'كشف المستحقات المالية (ديون لي على الآخرين)';
    } else if (filterType == DebtType.onMe) {
      reportTitle = 'كشف الالتزامات المالية (ديون علي للآخرين)';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: filterType == DebtType.onMe ? expenseRed : primaryTeal,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              reportTitle,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text('إجمالي السجلات:', style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.white)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(filteredDebts.length.toString(), textDirection: pw.TextDirection.ltr, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                  pw.SizedBox(width: 4),
                                  pw.Text('سند دين', style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _buildLabeledTextRow(
                              label: 'تاريخ التقرير:',
                              value: DateFormatter.formatDate(DateTime.now()),
                              labelStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                              valueStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                              valueIsLtr: true,
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'تطبيق ميزانيتي',
                              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  if (filteredDebts.isEmpty)
                    pw.Center(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Text('لا توجد ديون مسجلة في هذا التقرير', style: const pw.TextStyle(fontSize: 13)),
                      ),
                    )
                  else ...[
                    // Section 1: Debts For Me (ديون لي)
                    if (filterType == null || filterType == DebtType.forMe) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F0FDFA'),
                          border: pw.Border.all(color: primaryTeal, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'أولاً: مستحقات لي على الآخرين (ديون لي)',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryTeal),
                            ),
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text('عدد السجلات:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryTeal)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(debtsForMe.length.toString(), textDirection: pw.TextDirection.ltr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryTeal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),

                      if (debtsForMe.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8),
                          child: pw.Text('لا توجد مستحقات (ديون لي)', style: pw.TextStyle(fontSize: 10, color: subtextColor)),
                        )
                      else ...[
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#CCFBF1')),
                          headerHeight: 24,
                          cellHeight: 22,
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textColor),
                          cellStyle: pw.TextStyle(fontSize: 8.5, color: textColor),
                          cellAlignments: {
                            0: pw.Alignment.center,
                            1: pw.Alignment.centerRight,
                            2: pw.Alignment.centerRight,
                            3: pw.Alignment.center,
                            4: pw.Alignment.centerLeft,
                            5: pw.Alignment.centerLeft,
                            6: pw.Alignment.center,
                          },
                          headers: ['#', 'الشخص / الجهة', 'التاريخ', 'العملة', 'المبلغ الأصلي', 'المتبقي', 'الحالة'],
                          data: List.generate(debtsForMe.length, (i) {
                            final d = debtsForMe[i];
                            return [
                              '${i + 1}',
                              d.personName,
                              DateFormatter.formatDate(d.createdAt),
                              d.currency.code,
                              CurrencyFormatter.formatAmount(d.totalAmount),
                              CurrencyFormatter.formatAmount(d.remainingAmount),
                              d.isSettled ? 'مسدد' : (d.paidAmount > 0 ? 'مسدد جزئياً' : 'غير مسدد'),
                            ];
                          }),
                        ),
                        pw.SizedBox(height: 6),
                        // Totals by currency for debtsForMe
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: totalForMeByCurrency.entries.map((e) {
                              return pw.Container(
                                margin: const pw.EdgeInsets.only(left: 6),
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#E6FFFA'),
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(color: primaryTeal, width: 0.5),
                                ),
                                child: _buildAmountRow(
                                  label: 'إجمالي متبقي:',
                                  amount: e.value,
                                  currency: e.key,
                                  labelStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryTeal),
                                  amountStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryTeal),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 16),
                    ],

                    // Section 2: Debts On Me (ديون علي)
                    if (filterType == null || filterType == DebtType.onMe) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#FFF1F2'),
                          border: pw.Border.all(color: expenseRed, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'ثانياً: التزامات مالية للآخرين (ديون علي)',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: expenseRed),
                            ),
                            pw.Directionality(
                              textDirection: pw.TextDirection.rtl,
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text('عدد السجلات:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: expenseRed)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(debtsOnMe.length.toString(), textDirection: pw.TextDirection.ltr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: expenseRed)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),

                      if (debtsOnMe.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8),
                          child: pw.Text('لا توجد التزامات (ديون علي)', style: pw.TextStyle(fontSize: 10, color: subtextColor)),
                        )
                      else ...[
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFE4E6')),
                          headerHeight: 24,
                          cellHeight: 22,
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textColor),
                          cellStyle: pw.TextStyle(fontSize: 8.5, color: textColor),
                          cellAlignments: {
                            0: pw.Alignment.center,
                            1: pw.Alignment.centerRight,
                            2: pw.Alignment.centerRight,
                            3: pw.Alignment.center,
                            4: pw.Alignment.centerLeft,
                            5: pw.Alignment.centerLeft,
                            6: pw.Alignment.center,
                          },
                          headers: ['#', 'الشخص / الدائن', 'التاريخ', 'العملة', 'المبلغ الأصلي', 'المتبقي', 'الحالة'],
                          data: List.generate(debtsOnMe.length, (i) {
                            final d = debtsOnMe[i];
                            return [
                              '${i + 1}',
                              d.personName,
                              DateFormatter.formatDate(d.createdAt),
                              d.currency.code,
                              CurrencyFormatter.formatAmount(d.totalAmount),
                              CurrencyFormatter.formatAmount(d.remainingAmount),
                              d.isSettled ? 'مسدد' : (d.paidAmount > 0 ? 'مسدد جزئياً' : 'غير مسدد'),
                            ];
                          }),
                        ),
                        pw.SizedBox(height: 6),
                        // Totals by currency for debtsOnMe
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: totalOnMeByCurrency.entries.map((e) {
                              return pw.Container(
                                margin: const pw.EdgeInsets.only(left: 6),
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#FFEBEF'),
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(color: expenseRed, width: 0.5),
                                ),
                                child: _buildAmountRow(
                                  label: 'إجمالي متبقي:',
                                  amount: e.value,
                                  currency: e.key,
                                  labelStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: expenseRed),
                                  amountStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: expenseRed),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 16),
                    ],

                    // Section 3: Net Debts Summary (صافي الديون)
                    if (filterType == null && allCurrencies.isNotEmpty) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F8FAFC'),
                          border: pw.Border.all(color: PdfColor.fromHex('#94A3B8'), width: 1),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ثالثاً: ملخص صافي المركز المالي للديون (الفرق بين ما لك وما عليك)',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textColor),
                            ),
                            pw.SizedBox(height: 8),
                            pw.TableHelper.fromTextArray(
                              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
                              headerHeight: 24,
                              cellHeight: 22,
                              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textColor),
                              cellStyle: pw.TextStyle(fontSize: 9, color: textColor),
                              cellAlignments: {
                                0: pw.Alignment.center,
                                1: pw.Alignment.centerLeft,
                                2: pw.Alignment.centerLeft,
                                3: pw.Alignment.centerLeft,
                                4: pw.Alignment.center,
                              },
                              headers: ['العملة', 'إجمالي ما لي (مستحقات)', 'إجمالي ما علي (التزامات)', 'صافي الموقف المالي', 'الوضع المالي'],
                              data: allCurrencies.map((cur) {
                                final forMe = totalForMeByCurrency[cur] ?? 0.0;
                                final onMe = totalOnMeByCurrency[cur] ?? 0.0;
                                final net = forMe - onMe;
                                return [
                                  cur.nameAr,
                                  '${CurrencyFormatter.formatAmount(forMe)} ${cur.symbol}',
                                  '${CurrencyFormatter.formatAmount(onMe)} ${cur.symbol}',
                                  '${CurrencyFormatter.formatAmount(net.abs())} ${cur.symbol}',
                                  net >= 0 ? 'فائض لصالحك (+)' : 'عجز والتزام عليك (-)',
                                ];
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 16),
                    ],
                  ],

                  pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'كشف حساب صادر تلقائياً من تطبيق ميزانيتي • مطور بواسطة م/ نسيم مزاحم',
                    style: pw.TextStyle(fontSize: 8.5, color: subtextColor),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Interactive BottomSheet for Comprehensive Debts Report Export
  static Future<void> showComprehensiveDebtsExportBottomSheet({
    required BuildContext context,
    required List<DebtModel> debts,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DebtType? selectedFilter; // null = comprehensive (شامل), DebtType.forMe = مستحقات لي, DebtType.onMe = التزامات علي
    bool isGenerating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String reportTitle = 'كشف الديون الشامل';
            String filePrefix = 'كشف_الديون_الشامل';
            if (selectedFilter == DebtType.forMe) {
              reportTitle = 'كشف المستحقات (ديون لي)';
              filePrefix = 'كشف_المستحقات_ديون_لي';
            } else if (selectedFilter == DebtType.onMe) {
              reportTitle = 'كشف الالتزامات (ديون علي)';
              filePrefix = 'كشف_الالتزامات_ديون_علي';
            }

            final filename = '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';

            return SafeArea(
              child: Material(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تصدير $reportTitle (PDF)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),

                      // Filter selector: All / ForMe / OnMe
                      Text(
                        'اختر نوع التقرير المطلوب:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('شامل (الكل)', style: TextStyle(fontSize: 11))),
                              selected: selectedFilter == null,
                              selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                              onSelected: (_) => setSheetState(() => selectedFilter = null),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('مستحقات لي', style: TextStyle(fontSize: 11))),
                              selected: selectedFilter == DebtType.forMe,
                              selectedColor: AppColors.income.withValues(alpha: 0.2),
                              onSelected: (_) => setSheetState(() => selectedFilter = DebtType.forMe),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('التزامات علي', style: TextStyle(fontSize: 11))),
                              selected: selectedFilter == DebtType.onMe,
                              selectedColor: AppColors.expense.withValues(alpha: 0.2),
                              onSelected: (_) => setSheetState(() => selectedFilter = DebtType.onMe),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      if (isGenerating) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryTeal),
                              SizedBox(height: 12),
                              Text('جاري إنشاء وتجهيز كشف الديون...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ] else ...[
                        // 1. Save as PDF via FilePicker
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.download_rounded, color: AppColors.income),
                          ),
                          title: const Text('حفظ كملف PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('تحديد مجلد على الهاتف وحفظ الملف مباشرة', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating comprehensive debts PDF for save: $filename');
                              final bytes = await generateComprehensiveDebtsStatementBytes(
                                debts: debts,
                                filterType: selectedFilter,
                              );
                              debugPrint('PDF generated successfully, size: ${bytes.length} bytes');

                              String? selectedPath;
                              try {
                                selectedPath = await FilePicker.platform.saveFile(
                                  dialogTitle: 'حفظ كشف الديون',
                                  fileName: filename,
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  bytes: bytes,
                                );
                              } catch (e) {
                                debugPrint('[PdfStatementService] FilePicker error: $e');
                              }

                              if (selectedPath != null) {
                                final file = File(selectedPath);
                                if (!await file.exists() || await file.length() == 0) {
                                  await file.writeAsBytes(bytes);
                                }
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('تم حفظ ملف الـ PDF بنجاح في:\n$selectedPath'),
                                    backgroundColor: AppColors.income,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                if (ctx.mounted) {
                                  setSheetState(() => isGenerating = false);
                                }
                              }
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء حفظ كشف الديون: $e'),
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                          },
                        ),

                        const Divider(height: 12),

                        // 2. Print via System Print Framework
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded, color: AppColors.primaryTeal),
                          ),
                          title: const Text('طباعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('فتح نافذة الطباعة الرسمية للنظام ومعاينة التقرير', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating comprehensive debts PDF for print: $filename');
                              final bytes = await generateComprehensiveDebtsStatementBytes(
                                debts: debts,
                                filterType: selectedFilter,
                              );
                              debugPrint('PDF generated successfully, size: ${bytes.length} bytes');
                              navigator.pop();
                              await Printing.layoutPdf(
                                onLayout: (PdfPageFormat format) async => bytes,
                                name: filename,
                              );
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء طباعة كشف الديون: $e'),
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                          },
                        ),

                        const Divider(height: 12),

                        // 3. Share PDF
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.share_rounded, color: Colors.deepPurple),
                          ),
                          title: const Text('مشاركة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: const Text('إرسال تقرير الديون عبر واتساب، تيليجرام، أو التطبيقات الأخرى', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              setSheetState(() => isGenerating = true);
                              debugPrint('Started generating comprehensive debts PDF for share: $filename');
                              final bytes = await generateComprehensiveDebtsStatementBytes(
                                debts: debts,
                                filterType: selectedFilter,
                              );
                              debugPrint('PDF generated successfully, size: ${bytes.length} bytes');
                              navigator.pop();
                              await Printing.sharePdf(
                                bytes: bytes,
                                filename: filename,
                              );
                            } catch (e, stack) {
                              debugPrint('PDF ERROR: $e');
                              debugPrint('PDF STACK: $stack');
                              if (ctx.mounted) {
                                setSheetState(() => isGenerating = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء مشاركة كشف الديون: $e'),
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
              ),
            ),
          );
          },
        );
      },
    );
  }
}
