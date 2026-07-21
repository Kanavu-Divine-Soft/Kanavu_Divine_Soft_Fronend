import json
from deep_translator import GoogleTranslator

file_path = r'c:\Users\kalai\AppData\Local\Pub\Cache\hosted\pub.dev\csc_picker-0.2.7\lib\assets\country.json'

with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

tn_cities = []
for country in data:
    if country['name'] == 'India':
        for state in country['state']:
            if state['name'] == 'Tamil Nadu':
                for city in state['city']:
                    tn_cities.append(city['name'])
                break
        break

print(f"Found {len(tn_cities)} cities in Tamil Nadu")

translator = GoogleTranslator(source='en', target='ta')
translations = {}
# Process in chunks to avoid overwhelming the API
chunk_size = 50
for i in range(0, len(tn_cities), chunk_size):
    chunk = tn_cities[i:i+chunk_size]
    print(f"Translating chunk {i} to {i+len(chunk)}...")
    translated_chunk = translator.translate_batch(chunk)
    for en, ta in zip(chunk, translated_chunk):
        translations[en] = ta

dart_code = "const Map<String, String> cityTranslations = {\n"
for en, ta in translations.items():
    dart_code += f"  '{en}': '{ta}',\n"
dart_code += "};\n"

out_path = r'c:\Users\kalai\StudioProjects\temple_onboarding\temple_onboarding Frontend\lib\presentation\utils\city_translations.dart'
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(dart_code)

print("Done writing dart file!")
