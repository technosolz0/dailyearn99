import re

with open('/Volumes/Untitled/aitest/target99/backend/app/services.py', 'r') as f:
    lines = f.readlines()

import_pattern = re.compile(r'^\s*(import\s+|from\s+\S+\s+import\s+)')

for idx, line in enumerate(lines):
    if import_pattern.match(line):
        print(f"Line {idx+1}: {line.strip()}")
