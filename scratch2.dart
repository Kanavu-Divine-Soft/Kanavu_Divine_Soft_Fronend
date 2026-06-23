import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl_phone_field/countries.dart';

void main() {}

class CustomPhonePicker extends StatefulWidget {
  const CustomPhonePicker({super.key});

  @override
  _CustomPhonePickerState createState() => _CustomPhonePickerState();
}

class _CustomPhonePickerState extends State<CustomPhonePicker> {
  late final ValueNotifier<Country?> selectedCountry;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedCountry = ValueNotifier<Country?>(countries.firstWhere((c) => c.code == 'IN'));
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<Country>(
        isExpanded: true,
        hint: const Text('Select Country'),
        items: countries
            .map((item) => DropdownItem<Country>(
                  value: item,
                  child: Text('${item.flag} ${item.name} (+${item.dialCode})', overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        valueListenable: selectedCountry,
        onChanged: (value) {
          selectedCountry.value = value;
        },
        buttonStyleData: const ButtonStyleData(
          height: 50,
          width: 250,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          width: 300,
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
        ),
        dropdownSearchData: DropdownSearchData(
          searchController: searchController,
          searchBarWidgetHeight: 50,
          searchBarWidget: Padding(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 4,
              right: 8,
              left: 8,
            ),
            child: TextFormField(
              controller: searchController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                hintText: 'Search for an item...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          searchMatchFn: (item, searchValue) {
            final country = item.value!;
            return country.name.toLowerCase().contains(searchValue.toLowerCase()) || 
                   country.dialCode.contains(searchValue);
          },
        ),
        onMenuStateChange: (isOpen) {
          if (!isOpen) {
            searchController.clear();
          }
        },
      ),
    );
  }
}
