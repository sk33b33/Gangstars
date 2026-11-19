# Driving feel: gearbox, steering and the speedometer

Goal: any car the player can drive feels like a real, ordinary car: it pulls away slowly and strongly in 1st, runs through the gears
to a top speed that suits the vehicle, brakes and coasts believably, and steers less at speed. The dashboard shows the speed and the gear,
only while the player is in a car.

## Gearbox (`scripts/vehicles/drivetrain.gd`, data `data/vehicles/drivetrains.json`)
- Pure logic, one `Drivetrain` per drivable car. Every vehicle model has an entry: `gears_kmh` (the speed each gear reaches at the engine's
  redline: short for 1st, long for the top gear), `launch_accel` (m/s^2 in 1st), `reverse_kmh`, `idle` and `redline` rpm.
- Acceleration in a gear is `launch_accel` scaled by how short the gear is (gear 1's top speed over this gear's, to the power 0.62) and by a
  torque curve over the engine speed. So 1st is strong and slow, the top gear weak and fast. A hatchback does 0-100 km/h in about 16 s and
  tops out at 128 km/h; a police car 0-100 in about 12 s and 150 km/h; a bus reaches 78 km/h.
- Automatic: shifts up at 93% of a gear's top speed (pedal down), down when the engine would fall under 55% of the lower gear's range. A change
  of gear costs a short torque cut (0.28 s up, 0.18 s down) in which nothing pulls. The clutch slips below about a third of the range, so
  the engine never stalls at a crawl.
- Pedal meaning follows the direction of travel: forward, the accelerator pulls and back brakes; backing up, back accelerates in reverse and
  forward brakes; at a standstill the pedal picks 1st or reverse; no pedal at rest is neutral.
- Braking is a separate, stronger force (8.5 m/s^2 at full brake). Coasting: rolling and air drag plus engine braking that is stronger in
  a low gear. The driver's skill (`Player.drive_factor`) scales every gear's speed.

## Steering (`DrivableCar`)
A bicycle model: yaw rate = speed / wheelbase * tan(steering angle). The front wheels' full lock is wide when crawling (0.62 rad) and
almost nothing at top speed (0.10 rad). The wheel has weight: it follows the stick at 2.6 per second and returns at 3.6. Sideways grip is
limited to 8.5 m/s^2: past that the car runs wide and scrubs speed. The brake lights come on only for braking.

## Sound
The engine hum's pitch follows the engine speed (so it drops at each shift and climbs through the gears) and its volume the pedal.

## Speedometer (`scripts/ui/speedometer.gd`, put on screen by `Hud.set_vehicle`)
A 270 degree dial at the bottom centre, drawn in code: needle on the speed (it follows a little behind, like a real needle), a ring round
the edge for the engine speed (red near the redline), the gear (R, N, 1 to 5) in the middle of the dial (dimmed while the gearbox changes
gear), and the speed in digits under it. Scale: the car's top speed rounded up to the next 20 km/h. It is visible only while the player is
in a car (`GameSession._on_vehicle_changed`); the prompt and the messages move up while it is on screen.

## Tests
`tests/run_tests.gd`: the hatchback's gear run, torque cut and top speed; reverse, neutral and braking; every vehicle's data; the lock at
speed; the gauge shows and hides; the gauge and the gear while driving in the game.
