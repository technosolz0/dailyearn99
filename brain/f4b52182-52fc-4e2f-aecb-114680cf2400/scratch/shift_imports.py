import re

with open('/Volumes/Untitled/aitest/target99/backend/app/services.py', 'r') as f:
    content = f.read()

lines = content.split('\n')

import_lines = []
new_lines = []

# Regex to match single-line imports
import_regex = re.compile(r'^\s*(import\s+|from\s+\S+\s+import\s+)')

for line in lines:
    if import_regex.match(line):
        import_lines.append(line.strip())
    else:
        new_lines.append(line)

# De-duplicate import lines
unique_imports = sorted(list(set(import_lines)))

# Group imports
std_libs = []
third_party = []
local_imports = []

for imp in unique_imports:
    if imp.startswith('import '):
        parts = imp.split()
        pkg = parts[1].split('.')[0]
        if pkg in ['threading', 'random', 'hmac', 'hashlib', 'json', 'uuid', 'asyncio', 'time', 'secrets', 're', 'os']:
            std_libs.append(imp)
        else:
            third_party.append(imp)
    elif imp.startswith('from '):
        parts = imp.split()
        pkg = parts[1].split('.')[0]
        if pkg in ['datetime', 'typing']:
            std_libs.append(imp)
        elif pkg in ['sqlalchemy', 'fastapi', 'starlette', 'anyio']:
            third_party.append(imp)
        elif pkg == 'app':
            local_imports.append(imp)
        else:
            third_party.append(imp)

# Remove any redundant self-imports
local_imports = [imp for imp in local_imports if 'from app.services import' not in imp]

# Sort each group
std_libs = sorted(std_libs)
third_party = sorted(third_party)
local_imports = sorted(local_imports)

# Construct final imports header
top_imports = []
if std_libs:
    top_imports.extend(std_libs)
if third_party:
    if top_imports:
        top_imports.append('')
    top_imports.extend(third_party)
if local_imports:
    if top_imports:
        top_imports.append('')
    top_imports.extend(local_imports)

# Remove leading empty lines from new_lines if they exist
while new_lines and new_lines[0].strip() == '':
    new_lines.pop(0)

# Combine everything
final_content = '\n'.join(top_imports) + '\n\n' + '\n'.join(new_lines)

with open('/Volumes/Untitled/aitest/target99/backend/app/services.py', 'w') as f:
    f.write(final_content)

print("Successfully shifted all imports to the top!")
