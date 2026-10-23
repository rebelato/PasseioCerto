#!/usr/bin/env python3
"""Import compiler-extracted keys after an iOS build with SWIFT_EMIT_LOC_STRINGS=YES.
Usage: python3 scripts/update-localizations.py <Objects-normal/arm64 directory>
Preserves existing entries/translations. The project's source language is pt;
pt-BR is its sole localized language. No translated languages are fabricated.
"""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
path = root / 'App/Localizable.xcstrings'
catalog = json.loads(path.read_text()) if path.exists() else {'sourceLanguage': 'pt', 'strings': {}, 'version': '1.0'}
files = list(Path(sys.argv[1]).glob('*.stringsdata'))
if not files:
    raise SystemExit('No compiler extraction files found; build with SWIFT_EMIT_LOC_STRINGS=YES first.')
for file in files:
    for item in json.loads(file.read_text()).get('tables', {}).get('Localizable', []):
        key = item['key']
        if not key:
            continue
        entry = catalog['strings'].setdefault(key, {})
        entry.setdefault('localizations', {}).setdefault('pt-BR', {'stringUnit': {'state': 'translated', 'value': key}})
catalog['strings'] = dict(sorted(catalog['strings'].items()))
path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
print(f"{len(catalog['strings'])} localized keys")
