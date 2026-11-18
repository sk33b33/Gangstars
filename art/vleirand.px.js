// Westridge starter district — pixel textures for 3D surfaces.
// Density: 16 px per metre. Tinted textures (plaster, precast) are kept near-white so the
// Godot material albedo colour gives each house its paint colour.
// Build: tools/build_textures.sh
pal({
  k: "#1d1b24",                                   // ink / deep shadow
  W: "#ffffff", w: "#f1eee8", v: "#dcd8d0", V: "#c2bdb3", u: "#a49e94",   // tintable plaster ramp
  n: "#3a3d46", N: "#565a64", m: "#7d828c", M: "#a7acb4",                 // steel / metal
  g: "#d9d4c8", G: "#b8b2a6", h: "#959084",                               // glass-free frame greys
  b: "#29384a", B: "#3f5874", c: "#6f8fae", C: "#a7c0d6",                 // glass / sky reflection
  d: "#6b4630", D: "#4a2f22", e: "#8c6044",                               // wood door
  t: "#a24a32", T: "#7a3424", y: "#c8673f",                               // terracotta tiles
  i: "#6d7177", I: "#545860", j: "#8b9097",                               // IBR sheeting
  a: "#3b3b40", A: "#2e2e33", s: "#4a4a50",                               // asphalt
  p: "#9c9a95", P: "#85837e", q: "#b3b1ab",                               // concrete paving
  z: "#d9c49a", Z: "#c2ab80", x: "#e8d8b2", X: "#a8916a",                 // Cape Flats sand
  r: "#9c5a3c", R: "#7d4530", o: "#b8714e",                               // clay brick
  l: "#e7c64a", L: "#c9a42e", f: "#2f6e3a", F: "#245a2e",                 // sign colours
})
ramps("uVvwW", "nNmM", "hGg", "bBcC", "Dde", "Tty", "Iij", "Aas", "Ppq", "XZzx", "Rro")

// ------------------------------------------------------------------ walls
// Plain trowelled plaster: flat with faint horizontal float marks (cause: plastering by hand).
sprite("wall_plaster", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "w"),
  hline(3, 6, 9, "W"), hline(18, 13, 11, "W"), hline(6, 22, 8, "W"), hline(21, 28, 7, "W"),
  hline(12, 9, 5, "v"), hline(1, 17, 6, "v"), hline(25, 3, 5, "v"), hline(14, 25, 6, "v"))

// Face brick, near-white so each house can be tinted brick red or brown: stretcher bond, 4 courses per 16 px, mortar joints a little darker,
// the odd brick fired lighter or darker (cause: uneven firing).
sprite("wall_brick", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "v"),
  (c) => {
    for (let row = 0; row < 8; row++) {
      const y = row * 4, off = (row % 2) * 4
      c.hline(0, y + 3, 32, "u")
      for (let b = 0; b < 4; b++) {
        const x = (off + b * 8) % 32
        c.vline(x, y, 3, "u")
        if ((row * 5 + b * 3) % 7 === 0) c.rect(x + 1, y, 7, 3, "w")
        if ((row * 3 + b * 5) % 9 === 0) c.rect(x + 1, y, 7, 3, "V")
      }
    }
  })

// Rough-cast (pebbledash) plaster: a granular finish, so a sparse speckle is justified here.
sprite("wall_rough", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "w"), noise(0, 0, 32, 32, "W", 0.18, 5), noise(0, 0, 32, 32, "v", 0.2, 11), noise(0, 0, 32, 32, "V", 0.06, 17))

// Splash-back grime band: dirt kicked up from the sandy yard, fading upward.
sprite("wall_grime", { w: 32, h: 8 },
  rect(0, 0, 32, 8, "w"),
  dither(0, 2, 32, 2, "w", "v", 0.25), dither(0, 4, 32, 2, "v", "V", 0.4),
  dither(0, 6, 32, 2, "V", "u", 0.5))

// ------------------------------------------------------------------ openings
// Window 1.5 x 1.25 m: grey steel frame, sill, glass with sky reflection, diamond burglar bars.
sprite("window_bars", { w: 24, h: 20 },
  rect(0, 0, 24, 18, "G"), rect(1, 1, 22, 16, "b"),
  grad(1, 1, 22, 16, "BbbC", "v", 0.6), poly([3, 2, 9, 2, 3, 9], "c"), poly([13, 2, 16, 2, 13, 5], "c"),
  vline(12, 1, 16, "G"), hline(1, 8, 22, "G"),
  (c) => {
    // diamond lattice of burglar bars
    for (let k = -20; k < 24; k += 6) {
      c.line(1 + k, 1, 1 + k + 16, 17, "M"); c.line(1 + k + 16, 1, 1 + k, 17, "M")
    }
  },
  rect(0, 0, 24, 1, "h"), vline(0, 0, 18, "h"), vline(23, 0, 18, "h"), rect(0, 17, 24, 1, "h"),
  rect(0, 18, 24, 2, "g"), hline(0, 19, 24, "G"))

// Door 1 x 2 m: wooden door behind a steel security gate with a lock box.
sprite("door_gate", { w: 16, h: 32 },
  rect(0, 0, 16, 32, "D"), rect(1, 1, 14, 31, "d"),
  rect(3, 3, 10, 10, "e"), rect(3, 16, 10, 13, "e"), box(3, 3, 10, 10, "D"), box(3, 16, 10, 13, "D"),
  (c) => { for (let x = 1; x < 16; x += 3) c.vline(x, 0, 32, "n") },
  hline(0, 1, 16, "N"), hline(0, 11, 16, "N"), hline(0, 21, 16, "N"), hline(0, 30, 16, "N"),
  rect(11, 14, 4, 4, "N"), px(12, 15, "M"), box(0, 0, 16, 32, "n"))

// Garage door 2.5 x 2 m: white steel panels with horizontal ribs.
sprite("garage_door", { w: 40, h: 32 },
  rect(0, 0, 40, 32, "W"),
  (c) => { for (let y = 3; y < 32; y += 4) { c.hline(1, y, 38, "v"); c.hline(1, y + 1, 38, "w") } },
  rect(18, 26, 4, 2, "V"), box(0, 0, 40, 32, "V"), dither(1, 28, 38, 3, "W", "v", 0.3))

// ------------------------------------------------------------------ fences
// Precast concrete fence 2 x 1.5 m: posts at both ends, stacked panels, lattice top band.
sprite("fence_precast", { w: 32, h: 24 },
  rect(0, 0, 32, 24, "w"),
  (c) => { for (let y = 8; y < 24; y += 4) { c.hline(2, y, 28, "V"); c.hline(2, y + 1, 28, "W") } },
  rect(2, 1, 28, 6, "v"),
  (c) => {
    // diamond lattice cut-outs (transparent), as in reference photo 2
    for (let x = 3; x < 29; x += 4) { c.poly([x + 2, 2, x + 4, 4, x + 2, 6, x, 4], "_") }
  },
  hline(2, 0, 28, "W"), hline(2, 7, 28, "V"),
  rect(0, 0, 2, 24, "W"), vline(1, 0, 24, "v"), rect(30, 0, 2, 24, "W"), vline(31, 0, 24, "v"),
  dither(2, 21, 28, 3, "w", "v", 0.4))

// Steel palisade 2 x 1.5 m: round bars with spear/scroll tops (alpha between bars).
sprite("fence_palisade", { w: 32, h: 24 },
  (c) => {
    for (let x = 1; x < 32; x += 4) {
      c.vline(x, 3, 21, "M"); c.vline(x + 1, 3, 21, "m")
      c.px(x, 2, "M"); c.px(x + 1, 2, "M"); c.px(x, 1, "M")
    }
  },
  rect(0, 6, 32, 1, "N"), rect(0, 20, 32, 1, "N"),
  (c) => { for (let x = 3; x < 32; x += 8) { c.ring(x, 13, 2, "m") } })

// ------------------------------------------------------------------ roofs
// Concrete roof tiles: courses with offset joints and a shadow under each lap.
sprite("roof_tiles", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "t"),
  (c) => {
    for (let row = 0; row < 4; row++) {
      const y = row * 8, off = (row % 2) * 4
      // concrete tiles weather unevenly: a few lighter (new) and darker (old, damp) ones
      for (let x = off; x < 32 + 8; x += 8) {
        const k = (row * 7 + x * 3) % 11
        if (k === 0) c.rect((x % 32) + 1, y + 1, 7, 6, "y")
        if (k === 4) c.rect((x % 32) + 1, y + 1, 7, 6, "T")
      }
      c.hline(0, y + 7, 32, "T"); c.hline(0, y, 32, "y")
      for (let x = off; x < 32; x += 8) c.vline(x, y + 1, 6, "T")
    }
  })

// IBR corrugated sheeting: trapezoidal ribs every 0.5 m, rust run under one fixing.
sprite("roof_ibr", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "i"),
  (c) => { for (let x = 0; x < 32; x += 8) { c.vline(x, 0, 32, "j"); c.vline(x + 1, 0, 32, "j"); c.vline(x + 2, 0, 32, "I") } },
  px(5, 9, "R"), vline(5, 10, 5, "T"), px(21, 25, "R"), vline(21, 26, 4, "T"))

// ------------------------------------------------------------------ ground
// Sun-bleached Cape Flats asphalt, 4 m tile: granular aggregate (so sparse speckle is justified)
// and two cracks sealed with black tar (cause: maintenance crews pour sealant along cracks).
pal({ "7": "#77746f", "8": "#68655f", "9": "#8a8781", "+": "#3a3836" })
sprite("road_asphalt", { w: 64, h: 64 },
  rect(0, 0, 64, 64, "7"), noise(0, 0, 64, 64, "89", 0.10, 7), noise(0, 0, 64, 64, "8", 0.05, 21),
  line(6, 60, 14, 47, "+"), line(14, 47, 19, 45, "+"), line(19, 45, 22, 38, "+"),
  line(41, 9, 47, 15, "+"), line(47, 15, 58, 17, "+"))

// Sidewalk: 1 m square concrete slabs with expansion joints.
sprite("sidewalk", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "p"),
  hline(0, 0, 32, "P"), hline(0, 16, 32, "P"), vline(0, 0, 32, "P"), vline(16, 0, 32, "P"),
  hline(1, 1, 15, "q"), hline(17, 17, 15, "q"),
  line(20, 4, 26, 9, "P"))                                    // one cracked slab

// Street verge: trodden, compacted sand (darker and greyer than a yard) with clumps of kikuyu grass
// surviving where feet and tyres don't reach. 2 m tile.
pal({ "!": "#b9a57e", "%": "#a8946c", "&": "#c9b68c", "=": "#7f9a4c", "~": "#647f3c", "^": "#9fae62" })
sprite("_tuft", { w: 5, h: 4 }, `
  .=.^.
  ~=^=.
  =~=~^
  .~=~.`)
sprite("_tuft_s", { w: 3, h: 3 }, `
  ^=.
  =~=
  .~.`)
sprite("verge", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "!"), noise(0, 0, 32, 32, "%&", 0.12, 5),
  stamp("_tuft", 3, 4), stamp("_tuft", 20, 22), stamp("_tuft_s", 25, 6), stamp("_tuft_s", 9, 25), stamp("_tuft_s", 14, 14))

// Cape Flats sand: granular, so sparse speckle is justified.
sprite("yard_sand", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "z"), noise(0, 0, 32, 32, "ZxX", 0.14, 11))

// Clay paving bricks (driveway, photo 1): stretcher bond.
sprite("paving_brick", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "r"),
  (c) => {
    for (let row = 0; row < 8; row++) {
      const y = row * 4, off = (row % 2) * 4
      c.hline(0, y + 3, 32, "R"); c.hline(0, y, 32, "o")
      for (let x = off; x < 32; x += 8) c.vline(x, y, 3, "R")
    }
  })

// ------------------------------------------------------------------ signs
sprite("sign_shop", { w: 80, h: 16 },
  rect(0, 0, 80, 16, "f"), box(0, 0, 80, 16, "F"), hline(1, 1, 78, "l"),
  text(40, 4, "WESTRIDGE CAFE", "W", { align: "c" }), text(40, 10, "BREAD  AIRTIME", "l", { align: "c" }))

sprite("sign_garage", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "f"), box(0, 0, 64, 16, "F"), hline(1, 1, 62, "l"),
  text(32, 3, "DUIN GARAGE", "W", { align: "c" }), text(32, 9, "SHOP  OPEN 24H", "l", { align: "c" }))

// Fuel price board on the forecourt pylon: header, three prices (fictional pump brand).
sprite("sign_fuel_prices", { w: 56, h: 40 },
  rect(0, 0, 56, 40, "f"), box(0, 0, 56, 40, "F"), rect(1, 1, 54, 9, "l"),
  text(28, 3, "DUIN FUEL", "k", { align: "c" }),
  text(4, 13, "ULP95", "W"), text(52, 13, "24.10", "l", { align: "r" }),
  text(4, 22, "ULP93", "W"), text(52, 22, "23.60", "l", { align: "r" }),
  text(4, 31, "DIESEL", "W"), text(52, 31, "22.80", "l", { align: "r" }))

sprite("sign_taxi_rank", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "l"), box(0, 0, 64, 16, "k"), hline(1, 1, 62, "L"),
  text(32, 3, "TAXI RANK", "k", { align: "c" }), text(32, 9, "TO TOWN", "k", { align: "c" }))

// Timetable on the back wall of a bus shelter: header and four departures.
sprite("sign_timetable", { w: 28, h: 32 },
  rect(0, 0, 28, 32, "W"), box(0, 0, 28, 32, "B"), rect(1, 1, 26, 8, "B"),
  text(14, 3, "BUS", "W", { align: "c" }),
  text(14, 11, "06:10", "k", { align: "c" }), text(14, 18, "07:25", "k", { align: "c" }),
  text(14, 25, "12:40", "k", { align: "c" }))

// Words painted on the road at a stop bay, stretched along the road like STOP: the top is the far end.
sprite("bay_taxi", { w: 32, h: 16 },
  text(16, 5, "TAXI", "#f1eee8", { align: "c" }))
sprite("bay_bus", { w: 32, h: 16 },
  text(16, 5, "BUS", "#f1eee8", { align: "c" }))

sprite("sign_clinic", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "W"), box(0, 0, 64, 16, "f"), hline(1, 1, 62, "f"),
  rect(5, 3, 3, 9, "f"), rect(2, 6, 9, 3, "f"),
  text(38, 3, "WESTRIDGE", "f", { align: "c" }), text(38, 9, "CLINIC", "f", { align: "c" }))

sprite("sign_creche", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "l"), box(0, 0, 64, 16, "#d64541"), hline(1, 1, 62, "L"),
  rect(4, 4, 4, 4, "#2e86c1"), rect(10, 4, 4, 4, "#d64541"), rect(16, 4, 4, 4, "f"),
  text(42, 3, "CRECHE", "k", { align: "c" }), text(42, 9, "PRE-SCHOOL", "k", { align: "c" }))

// Opening hours board beside a clinic door.
sprite("sign_clinic_hours", { w: 24, h: 32 },
  rect(0, 0, 24, 32, "W"), box(0, 0, 24, 32, "f"), rect(1, 1, 22, 7, "f"),
  text(12, 2, "OPEN", "W", { align: "c" }),
  text(12, 11, "DAILY", "k", { align: "c" }), text(12, 18, "07:00", "k", { align: "c" }), text(12, 25, "16:00", "k", { align: "c" }))

// AMBULANCE painted in the bay in front of a clinic, stretched along the bay like STOP: the top is the far end.
sprite("bay_ambulance", { w: 48, h: 16 },
  text(24, 5, "AMBULANCE", "#f1eee8", { align: "c" }))

// ---- Places of worship. Arched windows in a stone surround (opaque, so no alpha is needed).
sprite("window_stained", { w: 16, h: 32 },
  rect(0, 0, 16, 32, "#d8d3c8"), rect(2, 8, 12, 22, "#2a2f4a"), circ(8, 9, 6, "#2a2f4a"),
  rect(3, 9, 4, 6, "#2f6fb8"), rect(9, 9, 4, 6, "#c8392f"), rect(3, 16, 4, 6, "#e0b02a"), rect(9, 16, 4, 6, "#3f8a4a"),
  rect(3, 23, 4, 6, "#c8392f"), rect(9, 23, 4, 6, "#2f6fb8"), circ(8, 6, 3, "#e0b02a"),
  rect(7, 3, 2, 26, "#2a2f4a"), hline(3, 15, 10, "#2a2f4a"), hline(3, 22, 10, "#2a2f4a"))

sprite("rose_window", { w: 24, h: 24 },
  rect(0, 0, 24, 24, "#d8d3c8"), circ(12, 12, 10, "#2a2f4a"), circ(12, 12, 8, "#2f6fb8"),
  circ(12, 12, 4, "#e0b02a"), rect(11, 3, 2, 18, "#2a2f4a"), rect(3, 11, 18, 2, "#2a2f4a"),
  circ(12, 12, 2, "#c8392f"))

sprite("door_church", { w: 16, h: 24 },
  rect(0, 0, 16, 24, "#d8d3c8"), rect(1, 2, 14, 22, "#5a3a26"), circ(8, 4, 7, "#5a3a26"),
  rect(7, 1, 2, 23, "#2e1c10"), rect(3, 8, 4, 14, "#6b4630"), rect(9, 8, 4, 14, "#6b4630"),
  px(6, 15, "#e0b02a"), px(9, 15, "#e0b02a"))

sprite("window_arch", { w: 16, h: 32 },
  rect(0, 0, 16, 32, "#f1eee8"), rect(2, 8, 12, 22, "#1f4a3a"), circ(8, 9, 6, "#1f4a3a"),
  rect(3, 9, 10, 20, "#2f6a52"), circ(8, 10, 5, "#2f6a52"), rect(7, 5, 2, 24, "#f1eee8"),
  hline(3, 17, 10, "#f1eee8"), hline(3, 23, 10, "#f1eee8"))

sprite("sign_church", { w: 64, h: 24 },
  rect(0, 0, 64, 24, "#f1eee8"), box(0, 0, 64, 24, "#2f4a8a"), rect(4, 3, 2, 8, "#2f4a8a"), rect(2, 5, 6, 2, "#2f4a8a"),
  text(38, 3, "ALL WELCOME", "#2f4a8a", { align: "c" }),
  text(38, 10, "SUNDAYS", "#2f4a8a", { align: "c" }), text(38, 16, "09:00", "#2f4a8a", { align: "c" }))

sprite("sign_mosque", { w: 64, h: 24 },
  rect(0, 0, 64, 24, "#f1eee8"), box(0, 0, 64, 24, "#1f6a4a"), circ(8, 8, 4, "#1f6a4a"), circ(10, 7, 3, "#f1eee8"),
  text(38, 3, "MASJID", "#1f6a4a", { align: "c" }),
  text(38, 10, "FRIDAYS", "#1f6a4a", { align: "c" }), text(38, 16, "13:00", "#1f6a4a", { align: "c" }))

// ---- Community halls.
sprite("sign_civic", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "#2f4a8a"), box(0, 0, 64, 16, "#f1eee8"), hline(1, 1, 62, "#e0b02a"),
  text(32, 3, "WESTRIDGE", "#f1eee8", { align: "c" }), text(32, 9, "CIVIC CENTRE", "#e0b02a", { align: "c" }))

sprite("sign_sports_hall", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "f"), box(0, 0, 64, 16, "F"), hline(1, 1, 62, "l"),
  text(32, 3, "SPORTS HALL", "W", { align: "c" }), text(32, 9, "BOOK NOW", "l", { align: "c" }))

sprite("sign_events", { w: 48, h: 32 },
  rect(0, 0, 48, 32, "#f1eee8"), box(0, 0, 48, 32, "#2f4a8a"), rect(1, 1, 46, 8, "#2f4a8a"),
  text(24, 3, "EVENTS", "#f1eee8", { align: "c" }),
  text(24, 12, "BINGO FRI", "#1d1b24", { align: "c" }), text(24, 19, "SOCCER SAT", "#1d1b24", { align: "c" }),
  text(24, 26, "CHOIR SUN", "#1d1b24", { align: "c" }))

sprite("door_hall", { w: 24, h: 24 },
  rect(0, 0, 24, 24, "#c2bdb3"), rect(1, 1, 22, 23, "#3b4a5a"), rect(11, 1, 2, 23, "#2a2f3a"),
  rect(2, 3, 9, 9, "#7f9fb8"), rect(13, 3, 9, 9, "#7f9fb8"), rect(2, 14, 9, 9, "#4a5a6a"), rect(13, 14, 9, 9, "#4a5a6a"),
  rect(8, 13, 1, 4, "#c9c9c4"), rect(15, 13, 1, 4, "#c9c9c4"))

sprite("sign_bus", { w: 16, h: 16 },
  rect(0, 0, 16, 16, "l"), box(0, 0, 16, 16, "L"), text(8, 2, "BUS", "k", { align: "c" }),
  rect(3, 9, 10, 4, "k"), px(4, 13, "k"), px(11, 13, "k"), rect(4, 10, 3, 2, "C"), rect(9, 10, 3, 2, "C"))

sprite("sign_locked", { w: 64, h: 24 },
  rect(0, 0, 64, 24, "l"), box(0, 0, 64, 24, "k"),
  (c) => { for (let x = -24; x < 64; x += 8) c.line(x, 23, x + 4, 19, "k", 2) },
  text(32, 3, "ROAD CLOSED", "k", { align: "c" }), text(32, 10, "LOCKED TURF", "T", { align: "c" }))

// ------------------------------------------------------------------ Phase 4.5 detail pass
pal({ E: "#e2585e", H: "#2e86c1", S: "#f1d36b" })

// Washing on a line (2 m x 1 m): shirts, a towel and socks pegged to the top edge.
sprite("_shirt", `
  ..aaaa..
  aaaaaaaa
  aaaaaaaa
  .aaaaaa.
  .aaaaaa.
  .aaaaaa.
  .aaaaaa.`)
sprite("washing", { w: 32, h: 16 },
  stamp("_shirt", 1, 1, { swap: { a: "E" } }),
  rect(11, 1, 6, 10, "H"), hline(11, 9, 6, "W"), hline(11, 10, 6, "H"),
  stamp("_shirt", 19, 1, { swap: { a: "S" } }),
  rect(28, 1, 2, 5, "W"), rect(28, 5, 3, 1, "W"),
  (c) => { for (const x of [3, 6, 12, 16, 21, 24, 29]) c.px(x, 0, "d") })

// Wendy house wall (2 m tile): painted corrugated sheeting with a rust run under a fixing.
sprite("wendy_wall", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "w"),
  (c) => { for (let x = 0; x < 32; x += 4) { c.vline(x, 0, 32, "W"); c.vline(x + 2, 0, 32, "v") } },
  hline(0, 8, 32, "V"), hline(0, 24, 32, "V"),
  px(9, 8, "R"), vline(9, 9, 6, "T"), px(25, 24, "R"), vline(25, 25, 4, "T"))

// Crew tag (fictional "TORTEL"): sprayed letters with an outline and drips.
sprite("tag_tortel", { w: 48, h: 20 },
  text(24, 5, "TORTEL", "H", { align: "c", scale: 2, gap: 1 }),
  (c) => {
    // outline the letters in black, then drip a few runs down from the paint
    const keep = []
    for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) if (c.is(x, y, "H")) keep.push([x, y])
    for (const [x, y] of keep) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (!c.is(x + dx, y + dy, "H")) c.px(x + dx, y + dy, "k")
    for (const x of [8, 19, 30, 41]) { c.vline(x, 16, 3, "H") }
  })

// Café poster (0.6 x 0.9 m).
sprite("poster_cafe", { w: 22, h: 24 },
  rect(0, 0, 22, 24, "W"), box(0, 0, 22, 24, "V"),
  rect(1, 1, 20, 7, "E"), text(11, 2, "HOT", "W", { align: "c" }),
  text(11, 10, "BREAD", "k", { align: "c" }),
  text(11, 17, "R12", "f", { align: "c" }))

// ------------------------------------------------------------------ Phase 7: Lentegeur
pal({ J: "#c8714a", K: "#a85a3a", O: "#dd8a5e", U: "#8e4a30", Q: "#d64541", Y: "#2b6fb5" })

// Red dune sand: granular (sparse speckle is the material itself), with a few wind ripples.
sprite("sand_red", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "J"), noise(0, 0, 32, 32, "KOU", 0.12, 17),
  line(2, 9, 12, 7, "O"), line(17, 22, 29, 20, "O"), line(5, 27, 11, 26, "K"))

// Shipping container side (2 m tile, tintable): vertical corrugation, top rail, rust runs.
sprite("container_wall", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "w"),
  (c) => { for (let x = 0; x < 32; x += 4) { c.vline(x, 0, 32, "W"); c.vline(x + 1, 0, 32, "W"); c.vline(x + 3, 0, 32, "V") } },
  rect(0, 0, 32, 2, "V"), hline(0, 2, 32, "u"),
  vline(6, 3, 7, "T"), px(6, 2, "R"), vline(22, 3, 4, "T"), px(22, 2, "R"), dither(0, 29, 32, 3, "w", "V", 0.4))

sprite("sign_barber", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "k"), box(0, 0, 64, 16, "M"),
  (c) => { for (let y = -8; y < 16; y += 4) c.line(2, y, 8, y + 6, "Q", 2) },
  rect(2, 1, 1, 14, "W"), rect(8, 1, 1, 14, "W"),
  text(36, 3, "KINGS", "S", { align: "c" }), text(36, 9, "CUTS", "W", { align: "c" }))

sprite("sign_spaza", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "Y"), box(0, 0, 64, 16, "B"), hline(1, 1, 62, "C"),
  text(32, 3, "DUIN SPAZA", "W", { align: "c" }), text(32, 9, "COLD DRINKS", "S", { align: "c" }))

sprite("sign_taxi", { w: 16, h: 16 },
  rect(0, 0, 16, 16, "W"), box(0, 0, 16, 16, "k"), text(8, 2, "TAXI", "k", { align: "c" }),
  rect(2, 9, 12, 4, "W"), box(2, 9, 12, 4, "k"), rect(4, 10, 2, 2, "C"), rect(7, 10, 2, 2, "C"), rect(10, 10, 2, 2, "C"),
  px(4, 13, "k"), px(11, 13, "k"))

// Fictional rival crew tag (Lentegeur).
sprite("tag_duin", { w: 48, h: 20 },
  text(24, 2, "DUNE", "Q", { align: "c", scale: 2, gap: 1 }),
  text(24, 14, "CRUISERS", "W", { align: "c" }),
  (c) => {
    const keep = []
    for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) if (c.is(x, y, "QW")) keep.push([x, y])
    for (const [x, y] of keep) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (!c.is(x + dx, y + dy, "QW")) c.px(x + dx, y + dy, "k")
    for (const x of [12, 25, 35]) c.vline(x, 12, 2, "Q")
  })

// ------------------------------------------------------------------ Rocklands (limestone quarry)
pal({ "0": "#e9e4d6", "1": "#d6cfbd", "2": "#bdb5a1", "3": "#a39b88", "4": "#f6f2e8", "5": "#2a2a30", "6": "#3d6e8f" })

// Chalky ground: granular limestone grit (speckle is the material), a few stone chips.
sprite("chalk_ground", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "0"), noise(0, 0, 32, 32, "123", 0.1, 23),
  rect(6, 11, 2, 1, "3"), rect(21, 4, 3, 2, "2"), rect(14, 25, 2, 2, "3"))

// Dry-stone limestone wall (2 m tile, tintable): irregular courses, offset joints, mortar lines.
sprite("limestone_wall", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "4"),
  (c) => {
    const rows = [0, 6, 11, 17, 22, 27, 32]
    for (let r = 0; r < rows.length - 1; r++) {
      const y = rows[r], h = rows[r + 1] - rows[r]
      c.hline(0, y, 32, "2")
      const off = (r * 7) % 11
      for (let x = off; x < 32; x += 9 + (r % 3) * 2) c.vline(x, y, h, "2")
      c.hline(1, y + 1, 30, "0")
    }
  },
  dither(0, 29, 32, 3, "4", "1", 0.35))

sprite("sign_hall", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "5"), box(0, 0, 64, 16, "3"),
  text(32, 3, "ROCKLANDS", "4", { align: "c" }), text(32, 9, "CHURCH HALL", "S", { align: "c" }))

sprite("sign_fish", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "6"), box(0, 0, 64, 16, "B"),
  text(34, 3, "VIS EN TJIPS", "W", { align: "c" }), text(32, 9, "FRESH SNOEK", "S", { align: "c" }),
  rect(3, 6, 6, 3, "C"), px(9, 6, "C"), px(9, 8, "C"), px(4, 7, "5"))

sprite("sign_quarry", { w: 48, h: 16 },
  rect(0, 0, 48, 16, "S"), box(0, 0, 48, 16, "5"),
  text(24, 3, "DANGER", "Q", { align: "c" }), text(24, 9, "QUARRY", "5", { align: "c" }))

sprite("tag_klip", { w: 48, h: 20 },
  text(24, 2, "ROCK", "6", { align: "c", scale: 2, gap: 1 }),
  text(24, 14, "ROYALS", "4", { align: "c" }),
  (c) => {
    const keep = []
    for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) if (c.is(x, y, "64")) keep.push([x, y])
    for (const [x, y] of keep) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (!c.is(x + dx, y + dy, "64")) c.px(x + dx, y + dy, "k")
  })

sprite("tag_vlakte", { w: 48, h: 20 },
  text(24, 2, "SPINE", "#d94f9c", { align: "c", scale: 2, gap: 1 }),
  text(24, 14, "STYLERS", "#f1d36b", { align: "c" }),
  (c) => {
    const keep = []
    for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) if (!c.is(x, y, ".")) keep.push([x, y])
    for (const [x, y] of keep) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (c.is(x + dx, y + dy, ".")) c.px(x + dx, y + dy, "k")
  })

// Police crest (made up, SAPS-inspired colours; deliberately not the real emblem): blue shield,
// yellow rim, yellow chevron and a white "P".
sprite("police_crest", { w: 17, h: 20 },
  poly([0, 0, 16, 0, 16, 12, 8, 19, 0, 12], "#f5c400"),
  poly([1, 1, 15, 1, 15, 11, 8, 17, 1, 11], "#123f8c"),
  poly([2, 9, 8, 13, 14, 9, 14, 11, 8, 15, 2, 11], "#f5c400"),
  text(8, 2, "P", "#ffffff", { align: "c" }))

// Mobile police post sign (SAPS-inspired, made-up crest).
sprite("sign_police", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "#123f8c"), rect(0, 13, 64, 1, "#f5c400"),
  poly([2, 2, 12, 2, 12, 9, 7, 13, 2, 9], "#f5c400"), poly([3, 3, 11, 3, 11, 8, 7, 12, 3, 8], "#123f8c"),
  text(7, 3, "P", "#ffffff", { align: "c" }),
  text(38, 2, "POLICE", "#ffffff", { align: "c" }), text(38, 8, "POLISIE", "#f5c400", { align: "c" }))

// Client mood faces for the phone and over clients' heads (16x16, outlined).
const MOODS = {
  mood_happy: ["#5fd36b", (c) => { c.line(4, 9, 6, 11, "#10301a"); c.line(6, 11, 9, 11, "#10301a"); c.line(9, 11, 11, 9, "#10301a") }],
  mood_ok:    ["#d9e05a", (c) => { c.line(5, 10, 10, 10, "#33300a"); c.px(4, 9, "#33300a"); c.px(11, 9, "#33300a") }],
  mood_meh:   ["#f0a33a", (c) => { c.line(5, 10, 10, 10, "#3a2208") }],
  mood_angry: ["#e2463c", (c) => { c.line(5, 11, 7, 10, "#3a0b08"); c.line(8, 10, 10, 11, "#3a0b08"); c.line(4, 4, 6, 5, "#3a0b08"); c.line(11, 4, 9, 5, "#3a0b08") }],
  mood_lost:  ["#8a8f99", (c) => { c.line(5, 10, 10, 10, "#22252b"); c.line(11, 2, 14, 5, "#22252b"); c.line(14, 2, 11, 5, "#22252b") }],
}
for (const [name, [col, mouth]] of Object.entries(MOODS)) {
  sprite(name, { w: 16, h: 16 },
    circ(7, 7, 7, "#1d1b24"), circ(7, 7, 6, col),
    rect(5, 5, 1, 2, "#1d1b24"), rect(9, 5, 1, 2, "#1d1b24"), mouth)
}

// Phone, stock icons.
sprite("icon_phone", { w: 12, h: 16 },
  rect(1, 0, 10, 16, "#1d1b24"), rect(2, 2, 8, 10, "#7fd1ff"), rect(5, 13, 2, 1, "#8a8f99"))
sprite("icon_bankie", { w: 12, h: 12 },
  rect(2, 3, 8, 8, "#e9f2df"), rect(2, 3, 8, 1, "#9fb59a"), rect(4, 6, 4, 3, "#4f8a3c"))
sprite("icon_drink", { w: 8, h: 14 },
  rect(3, 0, 2, 4, "#5a3c1c"), rect(2, 4, 4, 10, "#7a4a1c"), rect(2, 7, 4, 3, "#f1e2b4"))
sprite("sign_shebeen", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "#2a2a30"), rect(0, 14, 64, 2, "#e2585e"),
  text(32, 2, "AUNTY MAVIS", "#ffd75e", { align: "c" }), text(32, 8, "COLD DRINKS", "#f4f4f0", { align: "c" }))

// ------------------------------------------------------------------ aunty house-dress prints
// Seamless 16x16 cotton prints for house dresses and maxis (mapped onto the dress in object
// space, ~20 cm per repeat). A base colour, two flowers (petals P, centre C) and leaf pairs.
sprite("_flower", { w: 5, h: 5 }, `
  .PPP.
  PPCPP
  PCCCP
  PPCPP
  .PPP.`)
sprite("_bud", { w: 3, h: 3 }, `
  .P.
  PCP
  .P.`)
sprite("_leaf", { w: 3, h: 2 }, `
  .LL
  LL.`)
const PRINTS = {
  //            base       petals     centre     leaf       bud petals
  print_rose:  ["#e86a8a", "#fff3f0", "#f2c43a", "#3f8a4a", "#b8325a"],
  print_blue:  ["#2f6db8", "#fdf6e3", "#f2c43a", "#7fc3e8", "#f4f4f0"],
  print_sun:   ["#f2b632", "#d9442e", "#5a2a14", "#4f8a3c", "#fff3d6"],
  print_teal:  ["#159a8c", "#f6e7c8", "#e2585e", "#0d5f57", "#f2c43a"],
  print_lilac: ["#9a6cc4", "#ffffff", "#f2c43a", "#5b9a5a", "#f4a6c8"],
}
for (const [name, [base, petal, centre, leaf, bud]] of Object.entries(PRINTS)) {
  const sw = { P: petal, C: centre, L: leaf }
  sprite(name, { w: 16, h: 16 },
    rect(0, 0, 16, 16, base),
    stamp("_flower", 1, 1, { swap: sw }), stamp("_flower", 9, 9, { swap: sw }),
    stamp("_bud", 11, 2, { swap: { P: bud, C: centre } }), stamp("_bud", 2, 11, { swap: { P: bud, C: centre } }),
    stamp("_leaf", 6, 5, { swap: sw }), stamp("_leaf", 13, 13, { swap: sw, flip: "x" }),
    stamp("_leaf", 6, 13, { swap: sw }), stamp("_leaf", 13, 6, { swap: sw, flip: "x" }))
}

// ------------------------------------------------------------------ painted faces
// 40x40 overlays on the face shell (front projection, 5 mm per pixel; eyes at (12.8, 14.4) and
// (27.2, 14.4), mouth at (20, 29)). Godot multiplies them by the skin colour, so greys darken
// and pinks warm any skin tone. Transparent elsewhere (the modelled eyes, nose and brows show).
function face(name, o) {
  sprite(name, { w: 40, h: 40 }, (c) => {
    const both = (x, y, col) => { c.px(x, y, col); c.px(39 - x, y, col) }
    const row = (y, x0, x1, col) => { for (let x = x0; x <= x1; x++) both(x, y, col) }
    const lid = "#3a302c", soft = "#9a8a84", line = "#7d6c66"
    // upper lids (outer corner at the image edge side), lower lash line
    row(12, 10, 15, lid); both(9, 13, lid); both(16, 13, lid)
    if (o.lashes) { row(11, 10, 14, lid); both(8, 12, lid); both(7, 11, lid) }
    if (o.old) {
      row(17, 11, 14, soft)                                   // bags under the eyes
      both(7, 13, line); both(7, 15, line); both(6, 14, line)  // crow's feet
      row(5, 14, 19, soft); row(7, 15, 19, soft)              // forehead lines
      both(15, 25, line); both(14, 26, line); both(14, 27, line)  // smile lines
    }
    // nostrils, philtrum, lips, chin
    both(18, 25, "#4a3a36"); c.px(19, 26, "#a89088"); c.px(20, 26, "#a89088")
    const up = o.lips ? "#a8605c" : "#ae7c74", low = o.lips ? "#c27a74" : "#bf8e86"
    if (o.lips) { row(28, 15, 19, up); both(17, 27, up); both(18, 27, up) }
    row(29, 16, 19, "#5a3a36")
    row(30, 16, 19, low); if (o.lips) row(31, 17, 19, low)
    row(34, 18, 19, "#b8a098")
    if (o.blush) { for (const y of [21, 22]) row(y, 9, 10, "#f0c8c0") }
    if (o.stubble) {
      for (let y = 25; y <= 37; y++) for (let x = 8; x <= 19; x++) {
        const lips = y >= 27 && y <= 31 && x >= 15
        const jaw = y >= 32 || x <= 12 || x >= 14
        if (!lips && jaw && (x * x * 7 + y * 31 + x * y * 3) % 7 === 0 && !(y < 27 && x > 13)) both(x, y, "#9a908a")
      }
    }
  })
}
face("face_m", {})
face("face_f", { lashes: true, lips: true })
face("face_old_m", { old: true })
face("face_old_f", { old: true, lashes: true, lips: true })
face("face_stubble", { stubble: true })

// Denim twill (tinted by the trouser colour) and tracksuit side stripes (a mask: white = stripe).
sprite("denim", { w: 16, h: 16 }, (c) => {
  c.rect(0, 0, 16, 16, "#ffffff")
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
    if ((x + y) % 4 === 0) c.px(x, y, "#d4d8de")
    else if ((x + y) % 4 === 2 && (x * 3 + y) % 5 === 0) c.px(x, y, "#e8ebee")
  }
  c.hline(0, 15, 16, "#c8ccd2")
})
sprite("tracksuit_stripes", { w: 32, h: 4 },
  rect(0, 0, 32, 4, "#000000"), rect(13, 0, 2, 4, "#ffffff"), rect(17, 0, 2, 4, "#ffffff"))

// Crew cap logos (12x12, outlined): Tortel (shell), Stylers (S), Dune Cruisers (wave), Rock Royals (crown).
sprite("logo_tortel_crew", { w: 12, h: 12 },
  circ(5, 6, 5, "#1d1b24"), circ(5, 6, 4, "#f4f4f0"), rect(3, 4, 2, 2, "#1d1b24"), rect(6, 4, 2, 2, "#1d1b24"), rect(4, 7, 3, 2, "#1d1b24"))
sprite("logo_vlakte_vipers", { w: 12, h: 12 },
  rect(0, 0, 12, 12, "#1d1b24"), rect(3, 2, 6, 2, "#f4f4f0"), rect(3, 2, 2, 4, "#f4f4f0"), rect(3, 5, 6, 2, "#f4f4f0"),
  rect(7, 5, 2, 4, "#f4f4f0"), rect(3, 8, 6, 2, "#f4f4f0"))
sprite("logo_duin_boys", { w: 12, h: 12 },
  rect(0, 0, 12, 12, "#1d1b24"), line(1, 8, 4, 4, "#f2c43a"), line(4, 4, 7, 7, "#f2c43a"), line(7, 7, 10, 3, "#f2c43a"), rect(1, 9, 10, 1, "#f4f4f0"))
sprite("logo_klipspringers", { w: 12, h: 12 },
  rect(0, 0, 12, 12, "#1d1b24"), rect(2, 5, 8, 4, "#f2c43a"), px(2, 3, "#f2c43a"), px(2, 4, "#f2c43a"), px(5, 2, "#f2c43a"),
  rect(5, 3, 2, 2, "#f2c43a"), px(9, 3, "#f2c43a"), px(9, 4, "#f2c43a"))

// ------------------------------------------------------------------ interiors
// Floor lino (the classic speckled-tile vinyl), a lounge rug, pictures, posters, a clock and
// the window as seen from inside (frame, burglar bars, daylight).
sprite("floor_lino", { w: 16, h: 16 },
  rect(0, 0, 16, 16, "#e8dcc4"), rect(0, 0, 8, 8, "#c9a27a"), rect(8, 8, 8, 8, "#c9a27a"),
  hline(0, 0, 16, "#b8946c"), vline(0, 0, 16, "#b8946c"), hline(0, 8, 16, "#b8946c"), vline(8, 0, 16, "#b8946c"),
  px(3, 3, "#a8845c"), px(5, 6, "#a8845c"), px(11, 12, "#a8845c"), px(13, 10, "#a8845c"),
  px(11, 3, "#d4c4a6"), px(3, 12, "#d4c4a6"))
sprite("floor_boards", { w: 16, h: 16 },
  rect(0, 0, 16, 16, "#8c6044"), hline(0, 3, 16, "#6b4630"), hline(0, 7, 16, "#6b4630"), hline(0, 11, 16, "#6b4630"),
  hline(0, 15, 16, "#6b4630"), vline(5, 0, 3, "#6b4630"), vline(12, 4, 3, "#6b4630"), vline(3, 8, 3, "#6b4630"), vline(9, 12, 3, "#6b4630"))
sprite("rug", { w: 32, h: 20 },
  rect(0, 0, 32, 20, "#a63a4c"), rect(2, 2, 28, 16, "#e8d8b2"), rect(4, 4, 24, 12, "#a63a4c"),
  rect(8, 7, 16, 6, "#2f4a6e"), rect(14, 8, 4, 4, "#e8d8b2"),
  (c) => { for (let x = 0; x < 32; x += 2) { c.px(x, 0, "#e8d8b2"); c.px(x + 1, 19, "#e8d8b2") } })
sprite("frame_family", { w: 24, h: 18 },
  rect(0, 0, 24, 18, "#6b4630"), rect(2, 2, 20, 14, "#c9d8e0"), rect(2, 11, 20, 5, "#9cb48a"),
  circ(7, 7, 2, "#4a2f22"), rect(5, 9, 5, 5, "#a63a4c"), circ(12, 6, 2, "#6b4430"), rect(10, 8, 5, 6, "#2f6db8"),
  circ(17, 8, 2, "#8d5a3b"), rect(15, 10, 4, 4, "#f2b632"))
sprite("frame_mountain", { w: 24, h: 16 },
  rect(0, 0, 24, 16, "#d4a63a"), rect(2, 2, 20, 12, "#8fc0e0"), rect(2, 10, 20, 4, "#2f6db8"),
  poly([2, 10, 6, 6, 9, 5, 15, 5, 18, 7, 22, 10], "#6d7f8f"), rect(2, 12, 20, 2, "#3f7fc4"))
sprite("sign_home", { w: 52, h: 16 },
  rect(0, 0, 52, 16, "#f4f1ea"), rect(0, 0, 52, 1, "#a63a4c"), rect(0, 15, 52, 1, "#a63a4c"),
  text(2, 2, "HOME SWEET", "#2f4a6e"), text(18, 9, "HOME", "#a63a4c"))
sprite("wall_clock", { w: 12, h: 12 },
  circ(5, 5, 5, "#1d1b24"), circ(5, 5, 4, "#f4f1ea"), vline(5, 2, 4, "#1d1b24"), hline(5, 5, 3, "#1d1b24"))
sprite("calendar", { w: 12, h: 16 },
  rect(0, 0, 12, 16, "#f4f1ea"), rect(0, 0, 12, 6, "#2f6e3a"), rect(2, 1, 8, 4, "#9cb48a"),
  (c) => { for (let y = 8; y < 15; y += 2) for (let x = 1; x < 11; x += 2) c.px(x, y, "#8a8f99") })
sprite("poster_cold", { w: 20, h: 28 },
  rect(0, 0, 20, 28, "#1f6b45"), rect(1, 1, 18, 26, "#2f8a5a"), text(2, 2, "COLD", "#f4f1ea"), text(2, 8, "ONES", "#f2c43a"),
  rect(8, 14, 4, 11, "#6b3a12"), rect(9, 12, 2, 3, "#6b3a12"), rect(8, 18, 4, 3, "#f1e2b4"))
sprite("poster_soccer", { w: 20, h: 28 },
  rect(0, 0, 20, 28, "#f4f1ea"), rect(0, 0, 20, 8, "#e2585e"), text(2, 1, "VLEI", "#f4f1ea"),
  circ(9, 16, 5, "#1d1b24"), circ(9, 16, 4, "#f4f1ea"), rect(8, 15, 3, 3, "#1d1b24"), text(5, 22, "FC", "#e2585e"))
sprite("poster_map", { w: 28, h: 20 },
  rect(0, 0, 28, 20, "#e8d8b2"), hline(0, 7, 28, "#8a8f99"), hline(0, 14, 28, "#8a8f99"), vline(9, 0, 20, "#8a8f99"), vline(19, 0, 20, "#8a8f99"),
  rect(2, 2, 5, 3, "#a63a4c"), rect(11, 9, 6, 4, "#2f6e3a"), rect(21, 16, 5, 3, "#2f6db8"),
  line(4, 4, 14, 11, "#1d1b24"), line(14, 11, 23, 17, "#1d1b24"), px(4, 4, "#e2585e"), px(23, 17, "#e2585e"))
sprite("window_inside", { w: 24, h: 20 },
  rect(0, 0, 24, 20, "#e8e2d6"), rect(2, 2, 20, 16, "#a7cde8"), rect(2, 12, 20, 6, "#c8dcc0"),
  vline(12, 2, 16, "#e8e2d6"), hline(2, 10, 20, "#e8e2d6"),
  (c) => { for (let x = 4; x < 22; x += 3) c.vline(x, 2, 16, "#3a3d46") })

// House smokkie signs (Lentegeur, Rocklands).
sprite("sign_doreen", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "#1d4a46"), rect(0, 14, 64, 2, "#f2b632"),
  text(32, 2, "DOREEN'S", "#f4f1ea", { align: "c" }), text(32, 8, "COLD DRINKS", "#f2b632", { align: "c" }))
sprite("sign_lena", { w: 64, h: 16 },
  rect(0, 0, 64, 16, "#3f2a4a"), rect(0, 14, 64, 2, "#d9442e"),
  text(32, 2, "MA LENA'S", "#f4f1ea", { align: "c" }), text(32, 8, "TAVERN", "#f2c43a", { align: "c" }))

// Town Centre: the mall sign.
sprite("sign_promenade", { w: 96, h: 16 },
  rect(0, 0, 96, 16, "#2e5c8a"), rect(0, 14, 96, 2, "#f2b632"),
  text(48, 4, "THE PROMENADE", "#f4f1ea", { align: "c" }))

// ------------------------------------------------------------------ street detail
// Litter (flat on the ground, alpha), road wear, drains, a speed hump, wall cracks and stains,
// a shop A-frame board and a danger sticker for transformer boxes.
sprite("litter_chips", { w: 8, h: 8 },
  rect(1, 1, 6, 6, "#e2585e"), rect(2, 2, 4, 2, "#f2c43a"), px(3, 5, "#f4f1ea"), px(4, 5, "#f4f1ea"), px(0, 3, "#b8323a"), px(7, 4, "#b8323a"))
sprite("litter_can", { w: 8, h: 8 },
  rect(1, 3, 6, 3, "#c9c9c4"), rect(2, 3, 3, 3, "#2f6db8"), rect(6, 3, 1, 3, "#8a8f99"))
sprite("litter_paper", { w: 8, h: 8 },
  poly([0, 2, 6, 0, 7, 5, 2, 7], "#ece8dc"), line(2, 3, 5, 2, "#a8a39a"), line(2, 5, 5, 4, "#a8a39a"))
sprite("litter_bottle", { w: 8, h: 8 },
  rect(1, 3, 5, 2, "#2f6a2a"), rect(6, 3, 2, 2, "#4f8a3c"), px(2, 3, "#7fb07a"))
sprite("pothole", { w: 16, h: 12 },
  ellipse(8, 6, 7, 5, "#2a2a2e"), ellipse(8, 6, 5, 3, "#1d1d20"), px(4, 3, "#8a8578"), px(11, 8, "#8a8578"), px(6, 9, "#6d6a62"))
sprite("tar_patch", { w: 16, h: 16 },
  rect(1, 2, 13, 11, "#2e2e33"), rect(2, 3, 11, 9, "#26262b"), line(1, 2, 14, 2, "#3b3b40"))
sprite("manhole", { w: 12, h: 12 },
  circ(5, 5, 5, "#3a3d46"), circ(5, 5, 4, "#565a64"), hline(2, 3, 7, "#3a3d46"), hline(2, 5, 7, "#3a3d46"), hline(2, 7, 7, "#3a3d46"))
sprite("drain_grate", { w: 16, h: 6 },
  rect(0, 0, 16, 6, "#1d1b24"), (c) => { for (let x = 1; x < 16; x += 2) c.vline(x, 1, 4, "#565a64") })
// Mitchells Plain speed hump: slanted white stripes (not straight across) on dark asphalt.
sprite("speed_hump", { w: 32, h: 8 },
  rect(0, 0, 32, 8, "#2b2b30"),
  (c) => { for (let x = -8; x < 36; x += 8) c.poly([x, 8, x + 4, 8, x + 12, 0, x + 8, 0], "#f1eee8") })
sprite("crack_a", { w: 24, h: 24 },
  line(2, 22, 7, 15, "#5a5550"), line(7, 15, 9, 9, "#5a5550"), line(9, 9, 14, 6, "#5a5550"), line(14, 6, 21, 1, "#5a5550"),
  line(9, 9, 5, 4, "#6d6862"), line(7, 15, 12, 17, "#6d6862"))
sprite("stain_rust", { w: 16, h: 32 },
  (c) => { for (let y = 0; y < 32; y++) { const w = 6 - Math.floor(y / 7); for (let x = 8 - w; x < 8 + w; x++) if ((x * 7 + y * 3) % 5 !== 0) c.px(x, y, y < 6 ? "#8a5a3c" : "#a8826a") } })
sprite("board_bread", { w: 36, h: 28 },
  rect(0, 0, 36, 28, "#1d1b24"), rect(1, 1, 34, 26, "#2b3a2e"),
  text(18, 3, "BREAD", "#f4f1ea", { align: "c" }), text(18, 10, "MILK", "#f2c43a", { align: "c" }), text(18, 17, "AIRTIME", "#7fd1ff", { align: "c" }))
sprite("danger_sticker", { w: 12, h: 12 },
  poly([6, 0, 12, 11, 0, 11], "#f2c43a"), poly([6, 2, 10, 10, 2, 10], "#1d1b24"), rect(5, 4, 2, 4, "#f2c43a"), px(5, 9, "#f2c43a"), px(6, 9, "#f2c43a"))

// Side panel of the (made-up) bakery delivery van.
sprite("van_bakery", { w: 64, h: 26 },
  rect(0, 0, 64, 26, "#f2f0ea"), rect(0, 16, 64, 8, "#c0392b"), rect(0, 24, 64, 1, "#f2c43a"),
  ellipse(10, 9, 7, 5, "#c98a3d"), ellipse(10, 8, 6, 3, "#e0a95a"), line(6, 8, 8, 6, "#8a5a24"), line(10, 8, 12, 6, "#8a5a24"), line(14, 9, 15, 7, "#8a5a24"),
  text(40, 2, "OUMA'S", "#c0392b", { align: "c" }), text(40, 9, "BAKERY", "#1d1b24", { align: "c" }),
  text(32, 17, "FRESH DAILY", "#f4f1ea", { align: "c" }))

// ---- Ground detail (Cape Flats: wind-blown sand, worn earth, tough grass, dune strandveld) ----
sprite("dirt_patch", { w: 32, h: 24 },
  ellipse(16, 12, 15, 10, "#c9ad7c"), ellipse(15, 12, 12, 7, "#b99d6c"), ellipse(17, 13, 6, 3, "#a98e5e"),
  px(8, 8, "#8a8578"), px(22, 16, "#8a8578"), px(12, 17, "#a8a296"), px(25, 9, "#a8a296"))
sprite("grass_patch", { w: 32, h: 24 },
  ellipse(16, 12, 15, 10, "#98ad5c"), ellipse(16, 12, 11, 7, "#86a04f"),
  line(6, 14, 7, 11, "#c9b66a"), line(11, 16, 12, 12, "#6f8a3f"), line(16, 9, 17, 6, "#c9b66a"), line(20, 15, 21, 11, "#6f8a3f"),
  line(24, 11, 25, 8, "#c9b66a"), line(14, 18, 15, 15, "#6f8a3f"))
sprite("sand_ripple", { w: 32, h: 16 },
  line(2, 3, 12, 2, "#e6d3a0"), line(14, 2, 26, 4, "#e6d3a0"), line(0, 8, 9, 9, "#cdb67d"), line(11, 9, 22, 8, "#e6d3a0"),
  line(23, 8, 31, 9, "#cdb67d"), line(4, 13, 16, 12, "#e6d3a0"), line(18, 12, 28, 13, "#cdb67d"))
sprite("sand_drift", { w: 32, h: 12 },
  poly([0, 11, 4, 5, 12, 2, 22, 3, 30, 7, 32, 11], "#d9c590"), poly([2, 11, 6, 6, 13, 4, 21, 5, 28, 8, 30, 11], "#e6d6a8"),
  poly([6, 11, 10, 8, 16, 6, 22, 8, 26, 11], "#f0e3bc"))
sprite("weed_tuft", { w: 12, h: 12 },
  line(5, 11, 3, 4, "#6f8a3f"), line(6, 11, 6, 2, "#86a04f"), line(7, 11, 9, 4, "#6f8a3f"), line(4, 11, 1, 6, "#c9b66a"),
  line(8, 11, 11, 7, "#c9b66a"), line(6, 11, 5, 5, "#98ad5c"))
sprite("dune_grass", { w: 16, h: 22 },
  line(8, 21, 3, 5, "#8a9a6a"), line(8, 21, 6, 2, "#a8b480"), line(8, 21, 9, 1, "#8a9a6a"), line(8, 21, 12, 4, "#a8b480"),
  line(8, 21, 14, 9, "#d4c98a"), line(8, 21, 1, 11, "#d4c98a"), line(8, 21, 10, 7, "#6a7a52"), line(8, 21, 5, 8, "#6a7a52"))

// A community mural for the flats' walls (made up: sun, hills, hands and a heart; no names or words).
sprite("mural_plain", { w: 48, h: 20 },
  rect(0, 0, 48, 20, "#4aa3d8"), rect(0, 13, 48, 7, "#5da04a"), poly([0, 13, 10, 6, 20, 13], "#3f8a3f"), poly([14, 13, 28, 4, 44, 13], "#4a9a4a"),
  circ(38, 5, 4, "#f7d23a"), circ(38, 5, 3, "#ffe26a"),
  poly([10, 16, 6, 12, 8, 10, 10, 12, 12, 10, 14, 12], "#d6403e"),
  rect(20, 14, 3, 5, "#6b4430"), circ(21, 12, 2, "#a7754f"), rect(26, 15, 3, 4, "#2c3e50"), circ(27, 13, 2, "#8d5a3b"),
  hline(0, 0, 48, "#1d1b24"), hline(0, 19, 48, "#1d1b24"), vline(0, 0, 20, "#1d1b24"), vline(47, 0, 20, "#1d1b24"))

// ---- Vehicle detail: dents, stickers, slogans, rain on the glass, skid marks ----
sprite("dent", { w: 16, h: 12 },
  ellipse(8, 6, 7, 5, "#00000033"), ellipse(7, 5, 5, 3, "#00000040"), line(3, 9, 12, 3, "#ffffff40"), px(5, 4, "#00000055"))
sprite("sticker_a", { w: 14, h: 6 },
  rect(0, 0, 14, 6, "#f2c43a"), box(0, 0, 14, 6, "#1d1b24"), text(7, 1, "SKOON", "#1d1b24", { align: "c" }))
sprite("sticker_b", { w: 14, h: 6 },
  rect(0, 0, 14, 6, "#2e86c1"), box(0, 0, 14, 6, "#f4f1ea"), text(7, 1, "CAPE", "#f4f1ea", { align: "c" }))
sprite("sticker_c", { w: 14, h: 6 },
  rect(0, 0, 14, 6, "#c0392b"), box(0, 0, 14, 6, "#f4f1ea"), text(7, 1, "BRA", "#f4f1ea", { align: "c" }))
sprite("taxi_slogan_a", { w: 40, h: 8 },
  rect(0, 0, 40, 8, "#1d1b2488"), text(20, 1, "ALLES SAL REG KOM", "#f4f1ea", { align: "c" }))
sprite("taxi_slogan_b", { w: 40, h: 8 },
  rect(0, 0, 40, 8, "#1d1b2488"), text(20, 1, "SLOW AND EASY", "#f2c43a", { align: "c" }))
sprite("rain_drops", { w: 32, h: 16 },
  circ(4, 3, 1, "#cfe3f2aa"), circ(14, 9, 1, "#cfe3f2aa"), circ(24, 4, 1, "#cfe3f2aa"), circ(9, 13, 1, "#cfe3f2aa"), circ(28, 12, 1, "#cfe3f2aa"),
  circ(19, 1, 1, "#cfe3f2aa"), line(14, 10, 14, 14, "#cfe3f288"), line(4, 4, 4, 7, "#cfe3f288"), line(24, 5, 24, 9, "#cfe3f288"), px(2, 9, "#ffffffaa"), px(21, 7, "#ffffffaa"))
sprite("skid_mark", { w: 8, h: 32 },
  rect(1, 0, 2, 32, "#15151888"), rect(5, 0, 2, 32, "#15151888"), rect(1, 0, 2, 4, "#15151833"), rect(5, 0, 2, 4, "#15151833"))

// ---- World detail pass 2026-11-16 ----
// Dual-road median: mown kikuyu with bare sandy wheel-scuffed patches (cause: cars cutting the corner, foot traffic).
pal({ "<": "#6f8a3f", ">": "#93ab5c" })
sprite("median_grass", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "#7f9a4c"), noise(0, 0, 32, 32, "<", 0.12, 9), noise(0, 0, 32, 32, ">", 0.08, 4),
  ellipse(9, 22, 5, 3, "#b9a57e"), ellipse(10, 22, 3, 2, "#c9b68c"), ellipse(25, 8, 3, 2, "#b9a57e"))
// STOP painted across the lane before a stop line, as on a real road: the letters side by side, left to right as the driver sees
// them, stretched along the road. The texture's top is the far end (the stop line). 48 x 24 px = 2.4 m across x 1.8 m along.
sprite("stop_text", { w: 48, h: 24 },
  (c) => {
    const W = "#f1eee8", y0 = 2, w = 9, h = 20, s = 3
    const S = (x0) => { c.rect(x0, y0, w, s, W); c.rect(x0, y0, s, 10, W); c.rect(x0, y0 + 8, w, s, W); c.rect(x0 + w - s, y0 + 9, s, 11, W); c.rect(x0, y0 + h - s, w, s, W) }
    const T = (x0) => { c.rect(x0, y0, w, s, W); c.rect(x0 + 3, y0, s, h, W) }
    const O = (x0) => { c.rect(x0, y0, w, s, W); c.rect(x0, y0 + h - s, w, s, W); c.rect(x0, y0, s, h, W); c.rect(x0 + w - s, y0, s, h, W) }
    const P = (x0) => { c.rect(x0, y0, s, h, W); c.rect(x0, y0, w, s, W); c.rect(x0 + w - s, y0, s, 11, W); c.rect(x0, y0 + 8, w, s, W) }
    S(1); T(13); O(25); P(37)
  })
// The plain galvanised back of the STOP sign.
sprite("sign_stop_back", { w: 24, h: 24 },
  poly([7, 0, 16, 0, 23, 7, 23, 16, 16, 23, 7, 23, 0, 16, 0, 7], "#8d9299"),
  poly([8, 2, 15, 2, 21, 8, 21, 15, 15, 21, 8, 21, 2, 15, 2, 8], "#9ca1a8"))
// The red octagonal STOP sign on a pole.
sprite("sign_stop", { w: 24, h: 24 },
  poly([7, 0, 16, 0, 23, 7, 23, 16, 16, 23, 7, 23, 0, 16, 0, 7], "#f1eee8"),
  poly([8, 2, 15, 2, 21, 8, 21, 15, 15, 21, 8, 21, 2, 15, 2, 8], "#c8201e"),
  text(12, 9, "STOP", "#f1eee8", { align: "c" }))
// Oil drip under where cars park: dark, soft-edged, with a sheen ring.
sprite("oil_stain", { w: 16, h: 16 },
  ellipse(8, 8, 6, 5, "#2e2c2a"), ellipse(7, 8, 4, 3, "#24221f"), ellipse(10, 6, 2, 1, "#3d3b3a"), px(13, 11, "#2e2c2a"), px(3, 4, "#2e2c2a"))
// A second community mural: the mountain at sunset over rooftops (made up, no words).
sprite("mural_mountain", { w: 48, h: 20 },
  rect(0, 0, 48, 20, "#f08a3c"), rect(0, 0, 48, 5, "#d8613a"), circ(36, 9, 4, "#ffd25e"),
  poly([2, 14, 10, 8, 34, 8, 40, 12, 46, 14], "#5a3d6b"), poly([10, 8, 12, 6, 30, 6, 34, 8], "#4a3260"),
  rect(0, 14, 48, 6, "#2c3e50"), (c) => { for (let x = 2; x < 46; x += 6) { c.rect(x, 12, 4, 3, "#e8967a"); c.poly([x - 1, 12, x + 2, 10, x + 5, 12], "#a24a32") } },
  hline(0, 0, 48, "#1d1b24"), hline(0, 19, 48, "#1d1b24"), vline(0, 0, 20, "#1d1b24"), vline(47, 0, 20, "#1d1b24"))
// Striped market-stall awning.
sprite("awning_stripes", { w: 32, h: 16 },
  (c) => { for (let x = 0; x < 32; x += 8) { c.rect(x, 0, 4, 16, "#d6403e"); c.rect(x + 4, 0, 4, 16, "#f4f1ea") } }, hline(0, 15, 32, "#a83230"))
