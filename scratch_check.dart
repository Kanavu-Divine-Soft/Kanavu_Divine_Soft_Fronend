import 'package:intl_phone_field/countries.dart';
import 'package:temple_onboarding/presentation/utils/country_translations.dart';

void main() {
  for (var country in countries) {
    if (!countryTranslations.containsKey(country.name)) {
      print(country.name);
    }
  }
}
