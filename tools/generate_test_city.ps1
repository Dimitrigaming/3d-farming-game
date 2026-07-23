$base    = "D:\_DimitriGame\3d-printing-simulator"
$modDir  = "$base\addons\Toon\Toon City\Models"
$outFile = "$base\test_city.tscn"
$res     = "res://addons/Toon/Toon City/Models"
$LF      = [char]10

function Get-UID($path) {
    if (-not (Test-Path $path)) { return $null }
    $line = Get-Content $path -TotalCount 1
    if ($line -match 'uid="(uid://[^"]+)"') { return $Matches[1] }
    return $null
}

# Each entry: DisplayName, RelativePath (from Models\), X, Y, Z
$list = @(
    # ── MAIN STREET (Road_1A tiles running east-west along Z=0) ──────────────
    "MainRd_1","Road_1A.tscn",-90,0,0
    "MainRd_2","Road_1A.tscn",-60,0,0
    "MainRd_3","Road_1A.tscn",-30,0,0
    "MainRd_4","Road_1A.tscn",0,0,0
    "MainRd_5","Road_1A.tscn",30,0,0
    "MainRd_6","Road_1A.tscn",60,0,0
    "MainRd_7","Road_1A.tscn",90,0,0
    # Roundabout at east end of main street
    "Roundabout","Roundabout_1A.tscn",120,0,0

    # ── NORTH COMMERCIAL BUILDINGS (Z=-50) ───────────────────────────────────
    "Bldg_N1","Building_1A.tscn",-80,0,-50
    "Bldg_N2","Building_2A.tscn",-45,0,-50
    "Bldg_N3","Building_3A.tscn",-10,0,-50
    "Bldg_N4","Building_4A.tscn",25,0,-50
    "Bldg_N5","Building_5A.tscn",65,0,-50

    # ── SOUTH COMMERCIAL BUILDINGS (Z=50) ────────────────────────────────────
    "Bldg_S1","Building_6A.tscn",-80,0,50
    "Bldg_S2","Building_7A.tscn",-45,0,50
    "Bldg_S3","Building_8A.tscn",-10,0,50
    "Bldg_S4","Building_9A.tscn",25,0,50
    "Bldg_S5","Building_10A.tscn",65,0,50

    # ── EAST-END BUILDINGS (flanking roundabout) ─────────────────────────────
    "Bldg_E1","Building_11A.tscn",120,0,-55
    "Bldg_E2","Building_12A.tscn",120,0,55

    # ── WEST-END ANCHOR BUILDING (backs the residential block) ───────────────
    "Bldg_W","Building_2B.tscn",-165,0,-115

    # ── BROWNSTONE RESIDENTIAL BLOCK (X=-165, running north-south) ───────────
    "Brown_1","Update\Brownstone_1A.tscn",-165,0,-75
    "Brown_2","Update\Brownstone_2A.tscn",-165,0,-40
    "Brown_3","Update\Brownstone_3A.tscn",-165,0,-5
    "Brown_4","Update\Brownstone_4A.tscn",-165,0,30
    "Brown_5","Update\Brownstone_5A.tscn",-165,0,65

    # ── TOWN SQUARE / PARK (northwest, around X=-110, Z=-110) ────────────────
    "PlazaPave","Pavement_Special_1A_12X12.tscn",-110,0,-110
    "Fountain","Update\Fountain_1A.tscn",-110,0,-110
    "Statue_A","Update\Statue_3A.tscn",-128,0,-98
    "Statue_B","Update\Statue_3B.tscn",-92,0,-98
    "Statue_C","Update\Statue_1B.tscn",-110,0,-128
    "ParkBench1","Bench_1A.tscn",-125,0,-122
    "ParkBench2","Bench_2A.tscn",-95,0,-122
    "ParkBench3","Update\Bench_1C.tscn",-122,0,-95
    "BikeStand","Update\Bicycle_Stand_1A.tscn",-95,0,-130
    "ParkFlwr1","Flower_1A.tscn",-118,0,-98
    "ParkFlwr2","Flower_2A.tscn",-102,0,-98
    "ParkFlwr3","Flower_1B.tscn",-125,0,-115
    "ParkFlwr4","Flower_2B.tscn",-95,0,-115
    "ParkGrass1","Grass_Patch_1A.tscn",-130,0,-108
    "ParkGrass2","Grass_Patch_1B.tscn",-90,0,-108
    "ParkBush1","Bush_1A.tscn",-140,0,-100
    "ParkBush2","Bush_2A.tscn",-80,0,-100
    "ParkBush3","Bush_1B.tscn",-140,0,-120
    "ParkBush4","Bush_2B.tscn",-80,0,-120
    "ParkTree1","Tree_1A.tscn",-148,0,-92
    "ParkTree2","Tree_1C.tscn",-148,0,-128
    "ParkTree3","Tree_1E.tscn",-72,0,-92
    "ParkTree4","Tree_1G.tscn",-72,0,-128
    "ParkTree5","Tree_2A.tscn",-148,0,-110
    "ParkTree6","Tree_2C.tscn",-72,0,-110
    "ParkTree7","Update\Tree_5A.tscn",-120,0,-148
    "ParkTree8","Update\Tree_5C.tscn",-100,0,-148
    "ParkRock1","Rock_Cluster_2A.tscn",-140,0,-138
    "ParkRock2","Rock_Cluster_2B.tscn",-80,0,-138
    "ParkPlant","Plant_Pot_2A.tscn",-110,0,-95
    # Scooters parked at park entrance
    "Scoot_1","Update\Scooter_1A.tscn",-90,0,-80
    "Scoot_2","Update\Scooter_1B.tscn",-78,0,-80
    "Scoot_3","Update\Scooter_1C.tscn",-66,0,-80

    # ── STREETLIGHTS - North sidewalk (Z=-15) ────────────────────────────────
    "SL_N1","Streetlight_1A.tscn",-80,0,-15
    "SL_N2","Streetlight_2A.tscn",-50,0,-15
    "SL_N3","Streetlight_3A.tscn",-20,0,-15
    "SL_N4","Streetlight_2A.tscn",10,0,-15
    "SL_N5","Streetlight_1A.tscn",40,0,-15
    "SL_N6","Streetlight_3A.tscn",70,0,-15
    "SL_N7","Streetlight_2A.tscn",100,0,-15
    # South sidewalk (Z=15)
    "SL_S1","Streetlight_2A.tscn",-65,0,15
    "SL_S2","Streetlight_1A.tscn",-35,0,15
    "SL_S3","Streetlight_3A.tscn",-5,0,15
    "SL_S4","Streetlight_2A.tscn",25,0,15
    "SL_S5","Streetlight_1A.tscn",55,0,15
    "SL_S6","Streetlight_3A.tscn",85,0,15

    # ── STREET SIGNS ─────────────────────────────────────────────────────────
    "Sign_W","Streetsign_1A.tscn",-88,0,-12
    "Sign_E","Streetsign_2A.tscn",112,0,-12
    "Sign_C","Streetsign_1B.tscn",0,0,12

    # ── NORTH SIDEWALK PROPS (Z=-22) ─────────────────────────────────────────
    "Bench_N1","Bench_1A.tscn",-60,0,-22
    "Bench_N2","Bench_2A.tscn",10,0,-22
    "Mailbox_N","Mailbox_1A.tscn",35,0,-22
    "Hydrant_N","Hydrant_1A.tscn",-30,0,-22
    "Trash_N1","Trash_Can_1A.tscn",65,0,-22
    "PlantN1","Plant_Pot_1A.tscn",-92,0,-22
    "PlantN2","Plant_Pot_2A.tscn",92,0,-22
    "ParkMeter","Parking_Meter_1A.tscn",-5,0,-22
    "Cone_N","Traffic_Cone_1A.tscn",82,0,-22
    # South sidewalk (Z=22)
    "Bench_S1","Bench_1A.tscn",-45,0,22
    "Bench_S2","Bench_2A.tscn",20,0,22
    "Mailbox_S","Mailbox_2A.tscn",-72,0,22
    "Hydrant_S","Hydrant_1B.tscn",55,0,22
    "Trash_S1","Trash_Can_1B.tscn",78,0,22
    "PwrBox1","Power_Box_1A.tscn",-90,0,22
    "PwrBox2","Power_Box_1B.tscn",112,0,22

    # ── BARBER SHOP (in front of Bldg_N3) ────────────────────────────────────
    "BarberCyl","Update\Barber_Cylinder_1A.tscn",-10,0,-25
    "BarberTxt","Update\Barber_Text_1A.tscn",-10,0,-38

    # ── OUTDOOR CAFÉ (in front of Bldg_S1 south side) ────────────────────────
    "CafeTable1","Table_1A.tscn",-82,0,26
    "CafeTable2","Table_1B.tscn",-70,0,26
    "CafeChair","Chair_1A.tscn",-82,0,30
    "CafeUmb1","Umbrella_1A.tscn",-82,0,26
    "CafeUmb2","Umbrella_2A.tscn",-70,0,26

    # ── PARKED CARS - North side (Z=-20) ─────────────────────────────────────
    "Car_N1","Car_2D.tscn",-72,0,-20
    "Car_N2","Car_3B.tscn",-38,0,-20
    "Car_N3","Car_6D.tscn",5,0,-20
    "Car_N4","Car_7D.tscn",48,0,-20
    "Car_N5","Car_9A.tscn",82,0,-20
    # South side (Z=20)
    "Car_S1","Car_10C.tscn",-58,0,20
    "Car_S2","Car_11A.tscn",-18,0,20
    "Car_S3","Car_16A.tscn",28,0,20
    "Car_S4","Car_17A.tscn",68,0,20
    # Residential cars near brownstones
    "Car_R1","Car_4D.tscn",-148,0,-60
    "Car_R2","Car_15B.tscn",-148,0,20

    # ── UTILITY POLES (north side, backing the streetlights) ─────────────────
    "Pole_1","Cable_Pole_1A.tscn",-88,0,-8
    "Pole_2","Cable_Pole_1B.tscn",-38,0,-8
    "Pole_3","Cable_Pole_1C.tscn",18,0,-8

    # ── BACK ALLEY (north of buildings, Z=-68) ───────────────────────────────
    "AlleyTr1","Trash_Container_1A.tscn",15,0,-68
    "AlleyTr2","Trash_Container_2A.tscn",32,0,-68
    "AlleyBrl1","Barrel_1A.tscn",-15,0,-68
    "AlleyBrl2","Barrel_1B.tscn",-25,0,-68
    "AlleyBox","Wooden_Box_1A.tscn",48,0,-68
    "AlleyPlt","Wooden_Pallet_1A.tscn",62,0,-68
    "AlleyBag","Trash_Bag_1A.tscn",-5,0,-68

    # ── CONSTRUCTION ZONE (east end, beside Bldg_E1) ─────────────────────────
    "Scaffold","Scaffolding_1A.tscn",108,0,-50
    "EmStairs","Emergency_Stairs_1A.tscn",98,0,-50
    "CBarrier","Concrete_Barrier_1A.tscn",98,0,-22
    "Cone_C1","Traffic_Cone_2A.tscn",90,0,-22
    "Cone_C2","Traffic_Cone_2A.tscn",94,0,-22

    # ── TREES LINING MAIN STREET CORNERS ─────────────────────────────────────
    "TreeNW","Tree_3A.tscn",-95,0,-38
    "TreeNE","Tree_4A.tscn",108,0,-38
    "TreeSW","Tree_3B.tscn",-95,0,38
    "TreeSE","Tree_4B.tscn",108,0,38

    # ── RESIDENTIAL BLOCK GREENERY ────────────────────────────────────────────
    "ResTree1","Update\Tree_5E.tscn",-185,0,-80
    "ResTree2","Update\Tree_5G.tscn",-185,0,-38
    "ResTree3","Update\Tree_5I.tscn",-185,0,4
    "ResTree4","Update\Tree_5K.tscn",-185,0,46
    "ResBush1","Bush_3A.tscn",-180,0,-58
    "ResBush2","Bush_2C.tscn",-180,0,18
    "ResFlwr1","Flower_1C.tscn",-180,0,62

    # ── BILLBOARDS (east end, visible from the street) ────────────────────────
    "BBrd1","Billboard_1A.tscn",130,0,-65
    "BBrd2","Update\Billboard_4A.tscn",130,0,65

    # ── ROAD DETAILS ─────────────────────────────────────────────────────────
    "Manhole","Manhole_1A.tscn",15,0,8
    "Manhole2","Manhole_1B.tscn",-25,0,-8

    # ── EAST PARKING LOT (beside Bldg_E2) ────────────────────────────────────
    "ParkingLot","Parking_1A.tscn",120,0,55

    # ── CONCRETE UTILITY (near poles) ────────────────────────────────────────
    "ConcrPole","Concrete_Pole_1A.tscn",-95,0,-8
)

# ── Build scene ──────────────────────────────────────────────────────────────
$extLines  = [System.Collections.Generic.List[string]]::new()
$nodeLines = [System.Collections.Generic.List[string]]::new()
$idMap     = @{}
$counter   = 1

for ($i = 0; $i -lt $list.Count; $i += 5) {
    $name = $list[$i]
    $file = $list[$i+1]
    $x    = [int]$list[$i+2]
    $y    = [int]$list[$i+3]
    $z    = [int]$list[$i+4]

    $path = "$modDir\$file"
    $uid  = Get-UID $path
    if ($uid -eq $null) {
        Write-Warning "Not found: $path"
        continue
    }
    $eid = "a$counter"; $counter++
    $idMap[$name] = @{ EID = $eid; X = $x; Y = $y; Z = $z }

    $rpath = ($res + "/" + $file).Replace("\", "/")
    $extLines.Add('[ext_resource type="PackedScene" uid="' + $uid + '" path="' + $rpath + '" id="' + $eid + '"]')
}

foreach ($name in $idMap.Keys) {
    $e   = $idMap[$name]
    $eid = $e.EID
    $nodeLines.Add('')
    $nodeLines.Add('[node name="' + $name + '" parent="." instance=ExtResource("' + $eid + '")]')
    $nodeLines.Add('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, ' + $e.X + ', ' + $e.Y + ', ' + $e.Z + ')')
}

$out = [System.Collections.Generic.List[string]]::new()
$out.Add('[gd_scene format=4 uid="uid://d4d7k07nqqes3"]')
$out.Add('')
foreach ($l in $extLines) { $out.Add($l) }
$out.Add('')
$out.Add('[node name="TestCity" type="Node3D"]')
foreach ($l in $nodeLines) { $out.Add($l) }

[System.IO.File]::WriteAllText($outFile, [string]::Join([string][char]10, $out), [System.Text.UTF8Encoding]::new($false))
Write-Host "Done. Assets defined: $(($list.Count/5))  Written: $($idMap.Count)  Output: $outFile"
