$base    = "D:\_DimitriGame\3d-printing-simulator"
$modDir  = "$base\addons\Toon\Toon City\Models"
$outFile = "$base\demo_map.tscn"
$res     = "res://addons/Toon/Toon City/Models"
$LF      = [char]10

function Get-UID($path) {
    if (-not (Test-Path $path)) { return $null }
    $line = Get-Content $path -TotalCount 1
    if ($line -match 'uid="(uid://[^"]+)"') { return $Matches[1] }
    return $null
}

# Each entry: Name, filename (in Models\), X, Y, Z
$list = @(
    # Row 1: Buildings (Z=0)
    "Building_1A","Building_1A.tscn",-150,0,0
    "Building_2A","Building_2A.tscn",-100,0,0
    "Building_3A","Building_3A.tscn",-50,0,0
    "Building_4A","Building_4A.tscn",0,0,0
    "Building_5A","Building_5A.tscn",50,0,0
    "Building_6A","Building_6A.tscn",100,0,0
    "Building_7A","Building_7A.tscn",150,0,0
    # Roof items near Row 1 (Z=-25)
    "Air_Conditioner_1A","Air_Conditioner_1A.tscn",-162,0,-25
    "Air_Conditioner_2A","Air_Conditioner_2A.tscn",-148,0,-25
    "Air_Vent_1A","Air_Vent_1A.tscn",-110,0,-25
    "Air_Vent_2A","Air_Vent_2A.tscn",-100,0,-25
    "Antenna_1A","Antenna_1A.tscn",-60,0,-25
    "Antenna_2A","Antenna_2A.tscn",-48,0,-25
    "Water_Tank_1A","Water_Tank_1A.tscn",-10,0,-25
    "Water_Tank_1B","Water_Tank_1B.tscn",5,0,-25
    "Solar_Panels_1A","Solar_Panels_1A.tscn",40,0,-25
    "Skylight_1A","Skylight_1A.tscn",90,0,-25
    "Skylight_1B","Skylight_1B.tscn",102,0,-25
    "Industrial_Ventilation_1A","Industrial_Ventilation_1A.tscn",140,0,-25
    # Row 2: Buildings + emergency gear (Z=80)
    "Building_8A","Building_8A.tscn",-160,0,80
    "Building_9A","Building_9A.tscn",-110,0,80
    "Building_10A","Building_10A.tscn",-60,0,80
    "Building_11A","Building_11A.tscn",-10,0,80
    "Building_12A","Building_12A.tscn",40,0,80
    "Building_13A","Building_13A.tscn",90,0,80
    "Building_14A","Building_14A.tscn",140,0,80
    "Emergency_Staircase_1A","Emergency_Staircase_1A.tscn",-168,0,93
    "Emergency_Stairs_1A","Emergency_Stairs_1A.tscn",-118,0,93
    "Scaffolding_1A","Scaffolding_1A.tscn",-68,0,93
    "Window_Washer_1A","Window_Washer_1A.tscn",-18,0,93
    # Row 3: Skyscrapers (Z=170)
    "Skyscraper_1A","Skyscraper_1A.tscn",-120,0,170
    "Skyscraper_1B","Skyscraper_1B.tscn",-70,0,170
    "Skyscraper_2A","Skyscraper_2A.tscn",-20,0,170
    "Skyscraper_2B","Skyscraper_2B.tscn",30,0,170
    "Building_20A","Building_20A.tscn",90,0,170
    "Building_21A","Building_21A.tscn",140,0,170
    "Helipad_1A","Helipad_1A.tscn",-128,0,158
    "Helipad_1B","Helipad_1B.tscn",-116,0,158
    # Aerial above skyscrapers (Y=80)
    "Cloud_1A","Cloud_1A.tscn",-80,80,170
    "Cloud_1B","Cloud_1B.tscn",0,80,170
    "News_Helicopter_1A","News_Helicopter_1A.tscn",60,80,170
    "Service_Helicopter_1A","Service_Helicopter_1A.tscn",110,80,170
    # Row 4: Cars (Z=260)
    "Car_2D","Car_2D.tscn",-170,0,260
    "Car_3B","Car_3B.tscn",-148,0,260
    "Car_6D","Car_6D.tscn",-126,0,260
    "Car_7D","Car_7D.tscn",-104,0,260
    "Car_7F","Car_7F.tscn",-82,0,260
    "Car_8D","Car_8D.tscn",-60,0,260
    "Car_9A","Car_9A.tscn",-38,0,260
    "Car_10C","Car_10C.tscn",-16,0,260
    "Car_11A","Car_11A.tscn",6,0,260
    "Car_14C","Car_14C.tscn",28,0,260
    "Car_16A","Car_16A.tscn",50,0,260
    "Car_17A","Car_17A.tscn",72,0,260
    # Row 5: Trees (Z=350)
    "Tree_1A","Tree_1A.tscn",-140,0,350
    "Tree_1C","Tree_1C.tscn",-125,0,350
    "Tree_1E","Tree_1E.tscn",-110,0,350
    "Tree_2A","Tree_2A.tscn",-90,0,350
    "Tree_2C","Tree_2C.tscn",-75,0,350
    "Tree_2E","Tree_2E.tscn",-60,0,350
    "Tree_3A","Tree_3A.tscn",-40,0,350
    "Tree_3B","Tree_3B.tscn",-25,0,350
    "Tree_4A","Tree_4A.tscn",-10,0,350
    "Tree_4B","Tree_4B.tscn",5,0,350
    "Bush_1A","Bush_1A.tscn",25,0,350
    "Bush_2A","Bush_2A.tscn",37,0,350
    "Bush_3A","Bush_3A.tscn",49,0,350
    "Flower_1A","Flower_1A.tscn",62,0,350
    "Flower_2A","Flower_2A.tscn",74,0,350
    "Grass_Patch_1A","Grass_Patch_1A.tscn",88,0,350
    "Rock_Cluster_2A","Rock_Cluster_2A.tscn",103,0,350
    "Rock_Cluster_2B","Rock_Cluster_2B.tscn",118,0,350
    # Row 6: Billboards (Z=430)
    "Billboard_1A","Billboard_1A.tscn",-120,0,430
    "Billboard_1B","Billboard_1B.tscn",-80,0,430
    "Billboard_2A","Billboard_2A.tscn",-35,0,430
    "Billboard_3A","Billboard_3A.tscn",10,0,430
    "Billboard_3B","Billboard_3B.tscn",50,0,430
    "Billboard_5A","Billboard_5A.tscn",90,0,430
    # Row 7: Roads + street (Z=510)
    "Road_1A","Road_1A.tscn",-150,0,510
    "Road_1B","Road_1B.tscn",-120,0,510
    "Road_1C","Road_1C.tscn",-90,0,510
    "Road_2A","Road_2A.tscn",-60,0,510
    "Road_3A","Road_3A.tscn",-30,0,510
    "Streetlight_1A","Streetlight_1A.tscn",-155,0,500
    "Streetlight_2A","Streetlight_2A.tscn",-125,0,500
    "Streetlight_3A","Streetlight_3A.tscn",-95,0,500
    "Highway_Streetlight_1A","Highway_Streetlight_1A.tscn",-65,0,500
    "Streetsign_1A","Streetsign_1A.tscn",5,0,510
    "Streetsign_2A","Streetsign_2A.tscn",20,0,510
    "Highway_Streetsign_1A","Highway_Streetsign_1A.tscn",35,0,510
    "Bench_1A","Bench_1A.tscn",55,0,510
    "Bench_2A","Bench_2A.tscn",67,0,510
    "Mailbox_1A","Mailbox_1A.tscn",80,0,510
    "Mailbox_2A","Mailbox_2A.tscn",90,0,510
    "Hydrant_1A","Hydrant_1A.tscn",103,0,510
    "Parking_Meter_1A","Parking_Meter_1A.tscn",114,0,510
    "Traffic_Cone_1A","Traffic_Cone_1A.tscn",126,0,510
    "Traffic_Cone_2A","Traffic_Cone_2A.tscn",136,0,510
    "Manhole_1A","Manhole_1A.tscn",148,0,510
    "Toll_Booth_1A","Toll_Booth_1A.tscn",165,0,510
    # Row 8: Props (Z=590)
    "Barrel_1A","Barrel_1A.tscn",-160,0,590
    "Barrel_1B","Barrel_1B.tscn",-150,0,590
    "Barrel_1C","Barrel_1C.tscn",-140,0,590
    "Barrel_2A","Barrel_2A.tscn",-128,0,590
    "Paper_Pack_1A","Paper_Pack_1A.tscn",-110,0,590
    "Paper_Pack_2A","Paper_Pack_2A.tscn",-98,0,590
    "Wooden_Box_1A","Wooden_Box_1A.tscn",-82,0,590
    "Wooden_Pallet_1A","Wooden_Pallet_1A.tscn",-68,0,590
    "Trash_Bag_1A","Trash_Bag_1A.tscn",-55,0,590
    "Trash_Bag_2A","Trash_Bag_2A.tscn",-45,0,590
    "Trash_Can_1A","Trash_Can_1A.tscn",-32,0,590
    "Trash_Can_1B","Trash_Can_1B.tscn",-22,0,590
    "Trash_Container_1A","Trash_Container_1A.tscn",-5,0,590
    "Power_Box_1A","Power_Box_1A.tscn",15,0,590
    "Power_Box_1B","Power_Box_1B.tscn",27,0,590
    "Plant_Pot_1A","Plant_Pot_1A.tscn",42,0,590
    "Plant_Pot_2A","Plant_Pot_2A.tscn",54,0,590
    "Table_1A","Table_1A.tscn",68,0,590
    "Chair_1A","Chair_1A.tscn",80,0,590
    "Umbrella_1A","Umbrella_1A.tscn",95,0,590
    "Umbrella_2A","Umbrella_2A.tscn",109,0,590
    "Light_Projector_1A","Light_Projector_1A.tscn",125,0,590
    # Row 9: Pipes, poles, fences, barriers (Z=670)
    "Pipe_1A","Pipe_1A.tscn",-160,0,670
    "Pipe_1B","Pipe_1B.tscn",-148,0,670
    "Pipe_2A","Pipe_2A.tscn",-136,0,670
    "Pipe_3A","Pipe_3A.tscn",-124,0,670
    "Pipe_Support_1A","Pipe_Support_1A.tscn",-110,0,670
    "Cable_Pole_1A","Cable_Pole_1A.tscn",-90,0,670
    "Cable_Pole_1B","Cable_Pole_1B.tscn",-72,0,670
    "Cable_1A","Cable_1A.tscn",-54,0,670
    "Concrete_Fence_1A","Concrete_Fence_1A.tscn",-35,0,670
    "Concrete_Fence_1B","Concrete_Fence_1B.tscn",-20,0,670
    "Concrete_Barrier_1A","Concrete_Barrier_1A.tscn",-5,0,670
    "Concrete_Barrier_2A","Concrete_Barrier_2A.tscn",12,0,670
    "Concrete_Pole_1A","Concrete_Pole_1A.tscn",30,0,670
    "Safety_Net_1A","Safety_Net_1A.tscn",50,0,670
    "Highway_Fence_1A","Highway_Fence_1A.tscn",70,0,670
    "Highway_Barrier_1A","Highway_Barrier_1A.tscn",90,0,670
    # Row 10: Pavement + parking (Z=750)
    "Pavement_1A_4x4","Pavement_1A_4x4.tscn",-80,0,750
    "Pavement_1B_4x4","Pavement_1B_4x4.tscn",-55,0,750
    "Pavement_1C_4x4","Pavement_1C_4x4.tscn",-30,0,750
    "Pavement_1D_4x4","Pavement_1D_4x4.tscn",-5,0,750
    "Pavement_1E_4x4","Pavement_1E_4x4.tscn",20,0,750
    "Pavement_Special_1A_12X12","Pavement_Special_1A_12X12.tscn",60,0,750
    "Parking_1A","Parking_1A.tscn",105,0,750
    "Parking_2A","Parking_2A.tscn",140,0,750
)

# Parse flat list into structured entries (groups of 5)
$entries = @()
for ($i = 0; $i -lt $list.Count; $i += 5) {
    $entries += [PSCustomObject]@{
        Name = $list[$i]
        File = $list[$i+1]
        X    = [int]$list[$i+2]
        Y    = [int]$list[$i+3]
        Z    = [int]$list[$i+4]
    }
}

$extLines  = [System.Collections.Generic.List[string]]::new()
$nodeLines = [System.Collections.Generic.List[string]]::new()
$idMap     = @{}
$counter   = 1

foreach ($e in $entries) {
    $path = "$modDir\$($e.File)"
    $uid  = Get-UID $path
    if ($uid -eq $null) {
        Write-Warning "Not found: $path"
        continue
    }
    $eid = "a$counter"; $counter++
    $idMap[$e.Name] = $eid
    $rpath = "$res/$($e.File)"
    $extLines.Add('[ext_resource type="PackedScene" uid="' + $uid + '" path="' + $rpath + '" id="' + $eid + '"]')
}

foreach ($e in $entries) {
    if (-not $idMap.ContainsKey($e.Name)) { continue }
    $eid = $idMap[$e.Name]
    $nodeLines.Add('')
    $nodeLines.Add('[node name="' + $e.Name + '" parent="." instance=ExtResource("' + $eid + '")]')
    $nodeLines.Add('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, ' + $e.X + ', ' + $e.Y + ', ' + $e.Z + ')')
}

$out = [System.Collections.Generic.List[string]]::new()
$out.Add('[gd_scene format=4 uid="uid://b7waij0urmpen"]')
$out.Add('')
foreach ($l in $extLines) { $out.Add($l) }
$out.Add('')
$out.Add('[node name="Demo_Map" type="Node3D"]')
foreach ($l in $nodeLines) { $out.Add($l) }

[System.IO.File]::WriteAllText($outFile, [string]::Join([string][char]10, $out), [System.Text.UTF8Encoding]::new($false))
Write-Host "Done. Assets: $($entries.Count)  Written: $($idMap.Count)  Output: $outFile"
