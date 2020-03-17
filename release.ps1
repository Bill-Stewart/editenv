#requires -version 3

$SevenZip = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) "7-Zip\7z.exe"
if ( -not (Test-Path $SevenZip) ) {
  throw "File not found - '$SevenZip'"
}

$BinaryPath  = Join-Path $PSScriptRoot "x86\editenv.exe"
if ( -not (Test-Path $BinaryPath) ) {
  throw "File not found - '$BinaryPath'"
}
$VersionInfo = (Get-Item $BinaryPath).VersionInfo

$Version = "{0}.{1}" -f $VersionInfo.FileMajorPart,$VersionInfo.FileMinorPart

$Sources = Get-Content (Join-Path $PSScriptRoot "sources.txt") -ErrorAction Stop

$SourcesDir = Join-Path $PSScriptRoot "source"
if ( -not (Test-Path $SourcesDir) ) {
  New-Item $SourcesDir -ItemType Directory -ErrorAction Stop | Out-Null
}

# clean source dir and put latest files there
Get-ChildItem $SourcesDir | Remove-Item
$Sources | ForEach-Object {
  Get-Item (Join-Path $PSScriptRoot $_) | Copy-Item -Destination $SourcesDir
}

$ListName = [IO.Path]::GetTempFileName()

$Sources | ForEach-Object {
  "source\{0}" -f $_
} | Out-File $ListName -Encoding utf8

@(
  "x64\editenv.exe"
  "x86\editenv.exe"
  "LICENSE"
  "README.md"
) | Out-File $ListName -Append -Encoding utf8

$ZipName = Join-Path $PSScriptRoot ("editenv-{0}.zip" -f $Version)
if ( Test-Path $ZipName ) { Remove-Item $ZipName }

Push-Location $PSScriptRoot
& $SevenZip a -bb1 -stl ("-i@{0}" -f $ListName) -mx=7 $ZipName
Pop-Location

Remove-Item $ListName
