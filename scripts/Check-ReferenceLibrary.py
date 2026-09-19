"""Read-only integrity check for the local reference library and master Bib keys."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import datetime
import calendar

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
args = parser.parse_args()
root = args.root.resolve()
library = root / '参考文献原文件'
catalog_path = library / 'catalog.json'
if not catalog_path.exists():
    raise SystemExit('Local library not installed. See 参考资料目录.md; third-party PDFs are excluded from Git.')
catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
bib = (root / 'Shared/References.bib').read_text(encoding='utf-8')
keys = re.findall(r'^@\w+\s*\{\s*([^,\s]+)', bib, flags=re.M)
errors = []
if len(keys) != len(set(keys)):
    errors.append('Duplicate citation keys in master Bib database')
eligibility = json.loads((library / '入库资格清单.json').read_text(encoding='utf-8'))
eligible_keys = {r['key'] for r in eligibility if r['in_formal_bib']}
if set(keys) != eligible_keys:
    errors.append('Master Bib differs from the publication-and-age eligibility register')
for match in re.finditer(r'(?ms)^@(\w+)\{([^,]+),(.*?)(?=^@|\Z)', bib):
    kind, key, block = match.groups()
    if kind.lower() not in {'book', 'article', 'inbook', 'incollection'}:
        errors.append(f'Unapproved reference type in formal Bib: {key}')
    date_match = re.search(r'(?m)^\s*date\s*=\s*\{(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?\}', block)
    if not date_match:
        errors.append(f'Unverified publication date in formal Bib: {key}')
        continue
    year, month, day = date_match.groups()
    year, month = int(year), int(month or 12)
    latest = datetime.date(year, month, int(day or calendar.monthrange(year, month)[1]))
    minimum = 3 if kind.lower() == 'article' else 5
    if latest > datetime.date(2026 - minimum, 9, 18):
        errors.append(f'Publication does not meet age requirement: {key}')
expected = set()
for row in catalog:
    key = row['key']
    if row.get('formal_bib') and key not in keys:
        errors.append(f'Bib key missing: {key}')
    if not row.get('formal_bib') and key in keys:
        errors.append(f'Internal-only reference incorrectly in formal Bib: {key}')
    if not row.get('path'):
        continue
    pdf = (root / row['path']).resolve()
    if not pdf.is_relative_to(library.resolve()):
        errors.append(f'File outside library: {key}')
        continue
    expected.add(pdf)
    if not pdf.is_file():
        errors.append(f'PDF missing: {key}')
        continue
    digest = hashlib.sha256()
    with pdf.open('rb') as stream:
        header = stream.read(1024)
        if b'%PDF-' not in header:
            errors.append(f'Invalid PDF header: {key}')
        digest.update(header)
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    if digest.hexdigest() != row['sha256']:
        errors.append(f'SHA256 mismatch: {key}')
    if pdf.stat().st_size != row['bytes']:
        errors.append(f'File size mismatch: {key}')
actual = {p.resolve() for folder in ['Shared','Book1','Book2','Book3','Book4','Book5'] for p in (library / folder).glob('*.pdf')}
for extra in sorted(actual - expected):
    errors.append(f'Unregistered PDF: {extra.relative_to(root)}')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Verified {len(expected)} local PDFs and hashes; {len(catalog)} internal records; {len(keys)} eligible formal Bib entries (no exceptions).')
