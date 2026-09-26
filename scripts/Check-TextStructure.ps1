[CmdletBinding()]
param(
    [int[]]$Book = 1..5,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$issues = [Collections.Generic.List[object]]::new()

function Remove-TexComments([string]$Text) {
    [regex]::Replace($Text, '(?m)(?<!\\)%[^\r\n]*', '')
}

function Get-CommandEnd([string]$Text, [int]$Start, [int]$Arguments) {
    $position = $Start
    while ($position -lt $Text.Length -and [char]::IsWhiteSpace($Text[$position])) { $position++ }
    if ($position -lt $Text.Length -and $Text[$position] -eq '[') {
        $depth = 1
        $position++
        while ($position -lt $Text.Length -and $depth -gt 0) {
            if ($Text[$position] -eq '\') { $position += 2; continue }
            if ($Text[$position] -eq '[') { $depth++ }
            if ($Text[$position] -eq ']') { $depth-- }
            $position++
        }
    }
    for ($argument = 0; $argument -lt $Arguments; $argument++) {
        while ($position -lt $Text.Length -and [char]::IsWhiteSpace($Text[$position])) { $position++ }
        if ($position -ge $Text.Length -or $Text[$position] -ne '{') { throw 'Malformed heading command.' }
        $depth = 1
        $position++
        while ($position -lt $Text.Length -and $depth -gt 0) {
            if ($Text[$position] -eq '\') { $position += 2; continue }
            if ($Text[$position] -eq '{') { $depth++ }
            if ($Text[$position] -eq '}') { $depth-- }
            $position++
        }
        if ($depth -ne 0) { throw 'Unbalanced heading argument.' }
    }
    $position
}

function Remove-AdministrativeCommands([string]$Text) {
    $Text = [regex]::Replace($Text, '\\(?:label|BookChapterNumber)\{[^{}]*\}', '')
    [regex]::Replace($Text, '\\ProseParagraphBreak\b', '').Trim()
}

function Add-Issue([string]$Kind, [IO.FileInfo]$File, [string]$Text, [int]$Position) {
    $line = 1 + [regex]::Matches($Text.Substring(0, $Position), "`n").Count
    $relative = $File.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    $issues.Add([pscustomobject]@{Kind=$Kind; Path=$relative; Line=$line})
}

foreach ($number in $Book) {
    $files = Get-ChildItem (Join-Path $projectRoot "Book$number") -Recurse -Filter '*.tex'
    foreach ($file in $files) {
        $text = Remove-TexComments ([IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8))
        if ($file.Name -match '^Section') {
            $heading = [regex]::Match($text, '(?m)^[ \t]*\\(?<name>section|OptionalSection)(?!\*)\b')
            $subheading = [regex]::Match($text, '(?m)^[ \t]*\\(?:subsection|OptionalSubsection)(?!\*)\b')
            if ($heading.Success -and $subheading.Success -and $heading.Index -lt $subheading.Index) {
                $arity = if ($heading.Groups['name'].Value -eq 'OptionalSection') { 2 } else { 1 }
                $end = Get-CommandEnd $text ($heading.Index + $heading.Length) $arity
                $between = Remove-AdministrativeCommands ($text.Substring($end, $subheading.Index - $end))
                if ([string]::IsNullOrWhiteSpace($between)) { Add-Issue 'SectionIntroduction' $file $text $heading.Index }
                $paragraphs = [regex]::Split($between, '\r?\n\s*\r?\n')
                for ($index = 1; $index -lt $paragraphs.Count; $index++) {
                    $paragraph = $paragraphs[$index].Trim()
                    if ($paragraph.Length -ge 40 -and $paragraph -ceq $paragraphs[$index - 1].Trim()) {
                        Add-Issue 'RepeatedIntroduction' $file $text $heading.Index
                    }
                }
            }
        }

        $goals = [regex]::Match($text, '\\end\{learninggoals\}')
        if ($goals.Success) {
            $after = $goals.Index + $goals.Length
            $bodyStart = [regex]::Match($text.Substring($after), '\\input\{[^{}]*Section[^{}]*\}|(?m)^[ \t]*\\(?:section|OptionalSection)(?!\*)\b')
            if ($bodyStart.Success) {
                $between = Remove-AdministrativeCommands ($text.Substring($after, $bodyStart.Index))
                if ([string]::IsNullOrWhiteSpace($between)) { Add-Issue 'ChapterIntroduction' $file $text $goals.Index }
            }
        }

        $summary = [regex]::Match($text, '\\end\{chaptersummary\}')
        if ($summary.Success) {
            $after = $summary.Index + $summary.Length
            $exercises = [regex]::Match($text.Substring($after), '\\BookExercises\b')
            if ($exercises.Success) {
                $between = Remove-AdministrativeCommands ($text.Substring($after, $exercises.Index))
                if (-not [string]::IsNullOrWhiteSpace($between)) { Add-Issue 'TextBeforeExercises' $file $text $summary.Index }
            }
        }
    }
}

if ($AsJson) {
    ConvertTo-Json -InputObject @($issues.ToArray()) -Depth 3
} elseif ($issues.Count -gt 0) {
    $issues | Format-Table -AutoSize
} else {
    'Chapter introductions, section introductions and summary-to-exercise transitions verified.'
}
if ($issues.Count -gt 0) { exit 1 }
