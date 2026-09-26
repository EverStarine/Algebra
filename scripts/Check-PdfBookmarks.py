import re
from pathlib import Path

from pypdf import PdfReader


def walk(items, level=0):
    for item in items:
        if isinstance(item, list):
            yield from walk(item, level + 1)
        else:
            yield level, item.title


root = Path(__file__).resolve().parents[1]
failures = []
for number in range(1, 6):
    source = root / f"Book{number}"
    reader = PdfReader(root / f"Book{number}.pdf")
    entries = list(walk(reader.outline))
    chapter_count = len(list(source.glob("Part*/Chapter*/Chapter[0-9][0-9].tex")))
    appendix_count = len(list(source.glob("Appendices/Appendix*/Appendix[A-Z].tex")))
    chapters = [
        title for _, title in entries
        if re.match(r"^\u7b2c[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u96f6\u30070-9]+\u7ae0", title)
    ]
    appendices = [
        title for _, title in entries
        if re.match(r"^\u9644\u5f55\s*[A-Z](?:\s|$)", title)
    ]
    if len(chapters) != chapter_count:
        failures.append(f"Book{number}: numbered chapters {len(chapters)}/{chapter_count}")
    if len(appendices) != appendix_count:
        failures.append(f"Book{number}: numbered appendices {len(appendices)}/{appendix_count}")
    for level, title in entries:
        if level == 2 and title != "\u4e60\u9898":
            if not re.match(r"^(?:\d+|[A-Z])\.\d+\*?(?:\s|$)", title):
                failures.append(f"Book{number}: section bookmark {title!r}")
        if level == 3:
            if not re.match(r"^(?:\d+|[A-Z])\.\d+\.\d+\*?(?:\s|$)", title):
                failures.append(f"Book{number}: subsection bookmark {title!r}")
    print(f"Book{number}: {len(reader.pages)} pages; {len(chapters)} numbered chapters; "
          f"{len(appendices)} numbered appendices; {len(entries)} bookmarks")

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print("All five PDF bookmark trees have the required numbering.")
