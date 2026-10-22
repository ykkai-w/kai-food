#!/usr/bin/env python3
"""Check the source tree and optional release archives without printing secrets."""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.build', '.swiftpm', '.gradle', '.kotlin', 'build', 'DerivedData', 'dist', 'xcuserdata', '__pycache__'}
FORBIDDEN_NAMES = {'PrivateProviders.json', 'signing.properties', 'local.properties', 'embedded.mobileprovision', 'meals.json', 'chat.json', 'frequent-foods.json'}
FORBIDDEN_EXTENSIONS = {'.jks', '.keystore', '.p12', '.mobileprovision', '.cer', '.xcuserstate'}
PATTERNS = [
    ('provider credential', re.compile(rb'\bsk-[A-Za-z0-9_-]{24,}\b')),
    ('GLM credential', re.compile(rb'\b[a-f0-9]{32}\.[A-Za-z0-9]{16,}\b')),
    ('GitHub credential', re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b')),
    ('private key', re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
]
failures = []
count = 0

def inspect(name, data, source=False):
    global count
    count += 1
    path = Path(name)
    if path.name in FORBIDDEN_NAMES or path.suffix in FORBIDDEN_EXTENSIONS or path.name.startswith('.env'):
        failures.append((name, 'private file'))
    for label, pattern in PATTERNS:
        if pattern.search(data):
            failures.append((name, label))
    if source and path.suffix in {'.swift', '.kt', '.kts', '.md', '.plist', '.pbxproj', '.json', '.xml'}:
        if b'/Users/' in data:
            failures.append((name, 'personal absolute path'))
    if source and path.suffix == '.md':
        content = data.decode('utf-8', errors='replace')
        if any(word in content for word in ('不是', '不代表', 'Codex', 'codex')):
            failures.append((name, 'publication wording'))

for path in ROOT.rglob('*'):
    relative = path.relative_to(ROOT)
    if any(part in SKIP for part in relative.parts):
        continue
    if path.is_symlink():
        failures.append((str(relative), 'symlink'))
    elif path.is_file():
        inspect(str(relative), path.read_bytes(), source=True)

for argument in sys.argv[1:]:
    archive = Path(argument)
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            if not entry.is_dir():
                inspect(f'{archive.name}/{entry.filename}', package.read(entry))

if failures:
    for name, reason in failures:
        print(f'CHECK: {name} ({reason})')
    raise SystemExit(1)
print(f'Public package check passed: {count} files.')
