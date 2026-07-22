$base    = "D:\_DimitriGame\3d-printing-simulator"
$modDir  = "$base\addons\Toon\Toon City\Models"
$updDir  = "$modDir\Update"
$outFile = "$base\demo_map.tscn"
$res     = "res://addons/Toon/Toon City/Models"
$resUpd  = "res://addons/Toon/Toon City/Models/Update"
$LF      = [char]10

function Get-UID($path) {
    if (-not (Test-Path $path)) { return $null }
    $line = Get-Content $path -TotalCount 1
    if ($line -match 'uid="(uid://[^"]+)"') { return $Matches[1] }
    return $null
}

# Helper: build an entry using the Update subfolder
function U($name, $file, $x, $y, $z) {
    return @($name, "Update\$file", $x, $y, $z)
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
    "Road_3A","Update\Road_3A.tscn",-30,0,510
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
    # Row 11: More buildings B/C/D variants (Z=830)
    "Building_2B","Building_2B.tscn",-280,0,830
    "Building_3B","Building_3B.tscn",-250,0,830
    "Building_4B","Building_4B.tscn",-220,0,830
    "Building_4C","Building_4C.tscn",-190,0,830
    "Building_5B","Building_5B.tscn",-160,0,830
    "Building_5C","Building_5C.tscn",-130,0,830
    "Building_5D","Building_5D.tscn",-100,0,830
    "Building_5E","Building_5E.tscn",-70,0,830
    "Building_9B","Building_9B.tscn",-40,0,830
    "Building_9C","Building_9C.tscn",-10,0,830
    "Building_10B","Building_10B.tscn",20,0,830
    "Building_11B","Building_11B.tscn",60,0,830
    "Building_12B","Building_12B.tscn",100,0,830
    "Building_12C","Building_12C.tscn",130,0,830
    "Building_12D","Building_12D.tscn",160,0,830
    "Building_13B","Building_13B.tscn",190,0,830
    "Building_13C","Building_13C.tscn",220,0,830
    "Building_13D","Building_13D.tscn",250,0,830
    "Building_14B","Building_14B.tscn",280,0,830
    "Building_14C","Building_14C.tscn",310,0,830
    "Building_14D","Building_14D.tscn",340,0,830
    "Building_15A","Building_15A.tscn",370,0,830
    "Building_15B","Building_15B.tscn",400,0,830
    "Building_16A","Building_16A.tscn",430,0,830
    "Building_16B","Building_16B.tscn",460,0,830
    "Building_16C","Building_16C.tscn",490,0,830
    "Building_17A","Building_17A.tscn",520,0,830
    "Building_17B","Building_17B.tscn",560,0,830
    "Building_17C","Building_17C.tscn",600,0,830
    "Building_17D","Building_17D.tscn",640,0,830
    "Building_19A","Building_19A.tscn",680,0,830
    "Building_19B","Building_19B.tscn",720,0,830
    "Building_19C","Building_19C.tscn",760,0,830
    "Building_20B","Building_20B.tscn",800,0,830
    "Building_20C","Building_20C.tscn",840,0,830
    "Building_21B","Building_21B.tscn",880,0,830
    "Building_21C","Building_21C.tscn",920,0,830
    "Building_22A","Building_22A.tscn",960,0,830
    # Row 12: Brownstones + Building 18 (Update folder) + Air_Conditioner_3A (Z=910)
    "Air_Conditioner_3A","Air_Conditioner_3A.tscn",-160,0,910
    "Air_Vent_3A","Air_Vent_3A.tscn",-145,0,910
    "Air_Vent_3B","Air_Vent_3B.tscn",-132,0,910
    "Air_Vent_3C","Air_Vent_3C.tscn",-119,0,910
    "Antenna_1B","Antenna_1B.tscn",-105,0,910
    "Antenna_1C","Antenna_1C.tscn",-92,0,910
    "Antenna_2B","Antenna_2B.tscn",-79,0,910
    "Antenna_3A","Antenna_3A.tscn",-66,0,910
    "Brownstone_1A","Update\Brownstone_1A.tscn",-40,0,910
    "Brownstone_2A","Update\Brownstone_2A.tscn",5,0,910
    "Brownstone_3A","Update\Brownstone_3A.tscn",50,0,910
    "Brownstone_4A","Update\Brownstone_4A.tscn",95,0,910
    "Brownstone_5A","Update\Brownstone_5A.tscn",140,0,910
    "Building_18A","Update\Building_18A.tscn",185,0,910
    "Building_18B","Update\Building_18B.tscn",230,0,910
    # Scaffolding/stairs B variants near brownstones
    "Emergency_Stairs_1B","Emergency_Stairs_1B.tscn",-38,0,922
    "Scaffolding_1B","Scaffolding_1B.tscn",8,0,922
    # Row 13: Scooters, Statues, Fountain, Barber, Bicycle (Z=990)
    "Scooter_1A","Update\Scooter_1A.tscn",-80,0,990
    "Scooter_1B","Update\Scooter_1B.tscn",-60,0,990
    "Scooter_1C","Update\Scooter_1C.tscn",-40,0,990
    "Scooter_1D","Update\Scooter_1D.tscn",-20,0,990
    "Bicycle_Stand_1A","Update\Bicycle_Stand_1A.tscn",0,0,990
    "Statue_1B","Update\Statue_1B.tscn",25,0,990
    "Statue_3A","Update\Statue_3A.tscn",55,0,990
    "Statue_3B","Update\Statue_3B.tscn",80,0,990
    "Fountain_1A","Update\Fountain_1A.tscn",110,0,990
    "Barber_Cylinder_1A","Update\Barber_Cylinder_1A.tscn",145,0,990
    "Barber_Text_1A","Update\Barber_Text_1A.tscn",158,0,990
    # Row 14: Remaining Trees 1/2 variants + Tree_5 (Z=1070)
    "Tree_1B","Tree_1B.tscn",-200,0,1070
    "Tree_1D","Tree_1D.tscn",-185,0,1070
    "Tree_1F","Tree_1F.tscn",-170,0,1070
    "Tree_1G","Tree_1G.tscn",-155,0,1070
    "Tree_1H","Tree_1H.tscn",-140,0,1070
    "Tree_1I","Tree_1I.tscn",-125,0,1070
    "Tree_1J","Tree_1J.tscn",-110,0,1070
    "Tree_2B","Tree_2B.tscn",-90,0,1070
    "Tree_2D","Tree_2D.tscn",-75,0,1070
    "Tree_2F","Tree_2F.tscn",-60,0,1070
    "Tree_2G","Tree_2G.tscn",-45,0,1070
    "Tree_2H","Tree_2H.tscn",-30,0,1070
    "Tree_2I","Tree_2I.tscn",-15,0,1070
    "Tree_2J","Tree_2J.tscn",0,0,1070
    "Tree_5A","Update\Tree_5A.tscn",25,0,1070
    "Tree_5B","Update\Tree_5B.tscn",40,0,1070
    "Tree_5C","Update\Tree_5C.tscn",55,0,1070
    "Tree_5D","Update\Tree_5D.tscn",70,0,1070
    "Tree_5E","Update\Tree_5E.tscn",85,0,1070
    "Tree_5F","Update\Tree_5F.tscn",100,0,1070
    "Tree_5G","Update\Tree_5G.tscn",115,0,1070
    "Tree_5H","Update\Tree_5H.tscn",130,0,1070
    "Tree_5I","Update\Tree_5I.tscn",145,0,1070
    "Tree_5J","Update\Tree_5J.tscn",160,0,1070
    "Tree_5K","Update\Tree_5K.tscn",175,0,1070
    "Tree_5L","Update\Tree_5L.tscn",190,0,1070
    # Row 15: More bushes/flowers/grass/rock (Z=1150)
    "Bush_1B","Bush_1B.tscn",-140,0,1150
    "Bush_2B","Bush_2B.tscn",-128,0,1150
    "Bush_2C","Bush_2C.tscn",-116,0,1150
    "Bush_2D","Bush_2D.tscn",-104,0,1150
    "Bush_3B","Bush_3B.tscn",-92,0,1150
    "Flower_1B","Flower_1B.tscn",-75,0,1150
    "Flower_1C","Flower_1C.tscn",-63,0,1150
    "Flower_1D","Flower_1D.tscn",-51,0,1150
    "Flower_2B","Flower_2B.tscn",-39,0,1150
    "Flower_2C","Flower_2C.tscn",-27,0,1150
    "Flower_2D","Flower_2D.tscn",-15,0,1150
    "Grass_Blade_1A","Grass_Blade_1A.tscn",0,0,1150
    "Grass_Blade_1B","Grass_Blade_1B.tscn",12,0,1150
    "Grass_Patch_1B","Grass_Patch_1B.tscn",27,0,1150
    "Rock_Cluster_2C","Rock_Cluster_2C.tscn",45,0,1150
    # Row 16: Highway pieces (Z=1230)
    "Highway_1A","Highway_1A.tscn",-200,0,1230
    "Highway_1B","Highway_1B.tscn",-170,0,1230
    "Highway_1C","Highway_1C.tscn",-140,0,1230
    "Highway_1D","Highway_1D.tscn",-110,0,1230
    "Highway_1E","Highway_1E.tscn",-80,0,1230
    "Highway_1F","Highway_1F.tscn",-50,0,1230
    "Highway_1G","Highway_1G.tscn",-20,0,1230
    "Highway_1H","Highway_1H.tscn",10,0,1230
    "Highway_1I","Highway_1I.tscn",40,0,1230
    "Highway_Barrier_1B","Highway_Barrier_1B.tscn",75,0,1230
    "Highway_Barrier_1C","Highway_Barrier_1C.tscn",90,0,1230
    "Highway_Barrier_1D","Highway_Barrier_1D.tscn",105,0,1230
    "Highway_Barrier_1E","Highway_Barrier_1E.tscn",120,0,1230
    "Highway_Barrier_1F","Highway_Barrier_1F.tscn",135,0,1230
    "Highway_Barrier_1G","Highway_Barrier_1G.tscn",150,0,1230
    "Highway_Barrier_1H","Highway_Barrier_1H.tscn",165,0,1230
    "Highway_Barrier_1I","Highway_Barrier_1I.tscn",180,0,1230
    "Highway_Streetsign_1B","Highway_Streetsign_1B.tscn",200,0,1230
    "Highway_Streetsign_1C","Highway_Streetsign_1C.tscn",215,0,1230
    # Row 17: Remaining road pieces (Z=1310)
    "Road_1D","Road_1D.tscn",-300,0,1310
    "Road_1E","Road_1E.tscn",-270,0,1310
    "Road_1F","Road_1F.tscn",-240,0,1310
    "Road_1G","Road_1G.tscn",-210,0,1310
    "Road_1H","Road_1H.tscn",-180,0,1310
    "Road_1I","Road_1I.tscn",-150,0,1310
    "Road_1J","Road_1J.tscn",-120,0,1310
    "Road_1K","Road_1K.tscn",-90,0,1310
    "Road_1L","Road_1L.tscn",-60,0,1310
    "Road_1M","Road_1M.tscn",-30,0,1310
    "Road_1N","Road_1N.tscn",0,0,1310
    "Road_1O","Road_1O.tscn",30,0,1310
    "Road_1P","Road_1P.tscn",60,0,1310
    "Road_1Q","Road_1Q.tscn",90,0,1310
    "Road_1R","Road_1R.tscn",120,0,1310
    "Road_1S","Road_1S.tscn",150,0,1310
    "Road_1T","Road_1T.tscn",180,0,1310
    "Road_1U","Road_1U.tscn",210,0,1310
    "Road_1V","Road_1V.tscn",240,0,1310
    "Road_1X","Road_1X.tscn",270,0,1310
    "Road_1Y","Road_1Y.tscn",300,0,1310
    "Road_2B","Road_2B.tscn",330,0,1310
    "Road_2C","Road_2C.tscn",360,0,1310
    "Road_2D","Road_2D.tscn",390,0,1310
    "Road_3B","Update\Road_3B.tscn",420,0,1310
    "Road_3C","Update\Road_3C.tscn",450,0,1310
    "Road_3D","Update\Road_3D.tscn",480,0,1310
    "Road_3E","Update\Road_3E.tscn",510,0,1310
    "Road_3F","Update\Road_3F.tscn",540,0,1310
    "Road_3G","Update\Road_3G.tscn",570,0,1310
    "Road_3H","Update\Road_3H.tscn",600,0,1310
    "Road_3I","Update\Road_3I.tscn",630,0,1310
    "Road_3J","Update\Road_3J.tscn",660,0,1310
    "Road_3K","Update\Road_3K.tscn",690,0,1310
    "Road_3L","Update\Road_3L.tscn",720,0,1310
    "Road_3M","Update\Road_3M.tscn",750,0,1310
    "Road_3N","Update\Road_3N.tscn",780,0,1310
    "Road_3O","Update\Road_3O.tscn",810,0,1310
    "Road_3P","Update\Road_3P.tscn",840,0,1310
    "Road_3Q","Update\Road_3Q.tscn",870,0,1310
    "Road_3R","Update\Road_3R.tscn",900,0,1310
    "Road_3S","Update\Road_3S.tscn",930,0,1310
    "Road_3T","Update\Road_3T.tscn",960,0,1310
    "Road_3U","Update\Road_3U.tscn",990,0,1310
    "Road_3V","Update\Road_3V.tscn",1020,0,1310
    # Row 18: Roundabouts + Arches (Z=1390)
    "Roundabout_1A","Roundabout_1A.tscn",-120,0,1390
    "Roundabout_2A","Update\Roundabout_2A.tscn",-40,0,1390
    "Roundabout_2B","Update\Roundabout_2B.tscn",40,0,1390
    "Roundabout_2C","Update\Roundabout_2C.tscn",120,0,1390
    "Concrete_Arch_1A","Update\Concrete_Arch_1A.tscn",200,0,1390
    "Modern_Arch_1A","Update\Modern_Arch_1A.tscn",240,0,1390
    "Modern_Arch_1B","Update\Modern_Arch_1B.tscn",280,0,1390
    "Modern_Arch_2A","Update\Modern_Arch_2A.tscn",320,0,1390
    "Modern_Arch_2B","Update\Modern_Arch_2B.tscn",360,0,1390
    "Modern_Arch_2C","Update\Modern_Arch_2C.tscn",400,0,1390
    # Row 19: More pavement variants (Z=1470)
    "Pavement_1A_1x1","Pavement_1A_1x1.tscn",-300,0,1470
    "Pavement_1A_2x2","Pavement_1A_2x2.tscn",-285,0,1470
    "Pavement_1A_3x3","Pavement_1A_3x3.tscn",-265,0,1470
    "Pavement_1B_1x1","Pavement_1B_1x1.tscn",-240,0,1470
    "Pavement_1B_2x2","Pavement_1B_2x2.tscn",-225,0,1470
    "Pavement_1B_3x3","Pavement_1B_3x3.tscn",-205,0,1470
    "Pavement_1C_2x2","Pavement_1C_2x2.tscn",-180,0,1470
    "Pavement_1C_3x3","Pavement_1C_3x3.tscn",-160,0,1470
    "Pavement_1D_2x2","Pavement_1D_2x2.tscn",-135,0,1470
    "Pavement_1D_3x3","Pavement_1D_3x3.tscn",-115,0,1470
    "Pavement_1E_1x1","Pavement_1E_1x1.tscn",-90,0,1470
    "Pavement_1E_2x2","Pavement_1E_2x2.tscn",-75,0,1470
    "Pavement_1E_3x3","Pavement_1E_3x3.tscn",-55,0,1470
    "Pavement_1F_4x4","Pavement_1F_4x4.tscn",-25,0,1470
    "Pavement_1G_4x4","Pavement_1G_4x4.tscn",5,0,1470
    "Pavement_1H_4x4","Pavement_1H_4x4.tscn",35,0,1470
    "Pavement_1I_4x4","Pavement_1I_4x4.tscn",65,0,1470
    "Pavement_1J_1x1","Pavement_1J_1x1.tscn",90,0,1470
    "Pavement_1J_2x2","Pavement_1J_2x2.tscn",105,0,1470
    "Pavement_1J_3x3","Pavement_1J_3x3.tscn",125,0,1470
    "Pavement_1J_4x4","Pavement_1J_4x4.tscn",155,0,1470
    "Pavement_1K_4x4","Pavement_1K_4x4.tscn",185,0,1470
    "Pavement_1L_4x4","Pavement_1L_4x4.tscn",215,0,1470
    "Pavement_1M_4x4","Pavement_1M_4x4.tscn",245,0,1470
    "Pavement_1N_4x4","Pavement_1N_4x4.tscn",275,0,1470
    "Pavement_1S_4x4","Pavement_1S_4x4.tscn",305,0,1470
    "Pavement_2A_2X2","Update\Pavement_2A_2X2.tscn",330,0,1470
    "Pavement_2A_3X3","Update\Pavement_2A_3X3.tscn",350,0,1470
    "Pavement_2A_4X4","Update\Pavement_2A_4X4.tscn",375,0,1470
    "Pavement_2B_4X4","Update\Pavement_2B_4X4.tscn",405,0,1470
    "Pavement_2C_4X4","Update\Pavement_2C_4X4.tscn",435,0,1470
    "Pavement_2D_4X4","Update\Pavement_2D_4X4.tscn",465,0,1470
    "Pavement_2E_4X4","Update\Pavement_2E_4X4.tscn",495,0,1470
    "Pavement_2F_4X4","Update\Pavement_2F_4X4.tscn",525,0,1470
    "Pavement_2G_4X4","Update\Pavement_2G_4X4.tscn",555,0,1470
    "Pavement_2H_4X4","Update\Pavement_2H_4X4.tscn",585,0,1470
    "Pavement_2I_4X4","Update\Pavement_2I_4X4.tscn",615,0,1470
    "Pavement_Rounded_2A_4X4","Update\Pavement_Rounded_2A_4X4.tscn",645,0,1470
    "Pavement_Rounded_2B_4X4","Update\Pavement_Rounded_2B_4X4.tscn",675,0,1470
    "Pavement_Rounded_2C_8X8","Update\Pavement_Rounded_2C_8X8.tscn",715,0,1470
    "Pavement_Rounded_2D_14x14","Update\Pavement_Rounded_2D_14x14.tscn",760,0,1470
    "Pavement_Special_2A_8X8","Pavement_Special_2A_8X8.tscn",810,0,1470
    "Pavement_Special_3A_8X8","Update\Pavement_Special_3A_8X8.tscn",855,0,1470
    "Pavement_Special_4A_8X8","Update\Pavement_Special_4A_8X8.tscn",900,0,1470
    "Pavement_Special_4B_8X8","Update\Pavement_Special_4B_8X8.tscn",945,0,1470
    # Row 20: More pipes + cables + suspended cables (Z=1550)
    "Pipe_1C","Pipe_1C.tscn",-250,0,1550
    "Pipe_1D","Pipe_1D.tscn",-238,0,1550
    "Pipe_1E","Pipe_1E.tscn",-226,0,1550
    "Pipe_1F","Pipe_1F.tscn",-214,0,1550
    "Pipe_1G","Pipe_1G.tscn",-202,0,1550
    "Pipe_2B","Pipe_2B.tscn",-188,0,1550
    "Pipe_2C","Pipe_2C.tscn",-176,0,1550
    "Pipe_2D","Pipe_2D.tscn",-164,0,1550
    "Pipe_2E","Pipe_2E.tscn",-152,0,1550
    "Pipe_2F","Pipe_2F.tscn",-140,0,1550
    "Pipe_2G","Pipe_2G.tscn",-128,0,1550
    "Pipe_3B","Pipe_3B.tscn",-114,0,1550
    "Pipe_3C","Pipe_3C.tscn",-102,0,1550
    "Pipe_3D","Pipe_3D.tscn",-90,0,1550
    "Pipe_3E","Pipe_3E.tscn",-78,0,1550
    "Pipe_3F","Pipe_3F.tscn",-66,0,1550
    "Pipe_3G","Pipe_3G.tscn",-54,0,1550
    "Pipe_Support_2A","Pipe_Support_2A.tscn",-38,0,1550
    "Pipe_Support_3A","Pipe_Support_3A.tscn",-24,0,1550
    "Cable_Pole_1C","Cable_Pole_1C.tscn",-5,0,1550
    "Cable_Pole_2A","Update\Cable_Pole_2A.tscn",14,0,1550
    "Cable_1B","Cable_1B.tscn",35,0,1550
    "Cable_1C","Cable_1C.tscn",50,0,1550
    "Cable_1D","Cable_1D.tscn",65,0,1550
    "Cable_2A","Cable_2A.tscn",80,0,1550
    "Cable_2B","Cable_2B.tscn",95,0,1550
    "Cable_2C","Cable_2C.tscn",110,0,1550
    "Suspended_Cable_1A","Update\Suspended_Cable_1A.tscn",128,0,1550
    "Suspended_Cable_1B","Update\Suspended_Cable_1B.tscn",148,0,1550
    "Concrete_Fence_1C","Concrete_Fence_1C.tscn",168,0,1550
    # Row 21: Safety nets (Z=1630)
    "Safety_Net_1B","Safety_Net_1B.tscn",-180,0,1630
    "Safety_Net_1C","Safety_Net_1C.tscn",-160,0,1630
    "Safety_Net_1D","Safety_Net_1D.tscn",-140,0,1630
    "Safety_Net_1E","Safety_Net_1E.tscn",-120,0,1630
    "Safety_Net_2A","Safety_Net_2A.tscn",-98,0,1630
    "Safety_Net_2B","Safety_Net_2B.tscn",-78,0,1630
    "Safety_Net_2C","Safety_Net_2C.tscn",-58,0,1630
    "Safety_Net_2D","Safety_Net_2D.tscn",-38,0,1630
    "Safety_Net_2E","Safety_Net_2E.tscn",-18,0,1630
    "Safety_Net_3A","Safety_Net_3A.tscn",5,0,1630
    "Safety_Net_3B","Safety_Net_3B.tscn",25,0,1630
    "Safety_Net_3C","Safety_Net_3C.tscn",45,0,1630
    "Safety_Net_3D","Safety_Net_3D.tscn",65,0,1630
    "Safety_Net_3E","Safety_Net_3E.tscn",85,0,1630
    # Row 22: Wall panels + Titles/Lettering (Z=1710)
    "Wall_Pannel_1A","Update\Wall_Pannel_1A.tscn",-160,0,1710
    "Wall_Pannel_1B","Update\Wall_Pannel_1B.tscn",-130,0,1710
    "Wall_Pannel_1C","Update\Wall_Pannel_1C.tscn",-100,0,1710
    "Wall_Pannel_1D","Update\Wall_Pannel_1D.tscn",-70,0,1710
    "Title_1A","Lettering\Title_1A.tscn",-30,0,1710
    "Title_1B","Lettering\Title_1B.tscn",-15,0,1710
    "Title_2A","Lettering\Title_2A.tscn",0,0,1710
    "Title_2B","Lettering\Title_2B.tscn",15,0,1710
    "Title_3A","Lettering\Title_3A.tscn",30,0,1710
    "Title_3B","Lettering\Title_3B.tscn",45,0,1710
    "Title_4A","Lettering\Title_4A.tscn",60,0,1710
    "Title_5A","Lettering\Title_5A.tscn",75,0,1710
    "Title_6A","Lettering\Title_6A.tscn",90,0,1710
    "Title_7A","Lettering\Title_7A.tscn",105,0,1710
    "Title_8A","Lettering\Title_8A.tscn",120,0,1710
    "Title_9A","Lettering\Title_9A.tscn",135,0,1710
    "Title_10A","Lettering\Title_10A.tscn",150,0,1710
    "Title_11A","Lettering\Title_11A.tscn",165,0,1710
    # Row 23: More streetlights + signs + benches + tables + umbrellas (Z=1790)
    "Streetlight_2B","Streetlight_2B.tscn",-200,0,1790
    "Streetlight_2C","Streetlight_2C.tscn",-186,0,1790
    "Streetlight_2D","Streetlight_2D.tscn",-172,0,1790
    "Streetlight_2E","Streetlight_2E.tscn",-158,0,1790
    "Streetlight_3B","Streetlight_3B.tscn",-144,0,1790
    "Streetsign_1B","Streetsign_1B.tscn",-125,0,1790
    "Streetsign_1C","Streetsign_1C.tscn",-112,0,1790
    "Streetsign_2B","Streetsign_2B.tscn",-99,0,1790
    "Streetsign_2C","Streetsign_2C.tscn",-86,0,1790
    "Streetsign_2D","Streetsign_2D.tscn",-73,0,1790
    "Streetsign_2E","Streetsign_2E.tscn",-60,0,1790
    "Streetsign_2F","Streetsign_2F.tscn",-47,0,1790
    "Streetsign_2G","Streetsign_2G.tscn",-34,0,1790
    "Streetsign_2H","Streetsign_2H.tscn",-21,0,1790
    "Streetsign_2I","Streetsign_2I.tscn",-8,0,1790
    "Hydrant_1B","Hydrant_1B.tscn",10,0,1790
    "Impact_Barrel_1A","Impact_Barrel_1A.tscn",25,0,1790
    "Manhole_1B","Manhole_1B.tscn",40,0,1790
    "Traffic_Cone_2B","Traffic_Cone_2B.tscn",55,0,1790
    "Bench_1C","Update\Bench_1C.tscn",70,0,1790
    "Bench_2B","Bench_2B.tscn",83,0,1790
    "Bench_2C","Bench_2C.tscn",96,0,1790
    "Bench_2D","Bench_2D.tscn",109,0,1790
    "Table_1B","Table_1B.tscn",124,0,1790
    "Table_1C","Table_1C.tscn",138,0,1790
    "Umbrella_1B","Umbrella_1B.tscn",155,0,1790
    "Umbrella_1C","Umbrella_1C.tscn",169,0,1790
    "Umbrella_1D","Umbrella_1D.tscn",183,0,1790
    "Umbrella_2B","Umbrella_2B.tscn",197,0,1790
    "Umbrella_2C","Umbrella_2C.tscn",211,0,1790
    "Umbrella_2D","Umbrella_2D.tscn",225,0,1790
    # Row 24: Remaining props + more billboards + cars (Z=1870)
    "Barrel_1D","Barrel_1D.tscn",-200,0,1870
    "Barrel_1E","Barrel_1E.tscn",-188,0,1870
    "Barrel_2B","Barrel_2B.tscn",-176,0,1870
    "Paper_Pack_1B","Paper_Pack_1B.tscn",-160,0,1870
    "Paper_Pack_2B","Paper_Pack_2B.tscn",-148,0,1870
    "Trash_Bag_1B","Trash_Bag_1B.tscn",-132,0,1870
    "Trash_Bag_2B","Trash_Bag_2B.tscn",-120,0,1870
    "Trash_Can_1C","Trash_Can_1C.tscn",-105,0,1870
    "Trash_Container_1B","Trash_Container_1B.tscn",-90,0,1870
    "Trash_Container_2A","Trash_Container_2A.tscn",-72,0,1870
    "Trash_Container_2B","Trash_Container_2B.tscn",-54,0,1870
    "Power_Box_1C","Power_Box_1C.tscn",-35,0,1870
    "Plant_Pot_1B","Plant_Pot_1B.tscn",-20,0,1870
    "Plant_Pot_2B","Plant_Pot_2B.tscn",-8,0,1870
    "Plant_Pot_2C","Plant_Pot_2C.tscn",6,0,1870
    "Skyscraper_1C","Skyscraper_1C.tscn",50,0,1870
    "Billboard_1C","Billboard_1C.tscn",100,0,1870
    "Billboard_2B","Billboard_2B.tscn",140,0,1870
    "Billboard_2C","Billboard_2C.tscn",180,0,1870
    "Billboard_2D","Billboard_2D.tscn",220,0,1870
    "Billboard_2E","Billboard_2E.tscn",260,0,1870
    "Billboard_2F","Billboard_2F.tscn",300,0,1870
    "Billboard_3C","Billboard_3C.tscn",340,0,1870
    "Billboard_3D","Billboard_3D.tscn",380,0,1870
    "Billboard_4A","Update\Billboard_4A.tscn",420,0,1870
    "Car_10D","Car_10D.tscn",460,0,1870
    "Car_14D","Car_14D.tscn",484,0,1870
    "Car_15B","Car_15B.tscn",508,0,1870
    "Car_15C","Car_15C.tscn",532,0,1870
    "Car_15D","Car_15D.tscn",556,0,1870
    "Car_16B","Car_16B.tscn",580,0,1870
    "Car_17B","Car_17B.tscn",604,0,1870
    "Car_3C","Car_3C.tscn",628,0,1870
    "Car_4D","Car_4D.tscn",652,0,1870
    "Car_4E","Car_4E.tscn",676,0,1870
    "Car_6E","Car_6E.tscn",700,0,1870
    "Car_6F","Car_6F.tscn",724,0,1870
    "Car_7E","Car_7E.tscn",748,0,1870
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
    # Use forward slashes and correct res:// prefix (Update\ files are under Models/Update/)
    $rpath = ($res + "/" + $e.File).Replace("\", "/")
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
