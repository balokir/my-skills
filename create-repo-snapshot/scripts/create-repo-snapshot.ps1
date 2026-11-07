$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Output @(
        "Usage:",
        "  create-repo-snapshot.ps1 --output <zip-path> \",
        "    --include <path> [--include <path> ...] \",
        "    [--base-ref <git-ref> --include-changed <path> [--include-changed <path> ...]] [--dry-run]",
        "",
        "Options:",
        "  --output <zip-path>       Complete destination ZIP path; required once.",
        "  --base-ref <git-ref>      Git ref used to resolve the merge base; required with --include-changed.",
        "  --include <path>          Existing repository-relative file or directory; repeatable.",
        "  --include-changed <path>  Existing repository-relative changed-file root; optional and repeatable.",
        "  --dry-run                 Print the exact selection without creating an archive.",
        "  --help                    Print this help."
    )
}

function Test-InsidePath {
    param([string] $Path, [string] $Root)

    $Comparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    $Path.Equals($Root, $Comparison) -or
        $Path.StartsWith($Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, $Comparison)
}

function Get-NormalizedInclude {
    param([string] $Option, [string] $Value, [string] $RepoRoot)

    if ([IO.Path]::IsPathRooted($Value)) {
        throw "$Option path must be repository-relative: $Value"
    }
    $LexicalPath = [IO.Path]::GetFullPath((Join-Path $RepoRoot $Value))
    if (-not (Test-InsidePath $LexicalPath $RepoRoot)) {
        throw "$Option path resolves outside the repository: $Value"
    }
    $Item = Get-Item -LiteralPath $LexicalPath -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item) {
        throw "$Option path does not exist: $Value"
    }
    $ResolvedPath = $Item.FullName
    if ($null -ne $Item.LinkType) {
        $ResolvedItem = $Item.ResolveLinkTarget($true)
        if ($null -eq $ResolvedItem) {
            throw "$Option path cannot be resolved: $Value"
        }
        $ResolvedPath = $ResolvedItem.FullName
    }
    if (-not (Test-InsidePath $ResolvedPath $RepoRoot)) {
        throw "$Option path resolves outside the repository: $Value"
    }
    [IO.Path]::GetRelativePath($RepoRoot, $LexicalPath).Replace("\", "/")
}

function Invoke-GitLines {
    param(
        [System.Management.Automation.CommandInfo] $GitCommand,
        [string] $RepoRoot,
        [string[]] $GitArguments
    )

    $Output = @(& $GitCommand.Source -C $RepoRoot -c core.quotepath=false @GitArguments 2>&1 |
        ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        throw "Git file selection failed: $($Output -join [Environment]::NewLine)"
    }
    $Output
}

function Test-UnderRequestedRoot {
    param([string] $Path, [string[]] $Roots)

    foreach ($Root in $Roots) {
        if ($Root -eq "." -or $Path -ceq $Root -or $Path.StartsWith("$Root/", [StringComparison]::Ordinal)) {
            return $true
        }
    }
    $false
}

function Get-ArchiveEntries {
    param(
        [System.Management.Automation.CommandInfo] $SevenZip,
        [string] $ArchivePath
    )

    $Listing = @(& $SevenZip.Source l -slt -sccUTF-8 $ArchivePath 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        throw "archive entry inspection failed."
    }
    $Entries = [Collections.Generic.List[string]]::new()
    $CurrentPath = $null
    foreach ($Line in $Listing) {
        if ($Line.StartsWith("Path = ", [StringComparison]::Ordinal)) {
            $CurrentPath = $Line.Substring(7)
        } elseif ($Line -eq "Folder = -" -and $null -ne $CurrentPath) {
            $Entries.Add($CurrentPath.Replace("\", "/"))
        }
    }
    $Entries.ToArray()
}

function Assert-ExactEntries {
    param([string[]] $Expected, [string[]] $Actual)

    $ExpectedSorted = [string[]] @($Expected)
    $ActualSorted = [string[]] @($Actual)
    [Array]::Sort($ExpectedSorted, [StringComparer]::Ordinal)
    [Array]::Sort($ActualSorted, [StringComparer]::Ordinal)
    if ($ExpectedSorted.Count -ne $ActualSorted.Count) {
        throw "archive entry verification failed. Expected: $($ExpectedSorted -join ', '); actual: $($ActualSorted -join ', ')"
    }
    for ($Index = 0; $Index -lt $ExpectedSorted.Count; $Index++) {
        if ($ExpectedSorted[$Index] -cne $ActualSorted[$Index]) {
            throw "archive entry verification failed. Expected: $($ExpectedSorted -join ', '); actual: $($ActualSorted -join ', ')"
        }
    }
}

$TempRoot = $null
$TempOutput = $null

try {
    $OutputValue = $null
    $BaseRef = $null
    $OutputSeen = $false
    $BaseRefSeen = $false
    $DryRun = $false
    $Includes = [Collections.Generic.List[string]]::new()
    $ChangedIncludes = [Collections.Generic.List[string]]::new()

    for ($Index = 0; $Index -lt $args.Count; $Index++) {
        $Option = $args[$Index]
        switch ($Option) {
            "--output" {
                if ($Index + 1 -ge $args.Count -or [string]::IsNullOrEmpty($args[$Index + 1]) -or
                    $args[$Index + 1].StartsWith("--", [StringComparison]::Ordinal)) {
                    throw "--output requires a value."
                }
                if ($OutputSeen) {
                    throw "--output may be specified only once."
                }
                $Index++
                $OutputValue = $args[$Index]
                $OutputSeen = $true
            }
            "--base-ref" {
                if ($Index + 1 -ge $args.Count -or [string]::IsNullOrEmpty($args[$Index + 1]) -or
                    $args[$Index + 1].StartsWith("--", [StringComparison]::Ordinal)) {
                    throw "--base-ref requires a value."
                }
                if ($BaseRefSeen) {
                    throw "--base-ref may be specified only once."
                }
                $Index++
                $BaseRef = $args[$Index]
                $BaseRefSeen = $true
            }
            "--include" {
                if ($Index + 1 -ge $args.Count -or [string]::IsNullOrEmpty($args[$Index + 1]) -or
                    $args[$Index + 1].StartsWith("--", [StringComparison]::Ordinal)) {
                    throw "--include requires a value."
                }
                $Index++
                $Includes.Add($args[$Index])
            }
            "--include-changed" {
                if ($Index + 1 -ge $args.Count -or [string]::IsNullOrEmpty($args[$Index + 1]) -or
                    $args[$Index + 1].StartsWith("--", [StringComparison]::Ordinal)) {
                    throw "--include-changed requires a value."
                }
                $Index++
                $ChangedIncludes.Add($args[$Index])
            }
            "--dry-run" {
                $DryRun = $true
            }
            "--help" {
                Show-Usage
                exit 0
            }
            default {
                throw "unknown argument: $Option"
            }
        }
    }

    if (-not $OutputSeen) {
        throw "--output is required."
    }
    if ($Includes.Count -eq 0) {
        throw "at least one --include is required."
    }
    if ($ChangedIncludes.Count -gt 0 -and -not $BaseRefSeen) {
        throw "--base-ref is required when --include-changed is specified."
    }

    $GitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $GitCommand) {
        throw "Git is required but was not found on PATH."
    }
    $RepoOutput = @(& $GitCommand.Source rev-parse --show-toplevel 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0 -or $RepoOutput.Count -ne 1) {
        throw "the current directory is not inside a Git worktree."
    }
    $RepoRoot = [IO.Path]::GetFullPath($RepoOutput[0])

    if ([IO.Path]::IsPathRooted($OutputValue)) {
        $OutputPath = [IO.Path]::GetFullPath($OutputValue)
    } else {
        $OutputPath = [IO.Path]::GetFullPath((Join-Path $RepoRoot $OutputValue))
    }
    $OutputParent = [IO.Path]::GetDirectoryName($OutputPath)
    if (-not (Test-Path -LiteralPath $OutputParent -PathType Container)) {
        throw "output parent directory does not exist: $OutputParent"
    }
    $OutputParent = (Get-Item -LiteralPath $OutputParent -Force).FullName
    $OutputPath = Join-Path $OutputParent ([IO.Path]::GetFileName($OutputPath))
    if (Test-Path -LiteralPath $OutputPath -PathType Container) {
        throw "output path is a directory: $OutputPath"
    }

    $MergeBase = $null
    if ($ChangedIncludes.Count -gt 0) {
        & $GitCommand.Source -C $RepoRoot rev-parse --verify --quiet "$BaseRef^{commit}" *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "base ref does not resolve to a commit: $BaseRef"
        }
        $MergeBaseOutput = @(& $GitCommand.Source -C $RepoRoot merge-base HEAD $BaseRef 2>&1 |
            ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0 -or $MergeBaseOutput.Count -ne 1 -or [string]::IsNullOrWhiteSpace($MergeBaseOutput[0])) {
            throw "could not resolve a merge base between HEAD and base ref: $BaseRef"
        }
        $MergeBase = $MergeBaseOutput[0].Trim()
    }

    $NormalizedIncludes = [Collections.Generic.List[string]]::new()
    $NormalizedChangedIncludes = [Collections.Generic.List[string]]::new()
    $AllRoots = [Collections.Generic.List[string]]::new()
    foreach ($IncludePath in $Includes) {
        $Normalized = Get-NormalizedInclude "--include" $IncludePath $RepoRoot
        $NormalizedIncludes.Add($Normalized)
        $AllRoots.Add($Normalized)
    }
    foreach ($IncludePath in $ChangedIncludes) {
        $Normalized = Get-NormalizedInclude "--include-changed" $IncludePath $RepoRoot
        $NormalizedChangedIncludes.Add($Normalized)
        $AllRoots.Add($Normalized)
    }

    $Candidates = [Collections.Generic.List[string]]::new()
    foreach ($IncludePath in $NormalizedIncludes) {
        $Lines = Invoke-GitLines $GitCommand $RepoRoot @(
            "ls-files", "--cached", "--others", "--exclude-standard", "--", $IncludePath
        )
        foreach ($Line in $Lines) {
            $Candidates.Add($Line)
        }
    }
    foreach ($IncludePath in $NormalizedChangedIncludes) {
        $Commands = @(
            @("diff", "--name-only", "--diff-filter=ACMRTUXB", $MergeBase, "HEAD", "--", $IncludePath),
            @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB", "--", $IncludePath),
            @("diff", "--name-only", "--diff-filter=ACMRTUXB", "--", $IncludePath),
            @("ls-files", "--others", "--exclude-standard", "--", $IncludePath)
        )
        foreach ($Command in $Commands) {
            $Lines = Invoke-GitLines $GitCommand $RepoRoot $Command
            foreach ($Line in $Lines) {
                $Candidates.Add($Line)
            }
        }
    }

    $SelectedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $PathComparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    foreach ($CandidateValue in $Candidates) {
        $Candidate = $CandidateValue.Replace("\", "/")
        if ($Candidate.StartsWith("./", [StringComparison]::Ordinal)) {
            $Candidate = $Candidate.Substring(2)
        }
        if ([string]::IsNullOrEmpty($Candidate) -or
            -not (Test-UnderRequestedRoot $Candidate $AllRoots.ToArray())) {
            continue
        }
        $CandidatePath = [IO.Path]::GetFullPath((Join-Path $RepoRoot $Candidate))
        $Item = Get-Item -LiteralPath $CandidatePath -Force -ErrorAction SilentlyContinue
        if ($null -eq $Item -or ($Item.PSIsContainer -and $null -eq $Item.LinkType)) {
            continue
        }
        $ResolvedCandidate = $Item.FullName
        if ($null -ne $Item.LinkType) {
            $ResolvedItem = $Item.ResolveLinkTarget($true)
            if ($null -eq $ResolvedItem) {
                throw "selected symbolic link cannot be resolved: $Candidate"
            }
            $ResolvedCandidate = $ResolvedItem.FullName
            if (-not (Test-InsidePath $ResolvedCandidate $RepoRoot)) {
                throw "selected symbolic link resolves outside the repository: $Candidate"
            }
            if ($ResolvedItem.PSIsContainer) {
                throw "selected symbolic link does not resolve to a file: $Candidate"
            }
        }
        if ($CandidatePath.Equals($OutputPath, $PathComparison) -or
            $ResolvedCandidate.Equals($OutputPath, $PathComparison)) {
            continue
        }
        $SelectedSet.Add($Candidate) | Out-Null
    }

    if ($SelectedSet.Count -eq 0) {
        throw "computed file selection is empty."
    }
    $Selected = [string[]] @($SelectedSet)
    [Array]::Sort($Selected, [StringComparer]::Ordinal)

    if ($DryRun) {
        Write-Output "Dry run: repository snapshot selection"
        Write-Output "Destination: $OutputPath"
        if ($null -ne $MergeBase) {
            Write-Output "Merge base: $MergeBase"
        }
        Write-Output "Selected files: $($Selected.Count)"
        foreach ($SelectedPath in $Selected) {
            Write-Output "FILE $SelectedPath"
        }
        exit 0
    }

    $SevenZip = Get-Command 7za -ErrorAction SilentlyContinue
    if ($null -eq $SevenZip) {
        throw "7za is required for archive creation and inspection but was not found on PATH."
    }

    $TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("create-repo-snapshot-" + [guid]::NewGuid().ToString("N"))
    $StagingDirectory = Join-Path $TempRoot "staging"
    $SelectionFile = Join-Path $TempRoot "selection.txt"
    New-Item -ItemType Directory -Path $StagingDirectory -Force | Out-Null
    Set-Content -LiteralPath $SelectionFile -Value $Selected -Encoding utf8

    foreach ($SelectedPath in $Selected) {
        $SourceItem = Get-Item -LiteralPath (Join-Path $RepoRoot $SelectedPath) -Force
        $SourcePath = $SourceItem.FullName
        if ($null -ne $SourceItem.LinkType) {
            $SourcePath = $SourceItem.ResolveLinkTarget($true).FullName
        }
        $DestinationPath = Join-Path $StagingDirectory $SelectedPath
        $DestinationParent = [IO.Path]::GetDirectoryName($DestinationPath)
        New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
        [IO.File]::Copy($SourcePath, $DestinationPath, $false)
    }

    $TempOutput = Join-Path $OutputParent (
        "." + [IO.Path]::GetFileName($OutputPath) + ".tmp." + [guid]::NewGuid().ToString("N") + ".zip"
    )
    Push-Location $StagingDirectory
    try {
        $ArchiveOutput = @(& $SevenZip.Source a -tzip -scsUTF-8 -sccUTF-8 $TempOutput "@$SelectionFile" 2>&1 |
            ForEach-Object { "$_" })
        $ArchiveStatus = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($ArchiveStatus -ne 0) {
        throw "archive creation failed."
    }

    $ArchiveEntries = Get-ArchiveEntries $SevenZip $TempOutput
    Assert-ExactEntries $Selected $ArchiveEntries

    [IO.File]::Move($TempOutput, $OutputPath, $true)
    $TempOutput = $null

    Write-Output "Created repository snapshot: $OutputPath"
    if ($null -ne $MergeBase) {
        Write-Output "Merge base: $MergeBase"
    }
    Write-Output "Selected files: $($Selected.Count)"
} catch {
    [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
    exit 1
} finally {
    if ($null -ne $TempOutput -and (Test-Path -LiteralPath $TempOutput -PathType Leaf)) {
        Remove-Item -LiteralPath $TempOutput -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $TempRoot -and (Test-Path -LiteralPath $TempRoot -PathType Container)) {
        $SystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
        $ResolvedTempRoot = [IO.Path]::GetFullPath($TempRoot)
        if ($ResolvedTempRoot.StartsWith($SystemTemp + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
            [IO.Path]::GetFileName($ResolvedTempRoot).StartsWith("create-repo-snapshot-", [StringComparison]::Ordinal)) {
            Remove-Item -LiteralPath $ResolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
