import re

with open('lib/presentation/screens/add_admin_screen.dart', 'r', encoding='utf-8') as f:
    add_content = f.read()

with open('lib/presentation/screens/edit_admin_screen.dart', 'r', encoding='utf-8') as f:
    edit_content = f.read()

state_vars = """
  final GlobalKey _mobileFieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  bool _isCountryDropdownOpen = false;
  OverlayEntry? _countryOverlayEntry;
  late Country _selectedCountry;
"""
edit_content = re.sub(r'(bool _obscurePassword = true;\n)', r'\1' + state_vars, edit_content, count=1)

if 'package:intl_phone_field/countries.dart' not in edit_content:
    edit_content = edit_content.replace("import 'package:intl_phone_field/intl_phone_field.dart';", "import 'package:intl_phone_field/intl_phone_field.dart';\nimport 'package:intl_phone_field/countries.dart';")

init_state_addition = "\n    _selectedCountry = countries.firstWhere((c) => c.code == 'IN');\n"
edit_content = re.sub(r'(_selectedTable = widget\.adminData\[\'assigned_table\'\];\n)', r'\1' + init_state_addition, edit_content, count=1)

dropdown_methods_match = re.search(r'(  void _toggleCountryDropdown\(\).*?  void dispose\(\) \{)', add_content, re.DOTALL)
if dropdown_methods_match:
    dropdown_methods = dropdown_methods_match.group(1)
    dropdown_methods = re.sub(r'  void dispose\(\) \{.*', '', dropdown_methods, flags=re.DOTALL)
    edit_content = edit_content.replace('  Widget _buildTextField({', dropdown_methods + '\n  Widget _buildTextField({')

dispose_logic = """
  @override
  void dispose() {
    _removeCountryOverlay();
    _mobileNumberController.dispose();
    super.dispose();
  }
"""
if 'void dispose()' not in edit_content:
    edit_content = edit_content.replace('  Widget _buildTextField({', dispose_logic + '\n  Widget _buildTextField({')
else:
    edit_content = edit_content.replace('  void dispose() {', '  void dispose() {\n    _removeCountryOverlay();')

field_match = re.search(r'(CompositedTransformTarget\(\s*link: _layerLink.*?counterText: \'\',\s*\),\s*\),\s*\),)', add_content, re.DOTALL)
if field_match:
    field_code = field_match.group(1)
    intl_match = re.search(r'IntlPhoneField\(.*?\),', edit_content, re.DOTALL)
    if intl_match:
        edit_content = edit_content.replace(intl_match.group(0), field_code)
        
panel_match = re.search(r'(class _CountryDropdownPanel extends StatefulWidget \{.*)', add_content, re.DOTALL)
if panel_match:
    panel_code = panel_match.group(1)
    edit_content += '\n' + panel_code

with open('lib/presentation/screens/edit_admin_screen.dart', 'w', encoding='utf-8') as f:
    f.write(edit_content)

print("Done")
