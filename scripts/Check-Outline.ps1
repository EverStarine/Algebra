[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [switch]$ListOnly
)

# Read-only audit of the mapping from the authoritative outline to the TeX tree.
# -ListOnly exposes the outline records for tooling; it never writes files.
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$outlinePath = Join-Path $ProjectRoot '计划纲要.md'
$lines = [IO.File]::ReadAllLines($outlinePath, [Text.Encoding]::UTF8)
$numerals = @{ '一'=1; '二'=2; '三'=3; '四'=4; '五'=5; '六'=6; '七'=7; '八'=8; '九'=9; '十'=10 }
$nodes = [Collections.Generic.List[object]]::new()
$book = 0
$part = 0
$chapter = ''
$current = $null
$bookNode = $null
$partNode = $null
$chapterNode = $null
$inAppendices = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $kind = $null
    $number = ''
    $title = ''
    $optional = $false
    $path = ''
    $parent = ''
    $label = ''
    if ($line -match '^# 第([一二三四五])卷\s+(.+)$') {
        $book = $numerals[$Matches[1]]
        $part = 0
        $chapter = ''
        $inAppendices = $false
        $kind = 'Book'
        $number = [string]$book
        $title = $Matches[2]
        $path = "Book$book/Book$book.tex"
    } elseif ($line -match '^# 建议阅读层次\s*$') {
        $book = 0
        $current = $null
    } elseif ($book -gt 0 -and $line -match '^# 第([一二三四五])卷附录\s*$') {
        if ($numerals[$Matches[1]] -ne $book) { throw "Appendix volume mismatch at line $($i+1)." }
        $inAppendices = $true
        $kind = 'Appendices'
        $number = 'appendices'
        $title = '附录'
        $path = "Book$book/Appendices/Appendices.tex"
        $parent = $bookNode.Path
        $label = "b${book}:part:appendices"
    } elseif ($book -gt 0 -and $line -match '^# 第([一二三四五六七八九十])编\s+(.+)$') {
        $part = $numerals[$Matches[1]]
        $kind = 'Part'
        $number = '{0:00}' -f $part
        $title = $Matches[2]
        $path = "Book$book/Part$number/Part$number.tex"
        $parent = $bookNode.Path
        $label = "b${book}:part:$number"
        $inAppendices = $false
    } elseif ($book -gt 0 -and $line -match '^## 第(\d+)章(\*)?\s+(.+)$') {
        $kind = 'Chapter'
        $chapter = [string][int]$Matches[1]
        $number = '{0:00}' -f [int]$chapter
        $optional = $Matches[2] -eq '*'
        $title = $Matches[3]
        $path = 'Book{0}/Part{1:00}/Chapter{2}/Chapter{2}.tex' -f $book, $part, $number
        $parent = $partNode.Path
        $label = "b${book}:ch:$number"
    } elseif ($book -gt 0 -and $line -match '^## 附录 ([A-Z])\s+(.+)$') {
        if (-not $inAppendices) { throw "Appendix outside appendix block at line $($i+1)." }
        $kind = 'Appendix'
        $chapter = $Matches[1]
        $number = $chapter
        $title = $Matches[2]
        $path = "Book$book/Appendices/Appendix$number/Appendix$number.tex"
        $parent = "Book$book/Appendices/Appendices.tex"
        $label = "b${book}:app:$number"
    } elseif ($book -gt 0 -and $line -match '^### (\d+|[A-Z])\.(\d+)(\*)?\s+(.+)$') {
        if ($Matches[1] -ne $chapter) { throw "Section chapter mismatch at line $($i+1)." }
        $sectionNumber = [int]$Matches[2]
        $optional = $Matches[3] -eq '*'
        $title = $Matches[4]
        if ($inAppendices) {
            if ($optional) { throw "An appendix section must not carry an optional star." }
            $kind = 'AppendixSection'
            $number = '{0}{1:00}' -f $chapter, $sectionNumber
            $path = "Book$book/Appendices/Appendix$chapter/Section$number.tex"
            $label = "b${book}:sec:$number"
        } else {
            $kind = 'Section'
            $number = '{0:00}{1:00}' -f [int]$chapter, $sectionNumber
            $path = 'Book{0}/Part{1:00}/Chapter{2:00}/Section{3}.tex' -f $book, $part, [int]$chapter, $number
            $label = "b${book}:sec:$number"
        }
        $parent = $chapterNode.Path
    } elseif ($book -gt 0 -and $line -match '^#{1,3}\s') {
        throw "Unrecognized outline heading at line $($i+1): $line"
    }

    if ($kind) {
        $current = [pscustomobject]@{
            Kind=$kind; Book=$book; Number=$number; Title=$title; Optional=$optional
            Path=$path; Parent=$parent; Label=$label; SourceLine=$i+1
            RawHeading=$line; Notes=[Collections.Generic.List[string]]::new()
        }
        $nodes.Add($current)
        switch ($kind) {
            'Book' { $bookNode = $current }
            'Part' { $partNode = $current }
            'Chapter' { $chapterNode = $current }
            'Appendix' { $chapterNode = $current }
        }
    } elseif ($null -ne $current -and $book -gt 0) {
        $current.Notes.Add($line)
    }
}

if (($nodes | Where-Object Kind -eq 'Book').Count -ne 5) { throw 'The outline must contain five full volume blocks.' }
if (($nodes | Group-Object Path | Where-Object Count -gt 1).Count) { throw 'Duplicate outline paths.' }
foreach ($b in 1..5) {
    $chapters = @($nodes | Where-Object { $_.Book -eq $b -and $_.Kind -eq 'Chapter' })
    for ($i=0; $i -lt $chapters.Count; $i++) {
        if ([int]$chapters[$i].Number -ne $i+1) { throw "Book $b chapter numbering is not contiguous." }
    }
    $parts = @($nodes | Where-Object { $_.Book -eq $b -and $_.Kind -eq 'Part' })
    for ($i=0; $i -lt $parts.Count; $i++) {
        if ([int]$parts[$i].Number -ne $i+1) { throw "Book $b part numbering is not contiguous." }
    }
    $appendices = @($nodes | Where-Object { $_.Book -eq $b -and $_.Kind -eq 'Appendix' })
    for ($i=0; $i -lt $appendices.Count; $i++) {
        if ($appendices[$i].Number -ne [string][char](65+$i)) { throw "Book $b appendix numbering is not contiguous." }
    }
    foreach ($container in @($chapters) + @($appendices)) {
        $sections = @($nodes | Where-Object { $_.Parent -eq $container.Path })
        for ($i=0; $i -lt $sections.Count; $i++) {
            if ([int]$sections[$i].Number.Substring($sections[$i].Number.Length-2) -ne $i+1) {
                throw "Section numbering is not contiguous under $($container.Path)."
            }
        }
    }
}
if ($ListOnly) { $nodes; return }

$failures = [Collections.Generic.List[string]]::new()
foreach ($node in $nodes) {
    $file = Join-Path $ProjectRoot $node.Path
    if (-not [IO.File]::Exists($file)) { $failures.Add("Missing file: $($node.Path)"); continue }
    $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
    if (-not $text.Contains('% 纲要标题：' + $node.RawHeading)) {
        $failures.Add("Missing or changed outline title record: $($node.Path)")
    }
    if ($node.Label -and -not $text.Contains('{' + $node.Label + '}')) {
        $failures.Add("Missing stable label: $($node.Path)")
    }
    if ($node.Kind -in @('Chapter','Section')) {
        $expected = if ($node.Optional) { '\Optional' + $node.Kind + '{' } else { '\' + $node.Kind.ToLowerInvariant() + '{' }
        if (-not $text.Contains($expected)) { $failures.Add("Optional marker or heading command mismatch: $($node.Path)") }
    }
    foreach ($note in $node.Notes) {
        if ($note.Trim() -and -not $text.Contains('% ' + $note)) {
            $failures.Add("Outline detail missing from source comments: $($node.Path): $note")
        }
    }
    if ($node.Parent) {
        $parentFile = Join-Path $ProjectRoot $node.Parent
        if ([IO.File]::Exists($parentFile)) {
            $parentText = [IO.File]::ReadAllText($parentFile, [Text.Encoding]::UTF8)
            $relative = $node.Path.Substring(('Book' + $node.Book + '/').Length)
            $input = '\input{' + $relative.Substring(0, $relative.Length-4) + '}'
            $count = [regex]::Matches($parentText, [regex]::Escape($input)).Count
            if ($count -ne 1) { $failures.Add("Expected exactly one parent input for $($node.Path); found $count.") }
        }
    }
}

$allLabels = [Collections.Generic.List[string]]::new()
foreach ($b in 1..5) {
    $bookRoot = Join-Path $ProjectRoot "Book$b"
    $allTex = @(Get-ChildItem -LiteralPath $bookRoot -Filter '*.tex' -Recurse -File)
    $reachable = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [Collections.Generic.Queue[string]]::new()
    $queue.Enqueue((Join-Path $bookRoot "Book$b.tex"))
    while ($queue.Count) {
        $file = $queue.Dequeue()
        if (-not $reachable.Add($file)) { continue }
        if (-not [IO.File]::Exists($file)) { $failures.Add("Missing input target: $file"); continue }
        $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
        $activeText = (($text -split '\r?\n') | Where-Object { $_ -notmatch '^\s*%' }) -join "`n"
        foreach ($match in [regex]::Matches($activeText, '\\input\{([^}]+)\}')) {
            $input = $match.Groups[1].Value
            if ($input -notmatch '\.tex$') { $input += '.tex' }
            $target = [IO.Path]::GetFullPath((Join-Path $bookRoot $input))
            if (-not [IO.File]::Exists($target)) { $failures.Add("Missing input target: $file -> $input") }
            elseif ($target.StartsWith($bookRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $queue.Enqueue($target) }
        }
    }
    foreach ($file in $allTex) {
        if (-not $reachable.Contains($file.FullName)) { $failures.Add("Unreachable TeX file: $($file.FullName)") }
        $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
        if ($text -match '(?m)^% !TeX root = (.+)$') {
            $magicRoot = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $Matches[1].Trim()))
            if ($magicRoot -ne (Join-Path $bookRoot "Book$b.tex")) { $failures.Add("Wrong editor root: $($file.FullName)") }
        }
        foreach ($match in [regex]::Matches($text, '\\label\{([^}]+)\}')) { $allLabels.Add($match.Groups[1].Value) }
    }
}
foreach ($duplicate in @($allLabels | Group-Object | Where-Object Count -gt 1)) {
    $failures.Add("Duplicate explicit label: $($duplicate.Name)")
}
if ($failures.Count) { throw ($failures -join "`n") }

foreach ($b in 1..5) {
    $set = @($nodes | Where-Object Book -eq $b)
    [pscustomobject]@{
        Book=$b
        Parts=@($set | Where-Object Kind -eq 'Part').Count
        Chapters=@($set | Where-Object Kind -eq 'Chapter').Count
        Sections=@($set | Where-Object Kind -eq 'Section').Count
        Appendices=@($set | Where-Object Kind -eq 'Appendix').Count
        AppendixSections=@($set | Where-Object Kind -eq 'AppendixSection').Count
        OptionalChapters=@($set | Where-Object { $_.Kind -eq 'Chapter' -and $_.Optional }).Count
        OptionalSections=@($set | Where-Object { $_.Kind -eq 'Section' -and $_.Optional }).Count
    }
}
Write-Host 'Outline headings, detail comments, numbering, optional markers, input graph and editor roots verified.'
