# Third-party material

- **Map data:** (c) OpenStreetMap contributors, Open Database Licence 1.0 (https://www.openstreetmap.org/copyright).
  Used for `data/world/mitchells_plain_real.json` and `mitchells_plain_streets.json`; shown in the city map with this credit.
- **House outlines:** Microsoft GlobalMLBuildingFootprints (Open Database Licence 1.0,
  https://github.com/microsoft/GlobalMLBuildingFootprints), used for the buildings in `data/world/westridge/`.
  OpenStreetMap has no house outlines for Westridge. Credited on screen in the real Westridge view.
- **Map outline:** `data/world/mitchells_plain.knoxmap.json`, drawn by the project owner in KnoxMap.
- **Working rules:** `.claude/rules/` and the design-doc format in `design/gdd/` are adapted from
  Claude Code Game Studios by Donchitos (MIT licence, https://github.com/Donchitos/Claude-Code-Game-Studios).
- **Game-design inspiration:** the survival layer borrows ideas (needs, looting, wounds, skills, top-down view) from
  Project Zomboid. No code or assets from Project Zomboid or the Zomdroid launcher are used.
- **Taxi model:** "Toyota Hiace Passenger Van L2H3 GLX 2020" by Aeroux (https://skfb.ly/pH7KN), Creative Commons Attribution 4.0
  (http://creativecommons.org/licenses/by/4.0/). Source `art/source/hiace_l2h3.glb`, built into `assets/models/vehicles/taxi.glb` by
  `tools/blender/build_taxi.py`. Changes: scaled, the baked-in wheels cut out and replaced by a made wheel, the texture shrunk to 2048 px,
  seats, markers and the taxi markings added. Credited in the game (Menu > Credits).
- **Police bakkie model:** "SAPN Hilux" by stephen.williams (https://skfb.ly/6SAY8), Creative Commons Attribution-NonCommercial 4.0
  (http://creativecommons.org/licenses/by-nc/4.0/). **The licence does not allow commercial use**: the game may not be sold, or
  carry ads or paid extras, while it uses this model (replace it before any commercial release). Source `art/source/sapn_hilux.glb`, built
  into `assets/models/vehicles/hilux.glb` by `tools/blender/build_hilux.py`. Changes: the textures (a power company's logo, mud) are replaced
  by plain colours, the wheels rebuilt, a light bar and police markings added. Credited in the game (Menu > Credits).
- **Remy's car model:** "Ford Sierra" by poormancantaffordto3dmodels (https://skfb.ly/onCrE), Creative Commons Attribution 4.0
  (http://creativecommons.org/licenses/by/4.0/). Source `art/source/ford_sierra.glb`, built into `assets/models/vehicles/sierra.glb` by
  `tools/blender/build_sierra.py`. Changes: the engine, suspension, roll cage and duplicate wheels removed, parts joined and decimated, plain
  role colours, markers for the wheels, seats, wipers and steering wheel. Credited in the game (Menu > Credits).
