// Vleirand starter district — pixel textures for 3D surfaces.
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
sprite("road_asphalt", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "a"), noise(0, 0, 32, 32, "As", 0.12, 7),
  line(4, 30, 11, 22, "A"), line(11, 22, 14, 23, "A"))       // one patched crack

// Sidewalk: 1 m square concrete slabs with expansion joints.
sprite("sidewalk", { w: 32, h: 32 },
  rect(0, 0, 32, 32, "p"),
  hline(0, 0, 32, "P"), hline(0, 16, 32, "P"), vline(0, 0, 32, "P"), vline(16, 0, 32, "P"),
  hline(1, 1, 15, "q"), hline(17, 17, 15, "q"), noise(0, 0, 32, 32, "P", 0.03, 3))

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
  text(40, 4, "VLEIRAND CAFE", "W", { align: "c" }), text(40, 10, "BREAD  AIRTIME", "l", { align: "c" }))

sprite("sign_bus", { w: 16, h: 16 },
  rect(0, 0, 16, 16, "l"), box(0, 0, 16, 16, "L"), text(8, 2, "BUS", "k", { align: "c" }),
  rect(3, 9, 10, 4, "k"), px(4, 13, "k"), px(11, 13, "k"), rect(4, 10, 3, 2, "C"), rect(9, 10, 3, 2, "C"))

sprite("sign_locked", { w: 64, h: 24 },
  rect(0, 0, 64, 24, "l"), box(0, 0, 64, 24, "k"),
  (c) => { for (let x = -24; x < 64; x += 8) c.line(x, 23, x + 4, 19, "k", 2) },
  text(32, 3, "ROAD CLOSED", "k", { align: "c" }), text(32, 10, "LOCKED TURF", "T", { align: "c" }))
