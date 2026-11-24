# CAR_ROSTER_BIBLE.md — 32 Realistic Vehicles & Automotive Reference Catalog

This bible documents the complete 32-vehicle catalog of **GRIDLETHAL**. Every vehicle is grounded in real-world automotive engineering, aerodynamic silhouettes, engine configurations, and historical racing homologations, balanced within an **Open Class Sandbox** via Power-to-Weight Ratio and Combat Rating.

---

## Catalog Summary Matrix

| # | Car Identifier | Name | Archetype | Real-World Automotive Benchmark | Curb Mass | Power | HP/Ton | Combat Rating |
|---|---|---|---|---|:---:|:---:|:---:|:---:|
| 1 | `sprinter_r2` | **Sprinter R2** | Rally Special | Lancia 037 Stradale / Delta S4 | 1,180 kg | 290 hp | 245 | C (140) |
| 2 | `dust_viper` | **Dust Viper** | Rally Special | Ford RS200 Evolution Group B | 1,050 kg | 325 hp | 310 | B (185) |
| 3 | `gravel_fang` | **Gravel Fang** | Rally Special | Audi Sport Quattro S1 E2 | 1,200 kg | 410 hp | 341 | A (230) |
| 4 | `tundra_wolf` | **Tundra Wolf** | Rally Special | Subaru Impreza 22B STi | 1,270 kg | 355 hp | 279 | B (195) |
| 5 | `desert_corsair` | **Desert Corsair** | Rally Special | Toyota Celica GT-Four ST205 | 1,380 kg | 360 hp | 260 | B (175) |
| 6 | `ridge_phantom` | **Ridge Phantom** | Rally Special | Peugeot 205 Turbo 16 Evo 2 | 960 kg | 340 hp | 354 | A (245) |
| 7 | `iron_charger` | **Iron Charger** | Muscle Raider | 1969 Dodge Charger R/T 426 Hemi | 1,650 kg | 455 hp | 275 | C (160) |
| 8 | `venom_boss` | **Venom Boss** | Muscle Raider | 1970 Ford Mustang Boss 429 | 1,580 kg | 460 hp | 291 | B (180) |
| 9 | `scrap_cuda` | **Scrap Cuda** | Muscle Raider | 1970 Plymouth Hemi 'Cuda | 1,540 kg | 440 hp | 285 | B (175) |
| 10 | `gnx_marauder` | **GNX Marauder** | Muscle Raider | 1987 Buick GNX Turbo V6 | 1,500 kg | 400 hp | 266 | C (165) |
| 11 | `camaro_fury` | **Camaro Fury** | Muscle Raider | 1969 Chevrolet Camaro SS 396 | 1,520 kg | 415 hp | 273 | C (155) |
| 12 | `javelin_reaper`| **Javelin Reaper** | Muscle Raider | 1971 AMC Javelin AMX 401 | 1,480 kg | 415 hp | 280 | B (170) |
| 13 | `bulldog_6x6` | **Bulldog 6x6** | Heavy Offroad | Mercedes-Benz G63 AMG 6x6 | 3,750 kg | 620 hp | 165 | A (260) |
| 14 | `rock_crusher` | **Rock Crusher** | Heavy Offroad | Bowler Wildcat Dakar | 1,750 kg | 405 hp | 231 | B (210) |
| 15 | `mud_reaper` | **Mud Reaper** | Heavy Offroad | Ford F-150 Baja Trophy Truck | 2,150 kg | 610 hp | 283 | A (250) |
| 16 | `scrap_titan` | **Scrap Titan** | Heavy Offroad | Oshkosh JLTV Heavy Combat | 4,800 kg | 675 hp | 140 | S (310) |
| 17 | `dune_behemoth` | **Dune Behemoth** | Heavy Offroad | Land Rover Defender 110 Trophy | 2,250 kg | 440 hp | 195 | B (220) |
| 18 | `warlord_h1` | **Warlord H1** | Heavy Offroad | AM General Humvee H1 Alpha | 3,400 kg | 510 hp | 150 | A (270) |
| 19 | `skyline_vspec` | **Skyline V-Spec** | GT Interceptor | Nissan Skyline GT-R R32 V-Spec | 1,430 kg | 410 hp | 286 | B (205) |
| 20 | `bavarian_evo` | **Bavarian Evo** | GT Interceptor | BMW M3 Sport Evolution E30 | 1,200 kg | 300 hp | 250 | B (180) |
| 21 | `stuttgart_190` | **Stuttgart 190** | GT Interceptor | Mercedes-Benz 190E 2.5-16 Evo II | 1,340 kg | 320 hp | 238 | C (175) |
| 22 | `rotary_wraith` | **Rotary Wraith** | GT Interceptor | Mazda RX-7 Spirit R FD3S | 1,260 kg | 375 hp | 297 | A (220) |
| 23 | `turbo_930` | **Turbo 930** | GT Interceptor | Porsche 911 Turbo 3.3 (930) | 1,300 kg | 410 hp | 315 | A (235) |
| 24 | `cosworth_rs` | **Cosworth RS** | GT Interceptor | Ford Sierra RS500 Cosworth | 1,210 kg | 320 hp | 264 | B (190) |
| 25 | `vantage_v600` | **Vantage V600** | GT Interceptor | Aston Martin V8 Vantage V600 | 1,970 kg | 610 hp | 309 | A (240) |
| 26 | `aurelia_gt` | **Aurelia GT** | Apex Supercar | McLaren F1 LM | 1,060 kg | 615 hp | 580 | S (330) |
| 27 | `noir_phantom` | **Noir Phantom** | Apex Supercar | Ferrari F40 LM Competizione | 1,050 kg | 550 hp | 523 | S (320) |
| 28 | `vandal_hyper` | **Vandal Hyper** | Apex Supercar | Bugatti EB110 Super Sport | 1,420 kg | 700 hp | 492 | S (315) |
| 29 | `gilded_sovereign`| **Gilded Sovereign** | Apex Supercar | Jaguar XJ220-S TWR | 1,340 kg | 620 hp | 462 | S (305) |
| 30 | `countach_apex` | **Countach Apex** | Apex Supercar | Lamborghini Countach 25th Anniv | 1,490 kg | 610 hp | 409 | A (285) |
| 31 | `zonda_reign` | **Zonda Reign** | Apex Supercar | Pagani Zonda C12-S 7.3 | 1,250 kg | 640 hp | 512 | S (325) |
| 32 | `dakar_959` | **Dakar 959** | Apex Supercar | Porsche 959 Paris-Dakar Special | 1,260 kg | 485 hp | 384 | S (300) |

---

## Detailed Vehicle Profiles & Real-World Photo Comparisons

### 1. Sprinter R2
- **Benchmark**: Lancia 037 Stradale (1982) / Delta S4 Group B
- **Photo Reference**: [Wikimedia: Lancia 037 Stradale Front-Quarter](https://upload.wikimedia.org/wikipedia/commons/7/7b/Lancia_037_Stradale.jpg)
- **Visual Silhouette**: Low-slung mid-engine wedge with squared dual headlamps, integrated rear ducktail spoiler, wide flared rear arches, and twin auxiliary rally light pods.
- **Drivetrain**: Mid-engine RWD, 2.0L Supercharged Inline-4, 5-speed manual, limited-slip differential.
- **Dynamics**: Agile turn-in with responsive pendulum oversteer on gravel surfaces.

### 2. Dust Viper
- **Benchmark**: Ford RS200 Evolution (1986)
- **Photo Reference**: [Wikimedia: Ford RS200 Group B](https://upload.wikimedia.org/wikipedia/commons/e/ec/Ford_RS200_1986.jpg)
- **Visual Silhouette**: Compact greenhouse with distinctive high roof snorkel, bubble cabin, twin rear intercooler vents, and wide round headlights.
- **Drivetrain**: Mid-engine AWD with adjustable torque split (33/67 default), 2.1L Turbocharged Cosworth BDT-E, 5-speed dual-clutch.
- **Dynamics**: Explosive turbo spool above 4,200 RPM, exceptional dirt launch grip.

### 3. Gravel Fang
- **Benchmark**: Audi Sport Quattro S1 E2 (1985)
- **Photo Reference**: [Wikimedia: Audi Sport Quattro S1](https://upload.wikimedia.org/wikipedia/commons/b/b3/Audi_Sport_Quattro_S1.jpg)
- **Visual Silhouette**: Aggressive front snowplow splitter, massive boxed fender flares, high-mounted rear bi-plane wing, and hood heat louvers.
- **Drivetrain**: Front-longitudinal AWD, 2.1L 20V Turbocharged Inline-5 (distinctive 5-cylinder warble), 6-speed dog-box.
- **Dynamics**: Colossal high-speed downforce and immense straight-line traction.

### 4. Tundra Wolf
- **Benchmark**: Subaru Impreza 22B STi (1998)
- **Photo Reference**: [Wikimedia: Subaru Impreza 22B STi](https://upload.wikimedia.org/wikipedia/commons/e/e0/Subaru_Impreza_22B-STi_Version.jpg)
- **Visual Silhouette**: Widebody 2-door coupe, signature tall rear wing, aluminum hood scoop with dual heat extractors, gold multi-spoke rally wheels.
- **Drivetrain**: Front Boxer-4 2.2L Turbocharged, Symmetrical AWD with Driver Controlled Center Differential (DCCD).
- **Dynamics**: Neutral chassis balance with high grip threshold on snow, ice, and asphalt.

### 5. Iron Charger
- **Benchmark**: 1969 Dodge Charger R/T 426 Hemi
- **Photo Reference**: [Wikimedia: 1969 Dodge Charger R/T](https://upload.wikimedia.org/wikipedia/commons/2/22/1969_Dodge_Charger_RT.jpg)
- **Visual Silhouette**: Long sculpted coke-bottle fuselage, concealed hideaway headlights behind recessed front grille, flying buttress rear roofline, side exit dual exhausts.
- **Drivetrain**: Front 7.0L (426 ci) Hemi V8, heavy-duty rear solid axle with Positraction differential, 4-speed manual.
- **Dynamics**: Massive low-end torque ($660\text{ Nm}$), dramatic burnouts and high-angle power slides.

### 6. Bulldog 6x6
- **Benchmark**: Mercedes-Benz G63 AMG 6x6 (2014)
- **Photo Reference**: [Wikimedia: Mercedes-Benz G63 AMG 6x6](https://upload.wikimedia.org/wikipedia/commons/5/52/Mercedes-Benz_G_63_AMG_6x6_%28cropped%29.jpg)
- **Visual Silhouette**: Towering 6-wheel chassis with portal axles, beadlock offroad rims, cab-mounted roof LED light bar, pickup utility bed with roll bars.
- **Drivetrain**: Front-mounted 5.5L Twin-Turbo V8, 6x6 drive with 5 electronic differential locks.
- **Dynamics**: Unstoppable over rough terrain and obstacles, massive ramming mass ($3,750\text{ kg}$).

### 7. Skyline V-Spec
- **Benchmark**: Nissan Skyline GT-R R32 V-Spec II (1994)
- **Photo Reference**: [Wikimedia: Nissan Skyline GT-R R32](https://upload.wikimedia.org/wikipedia/commons/4/4c/Nissan_Skyline_GT-R_R32_front.jpg)
- **Visual Silhouette**: Muscular boxy profile, quad round tail lights, subtle functional rear decklid spoiler, front intercooler aperture.
- **Drivetrain**: 2.6L Twin-Turbocharged Inline-6 (RB26DETT), ATTESA E-TS hydraulic all-wheel-drive system, Super HICAS 4-wheel steering.
- **Dynamics**: Precision turn-in with proactive torque transfer to front wheels on exit.

### 8. Aurelia GT
- **Benchmark**: McLaren F1 LM (1995)
- **Photo Reference**: [Wikimedia: McLaren F1 LM](https://upload.wikimedia.org/wikipedia/commons/8/86/McLaren_F1_LM.jpg)
- **Visual Silhouette**: Central cockpit position, dihedral doors, roof-mounted ram-air intake snorkel, carbon rear diffuser, fixed CFRP high-downforce rear wing.
- **Drivetrain**: Mid-mounted 6.1L 60° Naturally Aspirated V12, RWD, 6-speed manual transaxle.
- **Dynamics**: Highest power-to-weight ratio in the game ($580\text{ hp/ton}$), blistering top speed ($380+\text{ km/h}$).

---

*Full technical properties for all 32 cars are encoded in [data/vehicles.json](file:///c:/Users/Aaron/Desktop/Fresh_Start/data/vehicles.json) and validated at boot time.*
