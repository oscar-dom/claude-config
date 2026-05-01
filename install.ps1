# Installs claude-config skills into ~/.claude/skills/
# Re-run after `git pull` to sync changes.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSource = Join-Path $ScriptDir "skills"
$SkillsTarget = Join-Path $HOME ".claude\skills"

if (-not (Test-Path $SkillsSource)) {
    Write-Error "Source skills folder not found at $SkillsSource"
    exit 1
}

if (-not (Test-Path $SkillsTarget)) {
    New-Item -ItemType Directory -Path $SkillsTarget -Force | Out-Null
    Write-Host "Created $SkillsTarget"
}

Get-ChildItem -Path $SkillsSource -Directory | ForEach-Object {
    $skillName = $_.Name
    $dest = Join-Path $SkillsTarget $skillName

    if (Test-Path $dest) {
        Remove-Item -Recurse -Force $dest
    }
    Copy-Item -Recurse -Path $_.FullName -Destination $dest
    Write-Host "Installed skill: $skillName"
}

Write-Host ""
Write-Host "Done. Skills available at: $SkillsTarget" -ForegroundColor Green
