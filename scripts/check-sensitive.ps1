# Pre-publish sensitive-data guard for this plugin repository.
#
# Why this exists: HBuilderX silently rewrites src/manifest.json with the
# developer's real HarmonyOS bundleName, a real DCloud appid (__UNI__xxxxxxxx) and
# a full signingConfigs block (cert path, profile, store file and both encrypted
# passwords pointing at the local machine). That must never reach a public
# repository or a plugin-market package, and it is easy to miss because the file
# looks like an ordinary config edit.
#
# Every rule below is SHAPE based (key names, path prefixes, id formats), so the
# script itself carries no company or customer value. Put company-specific
# literals (your bundle-name prefix, merchant id, WeChat appid) into a local
# deny-list and pass it with -PatternsFile; keep that file out of git.
#
# Usage (also available as npm scripts, see package.json):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive.ps1
#     no arguments          scan tracked files in the working tree
#     -Cached               scan the git index instead (pre-commit use)
#     -Paths src,scripts    scan exactly these paths, untracked and ignored files
#                           included. Comma separated. Every path must exist,
#                           otherwise the script aborts instead of reporting a
#                           false "clean". Use this on the folder about to be
#                           zipped for the plugin market.
#     -PatternsFile my.txt  add extra regex patterns from a local file
#     -SelfTest             assert that every built-in rule still fires
#
# Line escape hatch: a hit line containing the marker allow-sensitive is skipped.
# The rule table below uses it, because a rule and its own test sample cannot be
# written down without matching the rule.
#
# Exit codes: 0 clean, 1 sensitive data found, 2 environment / usage error.

# NOTE: keep every literal in this file pure ASCII.
# Windows PowerShell 5.1 decodes a BOM-less file as GBK; UTF-8 Chinese bytes then
# swallow the following quote and the whole script fails to parse (silently
# doing nothing, which is the worst outcome for a guard script).
param(
    [switch]$Cached,
    [string]$Paths = '',
    [string]$PatternsFile = '',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

# git grep emits UTF-8; without this the matched source lines print as mojibake
# on a zh-CN console (default OEM code page is GBK) and become unreadable.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# pattern -> test sample. The sample is what -SelfTest writes to a throwaway
# fixture; each rule is then run against it on its own, so a rule that silently
# degraded to a no-op cannot hide behind another rule's hit.
#
# IMPORTANT: never put a literal double quote inside a pattern. PowerShell 5.1
# strips embedded double quotes while building the argv for git.exe, which
# silently degrades such a rule to a no-op (verified: the quoted variants missed
# the keyPassword and storePassword lines). The '.?' absorbs the closing JSON
# quote instead, which is why the colon rules have one and the '=' rules do not.
$rules = [ordered]@{}
# signing material: a config key name followed by an assignment. The bare key
# name in prose is legitimate documentation; the key plus a value is a leak.
$rules['certpath.?[[:space:]]*:']      = 'certpath : v'          # allow-sensitive
$rules['storeFile.?[[:space:]]*:']     = 'storeFile : v'         # allow-sensitive
$rules['storePassword.?[[:space:]]*:'] = 'storePassword : v'    # allow-sensitive
$rules['keyPassword.?[[:space:]]*:']   = 'keyPassword : v'      # allow-sensitive
$rules['certpath[[:space:]]*=']        = 'certpath = v'          # allow-sensitive
$rules['storeFile[[:space:]]*=']       = 'storeFile = v'         # allow-sensitive
$rules['storePassword[[:space:]]*=']   = 'storePassword = v'    # allow-sensitive
$rules['keyPassword[[:space:]]*=']     = 'keyPassword = v'      # allow-sensitive
# signing material: well known local storage locations
$rules['agc-certs']                  = 'dir/agc-certs/1.cer'     # allow-sensitive
# one-or-more backslashes, so both the JSON escaped form (two) and a plain single
# backslash path in a log line are matched
$rules['\.ohos\\+config']            = 'x\.ohos\\config'         # allow-sensitive
# any absolute path into a developer home directory
$rules['[A-Za-z]:\\+Users\\']        = 'c:\\Users\\someone'      # allow-sensitive
# DCloud appid of a real project. The length after the prefix varies (7 and 8 hex
# digits both occur in the wild), so match 6 or more: a fixed {8} silently passes
# a real appid whose suffix is 7 characters long.
$rules['__UNI__[0-9A-Fa-f]{6,}']     = '__UNI__ABCDEF0'          # allow-sensitive
# real WeChat open-platform appid (a placeholder such as wxYourAppId does not match)
$rules['\bwx[0-9a-f]{16}\b']         = 'wx0123456789abcdef'      # allow-sensitive
# pasted transfer package_info / long base64 blobs. Built at runtime because a
# literal of that length in this file would match the rule itself.
$rules['\b[0-9a-zA-Z+/]{120,}={0,2}\b'] = ''.PadRight(121, 'A') + '='  # allow-sensitive

$patterns = @($rules.Keys)
$samples = @($rules.Values)

if ($Cached -and $Paths -ne '') {
    Write-Host '[ERROR] -Cached and -Paths are mutually exclusive' -ForegroundColor Red
    exit 2
}

# Resolve the repository root from this script's own location, so the guard works
# no matter where it is invoked from.
$scp = $PSScriptRoot
if (-not $scp) { $scp = (Get-Location).Path }
$repoRoot = Split-Path -Parent $scp

# A pathspec that does not exist makes git grep exit 1, which means no matches.
# The guard would then report clean without having looked at anything, so verify
# the requested paths up front. This is not a theoretical problem: git grep used to
# receive the whole comma separated -Paths argument as one missing path.
$scanPaths = @()
if ($Paths -ne '') {
    foreach ($p in $Paths -split ',') {
        $t = $p.Trim().Trim('"').Trim("'")
        if ($t -eq '' -or $t -eq '.') { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $t))) {
            Write-Host "[ERROR] path does not exist: $t (relative to $repoRoot)" -ForegroundColor Red
            Write-Host '        refusing to report clean for a path that was never scanned' -ForegroundColor Red
            exit 2
        }
        $scanPaths += $t
    }
}

# Mode selects the git grep view: 'tree' = tracked working tree files, 'index' =
# staged content, 'paths' = whatever Spec lists, untracked and ignored included.
function Invoke-Grep {
    param(
        [string]$Pattern,
        [string[]]$Spec,
        [ValidateSet('tree', 'index', 'paths')][string]$Mode = 'tree'
    )
    # git parses everything after the pattern as revisions, so the mode options MUST
    # be emitted before -n/-I/-E/<pattern>/--/<paths>.
    $pre = @()
    if ($Mode -eq 'index') { $pre = @('--cached') }
    elseif ($Mode -eq 'paths') { $pre = @('--no-index', '--no-exclude-standard') }
    $gitArgs = @('grep') + $pre + @('-n', '-I', '-E', $Pattern, '--') + $Spec
    # git reports failures on stderr; with Stop, PowerShell 5.1 turns that into a
    # terminating error and the script dies before it can print its own verdict.
    $prevPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git @gitArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevPreference
    $script:grepRc = $code
    return @($out | ForEach-Object { "$_" })
}

Push-Location -LiteralPath $repoRoot
try {
    if ($SelfTest) {
        if ($samples.Count -ne $patterns.Count) {
            Write-Host '[ERROR] rule table is inconsistent' -ForegroundColor Red
            exit 2
        }
        # dist/ is gitignored, so the fixture can never be committed or shipped.
        $fixtureDir = Join-Path $repoRoot 'dist'
        if (-not (Test-Path -LiteralPath $fixtureDir)) {
            New-Item -ItemType Directory -Path $fixtureDir | Out-Null
        }
        $fixture = Join-Path $fixtureDir 'sensitive-selftest-probe.txt'
        [System.IO.File]::WriteAllLines($fixture, $samples, [System.Text.Encoding]::ASCII)
        $spec = @('dist/sensitive-selftest-probe.txt')
        $silent = @()
        try {
            for ($i = 0; $i -lt $patterns.Count; $i++) {
                $null = Invoke-Grep -Pattern $patterns[$i] -Spec $spec -Mode 'paths'
                if ($script:grepRc -gt 1) {
                    Write-Host ("[ERROR] git grep failed (rc={0}) on rule {1} - the guard did NOT run" -f $script:grepRc, $i) -ForegroundColor Red
                    exit 2
                }
                if ($script:grepRc -ne 0) { $silent += $patterns[$i] }
            }
        }
        finally {
            Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
        }
        Write-Host ("       rules: {0} patterns" -f $patterns.Count)
        if ($silent.Count -eq 0) {
            Write-Host '[OK] selftest: every rule fired on its own sample' -ForegroundColor Green
            exit 0
        }
        Write-Host ("[FAIL] selftest: {0} rule(s) matched nothing, they are no-ops:" -f $silent.Count) -ForegroundColor Red
        foreach ($s in $silent) { Write-Host ('  ' + $s) -ForegroundColor Yellow }
        exit 1
    }

    if ($PatternsFile -ne '') {
        if (-not (Test-Path -LiteralPath $PatternsFile)) {
            Write-Host "[ERROR] patterns file not found: $PatternsFile" -ForegroundColor Red
            exit 2
        }
        foreach ($line in Get-Content -LiteralPath $PatternsFile) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $patterns += $t
        }
    }

    # Lock files are full of sha512 integrity blobs (pure noise here) and log files
    # are not shippable anyway while still being able to carry real payloads.
    $defaultSpec = @('.',
        ':(exclude)package-lock.json',
        ':(exclude)pnpm-lock.yaml',
        ':(exclude)yarn.lock',
        ':(exclude)*.log')
    $mode = 'tree'
    if ($Cached) {
        $pathSpec = $defaultSpec
        $scope = 'git index'
        $mode = 'index'
    }
    elseif ($scanPaths.Count -gt 0) {
        # Scan exactly what was asked for, untracked and ignored files included.
        $pathSpec = $scanPaths
        $scope = 'explicit paths: ' + ($scanPaths -join ', ')
        $mode = 'paths'
    }
    else {
        $pathSpec = $defaultSpec
        $scope = 'working tree (tracked files)'
    }

    $hits = Invoke-Grep -Pattern ($patterns -join '|') -Spec $pathSpec -Mode $mode
    $rc = $script:grepRc
}
finally {
    Pop-Location
}

if ($rc -gt 1) {
    Write-Host "[ERROR] git grep failed (rc=$rc) - the guard did NOT run" -ForegroundColor Red
    foreach ($e in $hits) { Write-Host ('  ' + $e) }
    exit 2
}

# Per-line escape hatch for documentation that must show a config template:
# put the marker allow-sensitive anywhere on the line and it is skipped.
$filtered = @()
foreach ($h in $hits) {
    if ("$h" -notmatch 'allow-sensitive') { $filtered += "$h" }
}

if ($filtered.Count -eq 0) {
    Write-Host "[OK] clean: no sensitive pattern found in $scope" -ForegroundColor Green
    Write-Host ("     rules: {0} patterns" -f $patterns.Count)
    exit 0
}

Write-Host "[FAIL] sensitive data found in $scope" -ForegroundColor Red
foreach ($s in $filtered) {
    $line = $s
    if ($line.Length -gt 160) { $line = $line.Substring(0, 160) + ' ...' }
    Write-Host ('  ' + $line) -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Fix the values above, then re-run. Common case:' -ForegroundColor Cyan
Write-Host '  git restore src/manifest.json   # drop the HBuilderX injected bundleName + signingConfigs' -ForegroundColor Cyan
Write-Host 'A plugin-market upload must contain only src/uni_modules/xyyt-wxmerchanttransfer.' -ForegroundColor Cyan
exit 1
