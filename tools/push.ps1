# Pousse le dossier du projet sur main via l'API GitHub (git n'est pas installé).
param([string]$Message, [string]$Root = "C:\Users\Administrator\Documents\Ippitsu", [string]$Repo = "vroux18/ippitsu")
$ErrorActionPreference = "Stop"
$exclude = '^(\.godot|build)[\\/]|^HANDOFF\.md$|\.import$'

function Api($method, $path, $body) {
  $tmp = [IO.Path]::GetTempFileName()
  [IO.File]::WriteAllText($tmp, ($body | ConvertTo-Json -Depth 10 -Compress), (New-Object Text.UTF8Encoding $false))
  $out = gh api -X $method $path --input $tmp
  Remove-Item $tmp
  if ($LASTEXITCODE -ne 0) { throw "gh api $method $path failed" }
  return $out | ConvertFrom-Json
}

$head = $null
try { $head = (gh api "repos/$Repo/git/ref/heads/main" 2>$null | ConvertFrom-Json).object.sha } catch {}
if (-not $head) {
  # dépôt vide : un premier fichier crée la branche main
  $readme = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$Root\README.md"))
  Api PUT "repos/$Repo/contents/README.md" @{ message = "Initial commit"; content = $readme; branch = "main" } | Out-Null
  $head = (gh api "repos/$Repo/git/ref/heads/main" | ConvertFrom-Json).object.sha
}
$baseTree = (gh api "repos/$Repo/git/commits/$head" | ConvertFrom-Json).tree.sha

$files = Get-ChildItem -Path $Root -Recurse -File -Force | ForEach-Object {
  $_.FullName.Substring($Root.Length + 1)
} | Where-Object { $_ -notmatch $exclude }

$tree = @()
foreach ($f in $files) {
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$Root\$f"))
  $blob = Api POST "repos/$Repo/git/blobs" @{ content = $b64; encoding = "base64" }
  $tree += @{ path = ($f -replace '\\', '/'); mode = "100644"; type = "blob"; sha = $blob.sha }
}
# fichiers supprimés localement : on les retire aussi du dépôt
$local = @{}; foreach ($f in $files) { $local[($f -replace '\\', '/')] = $true }
$remote = (gh api "repos/$Repo/git/trees/$baseTree`?recursive=1" | ConvertFrom-Json).tree | Where-Object { $_.type -eq 'blob' }
foreach ($r in $remote) {
  if (-not $local.ContainsKey($r.path) -and ($r.path -replace '/', '\') -notmatch $exclude) {
    $tree += @{ path = $r.path; mode = "100644"; type = "blob"; sha = $null }
  }
}
$newTree = Api POST "repos/$Repo/git/trees" @{ base_tree = $baseTree; tree = $tree }
$commit = Api POST "repos/$Repo/git/commits" @{ message = $Message; tree = $newTree.sha; parents = @($head) }
Api PATCH "repos/$Repo/git/refs/heads/main" @{ sha = $commit.sha } | Out-Null
"pushed $($commit.sha) ($($files.Count) files)"
