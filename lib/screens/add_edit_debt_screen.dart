import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/app_currency.dart';
import '../providers/debt_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/currency_selector_widget.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';

class AddEditDebtScreen extends StatefulWidget {
  final DebtModel? debtToEdit;
  final AppCurrency? initialCurrency;
  final DebtType? initialDebtType;
  final String? initialPersonId;
  final String? initialPersonName;
  final String? initialPhone;

  const AddEditDebtScreen({
    super.key,
    this.debtToEdit,
    this.initialCurrency,
    this.initialDebtType,
    this.initialPersonId,
    this.initialPersonName,
    this.initialPhone,
  });

  @override
  State<AddEditDebtScreen> createState() => _AddEditDebtScreenState();
}

class _AddEditDebtScreenState extends State<AddEditDebtScreen> {
  final _formKey = GlobalKey<FormState>();

  late DebtType _debtType;
  late AppCurrency _currency;
  String? _selectedPersonId;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  DateTime? _dueDate;

  bool get _isEditing => widget.debtToEdit != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debtToEdit;

    _debtType = d?.type ?? widget.initialDebtType ?? DebtType.forMe;
    _currency = d?.currency ?? widget.initialCurrency ?? AppCurrency.yer;
    _selectedPersonId = d?.personId ?? widget.initialPersonId;
    _nameController = TextEditingController(text: d?.personName ?? widget.initialPersonName ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? widget.initialPhone ?? '');
    _amountController = TextEditingController(
      text: d != null ? (d.totalAmount % 1 == 0 ? d.totalAmount.toInt().toString() : d.totalAmount.toString()) : '',
    );
    _notesController = TextEditingController(text: d?.notes ?? '');
    _dueDate = d?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _showSelectPersonSheet() {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = debtProvider.filterPersons(search);

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Text(
                    'اختر جهة الاتصال / الشخص',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setSheetState(() => search = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text('لا توجد جهات اتصال مطابقة'),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('كتابة اسم جديد يدوياً'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final p = filtered[idx];
                              final isSelected = p.id == _selectedPersonId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? AppColors.primaryTeal : Colors.grey.shade300,
                                  child: Text(
                                    p.name.isNotEmpty ? p.name.substring(0, 1) : '?',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: p.phone != null ? Text(p.phone!) : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppColors.primaryTeal)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedPersonId = p.id;
                                    _nameController.text = p.name;
                                    if (p.phone != null) {
                                      _phoneController.text = p.phone!;
                                    }
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ دين صالح أكبر من الصفر')),
      );
      return;
    }

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final id = _isEditing ? widget.debtToEdit!.id : const Uuid().v4();

    final newDebt = DebtModel(
      id: id,
      personId: _selectedPersonId,
      personName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      totalAmount: amount,
      currency: _currency,
      type: _debtType,
      dueDate: _dueDate,
      createdAt: _isEditing ? widget.debtToEdit!.createdAt : DateTime.now(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      payments: _isEditing ? widget.debtToEdit!.payments : [],
    );

    if (_isEditing) {
      await debtProvider.updateDebt(newDebt);
    } else {
      await debtProvider.addDebt(newDebt);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtProvider = Provider.of<DebtProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل بيانات الدين' : 'تسجيل دين جديد'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // Debt Type Selector (دين لي / دين علي)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _debtType = DebtType.forMe),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _debtType == DebtType.forMe ? AppColors.debtForMe : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _debtType == DebtType.forMe
                                ? [
                                    BoxShadow(
                                      color: AppColors.debtForMe.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'دين لي (أطلبه)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _debtType == DebtType.forMe
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _debtType = DebtType.onMe),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _debtType == DebtType.onMe ? AppColors.debtOnMe : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _debtType == DebtType.onMe
                                ? [
                                    BoxShadow(
                                      color: AppColors.debtOnMe.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'دين علي (يطلب مني)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _debtType == DebtType.onMe
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Currency Selector
              const Text(
                'العملة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CurrencySelectorWidget(
                selectedCurrency: _currency,
                onCurrencyChanged: (c) => setState(() => _currency = c),
              ),

              const SizedBox(height: 20),

              // Person Picker Quick Action
              if (debtProvider.persons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _showSelectPersonSheet,
                    icon: const Icon(Icons.contacts_rounded, size: 18),
                    label: Text(
                      _selectedPersonId != null
                          ? 'تغيير جهة الاتصال المختارة (${_nameController.text})'
                          : 'اختيار من سجل الأشخاص الحاليين',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: AppColors.primaryTeal.withValues(alpha: 0.5)),
                    ),
                  ),
                ),

              // Person Name
              CustomTextField(
                controller: _nameController,
                label: 'اسم الشخص / الجهة المعنية',
                hint: 'مثال: محمد عبدالله أو شركة النور',
                prefixIcon: Icons.person_rounded,
                onChanged: (val) {
                  // If user manually types, check matching person
                  final match = debtProvider.findPersonByName(val);
                  _selectedPersonId = match?.id;
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الشخص';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Number
              CustomTextField(
                controller: _phoneController,
                label: 'رقم الهاتف (اختياري)',
                hint: '777000000',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_rounded,
              ),

              const SizedBox(height: 16),

              // Debt Amount
              CustomTextField(
                controller: _amountController,
                label: 'إجمالي مبلغ الدين',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.attach_money_rounded,
                suffix: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _currency.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currency.primaryColor,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  final n = double.tryParse(val.replaceAll(',', ''));
                  if (n == null || n <= 0) {
                    return 'الرجاء إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Due Date Picker
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 20, color: AppColors.primaryTeal),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تاريخ الاستحقاق المتوقع (اختياري):',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dueDate != null ? DateFormatter.formatDate(_dueDate!) : 'غير محدد',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dueDate = null),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notes
              CustomTextField(
                controller: _notesController,
                label: 'ملاحظات وتفاصيل إضافية (اختياري)',
                hint: 'تفاصيل السلفة، الغرض، شروط السداد...',
                maxLines: 3,
                prefixIcon: Icons.notes_rounded,
              ),

              const SizedBox(height: 28),

              // Save Button
              ElevatedButton(
                onPressed: _saveDebt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'حفظ التعديلات' : 'تسجيل الدين وحفظه',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
