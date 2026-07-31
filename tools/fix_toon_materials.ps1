param([switch]$DryRun)

$textureDir = "D:\_DimitriGame\3d-printing-simulator\addons\Toon\Toon City\Textures"
$modelsDir  = "D:\_DimitriGame\3d-printing-simulator\addons\Toon\Toon City\Models"
$resTexPath = "res://addons/Toon/Toon City/Textures/"

# Build map: texture basename -> uid
$uidMap = @{}
Get-ChildItem $textureDir -Filter "*.png.import" | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    if ($c -match 'uid="(uid://[^"]+)"') {
        $uidMap[($_.Name -replace '\.png\.import$', '')] = $Matches[1]
    }
}
Write-Host "Loaded $($uidMap.Count) texture UIDs"

$files = Get-ChildItem $modelsDir -Filter "*.tscn" -Recurse
$processed = 0; $skipped = 0; $noMatch = 0

foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($content -match 'albedo_texture') { $skipped++; continue }

    # Collect unique resource_names in this file that have matching textures
    $resNames = [regex]::Matches($content, 'resource_name = "([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $uidMap.ContainsKey($_) } |
        Select-Object -Unique

    if ($resNames.Count -eq 0) { $noMatch++; continue }

    $newContent = $content

    # Build ext_resource block to insert (one per unique texture)
    $extBlock = ""
    $idMap = @{}  # resName -> ext id
    $counter = 1
    foreach ($rn in $resNames) {
        $eid = "tx_$counter"
        $idMap[$rn] = $eid
        $texUid = $uidMap[$rn]
        $extBlock += "[ext_resource type=`"Texture2D`" uid=`"$texUid`" path=`"${resTexPath}${rn}.png`" id=`"$eid`"]`n"
        $counter++
    }

    # Insert ext_resource block after the [gd_scene ...] line
    $newContent = $newContent -replace '(\[gd_scene[^\n]*\n)', "`$1`n$extBlock"

    # For each resource_name, inject albedo_texture after its line
    foreach ($rn in $resNames) {
        $eid = $idMap[$rn]
        # Insert after the resource_name line
        $escaped = [regex]::Escape("resource_name = `"$rn`"")
        $newContent = $newContent -replace "($escaped\r?\n)", "`$1albedo_texture = ExtResource(`"$eid`")`n"
    }

    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($f.FullName, $newContent, [System.Text.UTF8Encoding]::new($false))
    }
    $processed++
    if ($processed % 50 -eq 0) { Write-Host "  Processed $processed files..." }
}

Write-Host ""
Write-Host "Done. Processed: $processed  Skipped (already had texture): $skipped  No texture match: $noMatch"
