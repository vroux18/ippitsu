# Regenere scripts/ui_icons.gd a partir des SVG de ui/icons (handoff UI v2).
# Les SVG sont embarques en texte dans le script : UiKit.icon() les rasterise a la taille voulue
# (nette a tout u, recolorable), sans dependre de l'import Godot ni du filtre d'export.
# Usage : powershell -File tools/gen_ui_icons.ps1
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$ErrorActionPreference = "Stop"
$src = Join-Path $Root "ui\icons"
$out = Join-Path $Root "scripts\ui_icons.gd"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("extends RefCounted")
$lines.Add("## Sources SVG des pictogrammes de l'interface (copie de res://ui/icons), generees par tools/gen_ui_icons.ps1 :")
$lines.Add("## ne pas modifier a la main. UiKit.icon(""elements/feu"", px) les rasterise a la taille voulue (cache).")
$lines.Add("")
$lines.Add("const SVG := {")
Get-ChildItem -Path $src -Recurse -Filter *.svg | Sort-Object FullName | ForEach-Object {
  $key = $_.FullName.Substring($src.Length + 1).Replace("\", "/") -replace '\.svg$', ''
  $txt = [IO.File]::ReadAllText($_.FullName) -replace "\r?\n", " "
  $txt = $txt.Trim()
  if ($txt.Contains("'") -or $txt.Contains("\")) { throw "caractere interdit dans $key" }
  $lines.Add("`t""$key"": '$txt',")
}
$lines.Add("}")
[IO.File]::WriteAllText($out, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
Write-Output "ecrit $out"
