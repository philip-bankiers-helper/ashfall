param([switch]$Force)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$url='https://github.com/alingold/ashfall/releases/download/v0.1.0-preview/ASHFALL-Source-Assets.zip'
$expected='05fbf735253d2634d4cda2132c02c74d8f2b76db6b7db3d7dbb734d75a6d4ce6'
$target=Join-Path $root '.'
if((Test-Path -LiteralPath (Join-Path $target 'assets')) -and -not $Force) {throw 'Assets already exist. Use -Force only to replace the ignored asset payload, never project source.'}
$work=Join-Path ([IO.Path]::GetTempPath()) ('ashfall-assets-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
$archive=Join-Path $work 'assets.zip'
Write-Host 'Downloading the pinned release asset pack. This does not launch or install a game.'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
(New-Object Net.WebClient).DownloadFile($url,$archive)
$stream=[IO.File]::OpenRead($archive);$algorithm=[Security.Cryptography.SHA256]::Create()
try {$actual=([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant()} finally {$stream.Dispose();$algorithm.Dispose()}
if($actual -ne $expected) {throw 'Asset ZIP checksum mismatch; not extracted. Download again or report this release.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {foreach($entry in $zip.Entries) {
  $destination=[IO.Path]::GetFullPath((Join-Path $target $entry.FullName))
  if(-not $destination.StartsWith([IO.Path]::GetFullPath($target).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Unsafe ZIP entry.'}
  if($entry.FullName -notlike 'assets/*') {continue}
  if($entry.FullName.EndsWith('/')) {[IO.Directory]::CreateDirectory($destination)|Out-Null;continue}
  [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))|Out-Null
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$Force.IsPresent)
}} finally {$zip.Dispose()}
Write-Host "Assets verified and extracted to $target. Temporary archive: $archive"
