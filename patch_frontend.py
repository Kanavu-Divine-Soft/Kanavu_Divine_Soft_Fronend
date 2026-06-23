import re

file_path = r"c:\Users\kalai\StudioProjects\temple_onboarding\lib\presentation\screens\ponsoft_member_details_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Signature of _buildResponsiveFieldsGrid
content = re.sub(
    r"int visiblePayments = 1,\s*VoidCallback\? onAddPayment,\s*VoidCallback\? onRemovePayment,",
    "List<TextEditingController> paymentControllers = const [],\n    VoidCallback? onAddPayment,\n    Function(int)? onRemovePayment,",
    content
)

# 2. Payments UI in _buildResponsiveFieldsGrid
old_payments_ui = r"_buildSectionHeader\('Payments', Icons.payments_outlined\),.*?_buildResponsiveRow\(context, \[\s*_buildDialogTextField\(\s*controller: controllers\['pay1'\].*?\]\),"
new_payments_ui = """_buildSectionHeader('Payments', Icons.payments_outlined),
        for (int i = 0; i <= paymentControllers.length; i += 3)
          if (i <= paymentControllers.length)
            _buildResponsiveRow(context, [
              for (int j = i; j < i + 3; j++)
                if (j < paymentControllers.length)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDialogTextField(
                          controller: paymentControllers[j],
                          label: 'Payment ${j + 1} *',
                          icon: Icons.payments,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          enabled: isEditable,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\\d*\\.?\\d*$'))],
                          onTap: () {
                            if (paymentControllers[j].text == '0.00' || paymentControllers[j].text == '0') {
                              paymentControllers[j].clear();
                            }
                          },
                          onChanged: (v) => setDialogState(() {}),
                        ),
                      ),
                      if (onRemovePayment != null && paymentControllers.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: IconButton(
                            icon: Icon(Icons.remove_circle, color: isEditable ? Colors.grey.shade600 : Colors.grey.shade400, size: 28),
                            onPressed: isEditable ? () => onRemovePayment(j) : null,
                            tooltip: 'Remove payment',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                    ],
                  )
                else if (j == paymentControllers.length && onAddPayment != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: IconButton(
                        icon: Icon(Icons.add_circle, color: isEditable ? const Color(0xFFE40000) : Colors.grey.shade400, size: 36),
                        onPressed: isEditable ? onAddPayment : null,
                        tooltip: 'Add payment',
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
            ]),"""

content = re.sub(old_payments_ui, lambda m: new_payments_ui, content, flags=re.DOTALL)

# 3. Add Member Dialog
content = re.sub(
    r"final _addPayment1Controller = TextEditingController\(text: '0\.00'\);\s*final _addPayment2Controller = TextEditingController\(text: '0\.00'\);\s*final _addPayment3Controller = TextEditingController\(text: '0\.00'\);",
    "final List<TextEditingController> _paymentControllers = [TextEditingController(text: '0.00')];",
    content
)

content = re.sub(
    r"int _visiblePayments = 1;",
    "",
    content, count=1 # Add dialog
)

add_grid_old = r"visiblePayments: _visiblePayments,\s*onAddPayment: \(\) \{.*?\},\s*onRemovePayment: \(\) \{.*?\},"
add_grid_new = """paymentControllers: _paymentControllers,
                                    onAddPayment: () {
                                      setDialogState(() {
                                        _paymentControllers.add(TextEditingController(text: '0.00'));
                                      });
                                    },
                                    onRemovePayment: (index) {
                                      setDialogState(() {
                                        _paymentControllers[index].dispose();
                                        _paymentControllers.removeAt(index);
                                      });
                                    },"""
content = re.sub(add_grid_old, add_grid_new, content, flags=re.DOTALL, count=1)

# Remove 'pay1', 'pay2', 'pay3' from controllers map
content = re.sub(r"'pay1': _addPayment1Controller,\s*'pay2': _addPayment2Controller,\s*'pay3': _addPayment3Controller,", "", content)

# 4. Edit Member Dialog
edit_init_old = r"final _addPayment1Controller = TextEditingController\(text: member\['Payment_1'\].*?final _addPayment3Controller = TextEditingController\(text: member\['Payment_3'\].*?'0\.00'\);"
edit_init_new = """List<dynamic> existingPayments = [];
    if (member['Payments'] != null) {
      if (member['Payments'] is String) {
        try {
          existingPayments = jsonDecode(member['Payments']);
        } catch (e) {}
      } else if (member['Payments'] is List) {
        existingPayments = member['Payments'];
      }
    }
    final List<TextEditingController> _paymentControllers = existingPayments.isNotEmpty
        ? existingPayments.map((p) => TextEditingController(text: p['amount']?.toString() ?? '0.00')).toList()
        : [TextEditingController(text: '0.00')];"""
content = re.sub(edit_init_old, edit_init_new, content, flags=re.DOTALL)

# edit _visiblePayments
content = re.sub(r"int _visiblePayments = 1;\s*if \(_addPayment2Controller.*?\s*if \(_addPayment3Controller.*?", "", content, flags=re.DOTALL)

content = re.sub(add_grid_old, add_grid_new, content, flags=re.DOTALL) # Replaces the second occurrence

# 5. Payloads in _submitAddMember and _submitEditMember
payload_old = r"'payment_1': double\.tryParse\(_addPayment1Controller\.text\.trim\(\)\) \?\? 0\.0,\s*'payment_2': double\.tryParse\(_addPayment2Controller\.text\.trim\(\)\) \?\? 0\.0,\s*'payment_3': double\.tryParse\(_addPayment3Controller\.text\.trim\(\)\) \?\? 0\.0,"
payload_new = "'payments': _paymentControllers.map((c) => {'amount': double.tryParse(c.text.trim()) ?? 0.0}).toList(),"
content = re.sub(payload_old, payload_new, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Patch successful!")
