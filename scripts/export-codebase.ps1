[CmdletBinding()]
param(
    [string]$OutputPath = "handoff/obsidian-sync-ios-codebase.txt"
)

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))
$outputDirectory = Split-Path -Parent $resolvedOutputPath

function Get-RepositoryRelativePath {
    param([Parameter(Mandatory = $true)][string]$FullName)

    $rootWithSeparator = $repositoryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $rootUri = [System.Uri]::new($rootWithSeparator)
    $fileUri = [System.Uri]::new($FullName)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString()).Replace('/', '\')
}

if (-not $resolvedOutputPath.StartsWith($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputPath must stay inside the repository."
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$excludedDirectoryNames = @(
    ".git",
    ".build",
    ".swiftpm",
    ".xcodeproj",
    ".xcworkspace",
    "build",
    "Build",
    "DerivedData",
    "xcuserdata",
    "node_modules",
    "vendor",
    "coverage",
    ".coverage",
    ".pytest_cache",
    "__pycache__"
)

$excludedExtensions = @(
    ".md",
    ".markdown",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".pdf",
    ".zip",
    ".tar",
    ".gz",
    ".7z",
    ".a",
    ".o",
    ".dylib",
    ".so",
    ".dll",
    ".exe",
    ".pdb",
    ".xcframework"
)

$files = Get-ChildItem -LiteralPath $repositoryRoot -File -Recurse -Force | Where-Object {
    $file = $_
    $relativePath = Get-RepositoryRelativePath -FullName $file.FullName
    $pathParts = $relativePath -split '[\\/]'
    $isExcludedDirectory = $false

    foreach ($part in $pathParts) {
        if ($excludedDirectoryNames -contains $part) {
            $isExcludedDirectory = $true
            break
        }
    }

    -not $isExcludedDirectory -and
        $excludedExtensions -notcontains $file.Extension.ToLowerInvariant() -and
        $file.FullName -ne $resolvedOutputPath
} | Sort-Object FullName

$branch = (& git -C $repositoryRoot branch --show-current 2>$null) -join "`n"
$head = (& git -C $repositoryRoot log -1 --pretty=format:"%H %s" 2>$null) -join "`n"
$status = (& git -C $repositoryRoot status --short 2>$null) -join "`n"

$encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.IO.StreamWriter]::new($resolvedOutputPath, $false, $encoding)

try {
    $writer.WriteLine("OBSIDIAN SYNC IOS - SOURCE HANDOFF BUNDLE")
    $writer.WriteLine("Generated: $([DateTimeOffset]::Now.ToString('o'))")
    $writer.WriteLine("Repository: $repositoryRoot")
    $writer.WriteLine("Branch: $branch")
    $writer.WriteLine("HEAD: $head")
    $writer.WriteLine("Working tree status:")
    $writer.WriteLine($(if ($status) { $status } else { "clean" }))
    $writer.WriteLine("Files included: $($files.Count)")
    $writer.WriteLine("Markdown, generated/build directories, and binary assets are intentionally excluded.")
    $writer.WriteLine()

    foreach ($file in $files) {
        $relativePath = (Get-RepositoryRelativePath -FullName $file.FullName).Replace('\', '/')
        $writer.WriteLine("================================================================================")
        $writer.WriteLine("FILE: $relativePath")
        $writer.WriteLine("================================================================================")
        $writer.WriteLine([System.IO.File]::ReadAllText($file.FullName))
        $writer.WriteLine()
    }
}
finally {
    $writer.Dispose()
}

Write-Host "Exported $($files.Count) source/configuration files to $resolvedOutputPath"
