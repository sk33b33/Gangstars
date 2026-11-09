# Game Design Document — Gangstars

## 1. High concept

**Gangstars** is a stylized, third-person 3D neighbourhood crime-and-empire game. The player starts as a small-time operator in one compact community and gradually builds influence, relationships, resources, and control. The emphasis is on a believable living neighbourhood, character movement, street-level exploration, and gradual territory expansion.

The game should feel grounded and character-driven rather than like a static strategy map. Houses, streets, residents, crews, and local businesses form a connected simulation.

## 2. Player fantasy and pillars

1. **A living community:** people leave homes, walk to destinations, socialize, work, react, and return.
2. **Street-level agency:** the player physically explores and interacts with the neighbourhood.
3. **Build an organisation:** recruit crew members, assign roles, improve safehouses, and build reputation.
4. **Territory earned over time:** the starter community is the whole initial map; expansion is a meaningful later unlock.
5. **Readable, responsive systems:** clear feedback, understandable mission goals, and fair progression.

## 3. Camera and controls

- Third-person over-the-shoulder camera.
- Keyboard/mouse first; controller mapping should be possible without rewriting gameplay.
- Player movement: walk, run/sprint, jump only if level design needs it, interact.
- Camera: mouse look with sensible pitch limits and optional sensitivity settings.
- Interactions: contextual prompt for doors, people, mission objects, and shops.

## 4. Initial neighbourhood

The starter area contains approximately 30 houses. Organize them as several connected residential streets around a central road or small square. Include:
- 30 distinct house plots with readable numbers/IDs.
- Pavements/sidewalks, road crossings, driveways, yards, fences, gates, streetlights, bins, parked cars, and small public spaces.
- A corner shop or local business, a community gathering spot, a small park/court, and one player safehouse.
- Clear landmarks so the player can navigate without a minimap.
- Street lighting and a day/night cycle as later polish, not a blocker for the first slice.

The first district should be compact enough that a player can walk from one end to the other in roughly 2–4 minutes, subject to playtesting.

## 5. Characters

### Player
- Third-person movement and camera.
- Interaction system.
- Basic stats: health, cash, reputation, crew influence.
- Saveable position and progression.

### Residents
- Named or generated identities with stable IDs.
- Home assignment, daily routine, current goal, faction/relationship, and alertness.
- Visible movement between home and destinations.
- Ambient behaviours: walking, standing, talking, sitting, shopping, working, returning home.
- Simple reactions to threats or unusual events.

### Crew members
- Follow, guard, patrol, gather, and travel to assigned points.
- Can be recruited through missions or reputation.
- Have loyalty/role data and simple combat readiness later.
- Must use the same navigation and schedule foundation as residents.

### Rival faction
- Starts as a small presence or a later introduction.
- Has a home base and patrol/gather points.
- Avoid overwhelming the first playable milestone.

## 6. Core gameplay loop

1. Explore the starter neighbourhood.
2. Meet residents and discover local stories/needs.
3. Complete a mission or favour.
4. Earn cash, reputation, trust, or crew influence.
5. Recruit or improve crew.
6. Resolve local conflicts and gain control of key locations.
7. Unlock a new district after a clear progression milestone.
8. Repeat with new characters, locations, and challenges.

## 7. Systems

- Character controller and camera.
- Contextual interaction.
- House/plot registry and door entry.
- NPC schedules and navigation.
- Faction and relationship data.
- Mission manager and objective tracking.
- Reputation/cash/crew progression.
- Turf ownership and district unlock manager.
- Save/load.
- UI: HUD, interaction prompt, mission tracker, map/territory screen, pause/settings.

## 8. Tone and presentation

Use a fictional contemporary urban neighbourhood. Aim for grounded, stylized realism with strong silhouettes and readable colour/value contrast. Avoid copying real gangs, real people, or identifiable copyrighted game assets. Use fictional names, symbols, locations, and factions. Build a coherent visual identity before sourcing final assets.

## 9. Monetization and online features

Out of scope for the initial build. No multiplayer, live service, microtransactions, or online accounts until a stable single-player game exists.

## 10. Explicit non-goals for the first playable build

- Huge open world.
- Fully enterable interiors for every house.
- Complex police simulation.
- Advanced vehicle physics.
- Multiplayer.
- Photorealistic custom assets.
- Large-scale combat systems.

These may be considered later only after the core neighbourhood simulation is stable.
