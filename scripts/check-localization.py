#!/usr/bin/env python3
"""Check shared UI translations and format arguments for both apps."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
swift_catalog = root / "App/Resources/English.json"
android_catalog = root / "Android/app/src/main/assets/English.json"
failures = []

def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            failures.append(f"Duplicate translation: {key}")
        result[key] = value
    return result

words = json.loads(swift_catalog.read_text(), object_pairs_hook=unique_pairs)
for name in ("English", "Traditional"):
    ios = root / f"App/Resources/{name}.json"
    android = root / f"Android/app/src/main/assets/{name}.json"
    catalog = json.loads(ios.read_text(), object_pairs_hook=unique_pairs)
    if ios.read_bytes() != android.read_bytes():
        failures.append(f"The iOS and Android {name} catalogs differ.")
    if set(catalog) != set(words):
        failures.append(f"The {name} translation keys differ.")
    for key, value in catalog.items():
        if not value.strip():
            failures.append(f"Empty {name} translation: {key}")
        if sorted(re.findall(r"\{\d+\}", key)) != sorted(re.findall(r"\{\d+\}", value)):
            failures.append(f"Mismatched {name} format arguments: {key}")

calls = re.compile(r'(?:L10n\.text|localize)\(\s*"((?:\\.|[^"\\])*)"')
paths = list((root / "App").rglob("*.swift"))
paths += list((root / "Sources").rglob("*.swift"))
paths += list((root / "Android/app/src/main/java").rglob("*.kt"))
for path in paths:
    for match in calls.finditer(path.read_text()):
        key = json.loads('"' + match.group(1) + '"')
        if re.search(r"[\u4e00-\u9fff]", key) and key not in words:
            failures.append(f"Missing translation in {path.relative_to(root)}: {key}")

if failures:
    raise SystemExit("\n".join(failures))
print(f"PASS: {len(words)} shared translations, matching arguments and localized call sites.")
