import os
import glob

lib_dir = r"c:\Users\kalai\StudioProjects\temple_onboarding\lib"

dart_files = glob.glob(os.path.join(lib_dir, "**", "*.dart"), recursive=True)

import_statement = "import 'package:temple_onboarding/core/api_constants.dart';\n"

for file_path in dart_files:
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        if "http://localhost:8005" in content:
            new_content = content.replace("http://localhost:8005", "${ApiConstants.baseUrl}")
            
            # Add import if not present
            if "api_constants.dart" not in new_content:
                # Find the last import
                lines = new_content.split('\n')
                last_import_idx = -1
                for i, line in enumerate(lines):
                    if line.startswith("import "):
                        last_import_idx = i
                
                if last_import_idx != -1:
                    lines.insert(last_import_idx + 1, import_statement.strip())
                else:
                    lines.insert(0, import_statement.strip())
                    
                new_content = '\n'.join(lines)
                
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"Updated {file_path}")
    except Exception as e:
        print(f"Failed to process {file_path}: {e}")
