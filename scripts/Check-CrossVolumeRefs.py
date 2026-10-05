"""Check annotated cross-volume references against compiled target labels.

Only references explicitly annotated with a stable target label are covered.
The checker does not certify the mathematical applicability of a citation.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MARKER = re.compile(r"^\s*%\s*跨卷(?:引用)?目标：(.+)$")
BINDING = re.compile(r"(b([1-5]):[A-Za-z0-9:_-]+)（(?:第[一二三四五]卷)?(?:定理|命题|引理|推论|定义|例)?([0-9A-Z]+(?:\.[0-9A-Z]+)*)）")
KINDS = {"theorem":"定理", "proposition":"命题", "lemma":"引理", "corollary":"推论", "definition":"定义", "example":"例"}

def load_target(label, volume, cache):
    if volume not in cache:
        path = ROOT / f"tmp/build/Book{volume}/Book{volume}.aux"
        if not path.is_file():
            raise ValueError(f"Book{volume}: missing target AUX; build this volume first")
        text = path.read_text(encoding="utf-8")
        numbers = dict(re.findall(r"\\newlabel\{([^{}]+)\}\{\{([^{}]*)\}",text))
        kinds = dict(re.findall(r"\\newlabel\{([^{}]+)@cref\}\{\{\[([^\]]+)\]",text))
        cache[volume] = numbers,kinds
    numbers,kinds = cache[volume]
    if label not in numbers:
        raise ValueError(f"{label}: target label not found")
    if kinds.get(label) not in KINDS:
        raise ValueError(f"{label}: unsupported target result kind {kinds.get(label)}")
    return numbers[label],KINDS[kinds[label]]

def check_source(path, text, cache):
    issues, checked = [], 0
    lines = text.splitlines()
    for index,line in enumerate(lines):
        marker = MARKER.match(line)
        if not marker:
            continue
        bindings = BINDING.findall(marker.group(1))
        where = f"{path}:{index+1}"
        if not bindings:
            issues.append(where+": no stable target binding in annotation")
            continue
        paragraph = []
        for following in lines[index+1:]:
            if not following.strip():
                break
            if not following.lstrip().startswith("%"):
                paragraph.append(following)
        caller = "\n".join(paragraph)
        for label,volume,declared in bindings:
            checked += 1
            try:
                actual,kind = load_target(label,volume,cache)
            except ValueError as error:
                issues.append(where+": "+str(error))
                continue
            if actual != declared:
                issues.append(f"{where}: {label}: declared {declared}, target is {actual}")
            pattern = re.escape(kind)+r"\s*"+re.escape(actual)+r"(?![0-9.])"
            if not re.search(pattern,caller):
                issues.append(f"{where}: following paragraph does not cite {kind}{actual} for {label}")
    return checked,issues

def main():
    cache,issues,checked,files = {},[],0,0
    for volume in range(1,6):
        for path in (ROOT/f"Book{volume}").rglob("*.tex"):
            count,found = check_source(path.relative_to(ROOT).as_posix(),path.read_text(encoding="utf-8-sig"),cache)
            checked += count
            files += bool(count)
            issues.extend(found)
    for issue in issues:
        print(issue)
    print(f"Checked {checked} annotated target bindings in {files} source files against target AUX labels.")
    print("Coverage is limited to annotated references; citation applicability still requires source review.")
    return bool(issues)

if __name__ == "__main__":
    sys.exit(main())
