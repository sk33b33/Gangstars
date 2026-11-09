# Progression, Missions, and Turf Expansion

## Starting state

- Player begins in the starter district.
- Starter district contains approximately 30 houses.
- Starter district is the only unlocked district.
- Adjacent districts are locked and cannot be entered or claimed.
- The player has a modest starting cash/reputation level and a small set of contacts.

## Progression variables

Keep progression values in a dedicated service/model:
- `cash`
- `reputation`
- `crew_influence`
- `district_control`
- `completed_mission_ids`
- `unlocked_district_ids`
- `recruited_crew_ids`

Avoid using UI text as the source of truth.

## Intro mission arc

1. **New Face:** meet a local contact at the gathering corner.
2. **A Favour:** visit a resident and deliver a harmless item or message.
3. **Know the Block:** visit three named locations across the starter district.
4. **First Crew:** help a character and unlock the first recruit.
5. **Local Respect:** complete a sequence of local objectives to increase reputation.
6. **Hold the Corner:** defend or maintain influence at a fictional point of interest.
7. **Beyond the Block:** unlock the first neighbouring district after the player meets the reputation and mission prerequisites.

Keep missions fictional and focused on game objectives. The initial prototype can use non-violent errands and social objectives to validate the mission framework.

## Turf data

Each district should have:
- Stable district ID.
- Display name.
- Boundary/transition point.
- House and point-of-interest IDs.
- Current control/influence value.
- Unlock requirements.
- Locked/unlocked/contested/controlled state.

## Unlock logic

Use a single `DistrictManager` or equivalent service:
- `can_unlock(district_id)`
- `unlock_district(district_id)`
- `get_unlock_requirements(district_id)`

The unlock service must validate prerequisites. UI may request an unlock but must not directly change the district state.

## Example first expansion condition

Use this as placeholder tuning, not a permanent balance decision:
- Complete `hold_the_corner`.
- Reach a modest reputation threshold.
- Recruit at least one crew member.

Display all requirements to the player. Persist the unlocked district ID in the save data.

## As built (Phase 5)

| District | Side | Unlock requirements |
|---|---|---|
| Vleirand (`starter`) | — | always unlocked; contested below 50% influence, controlled at 50%+ |
| Rooiduin (`district_east`) | east | Hold the Corner, reputation 60, 1 crew, Vleirand influence 50% |
| Kalkbos (`district_west`) | west | Beyond the Block, reputation 100, 2 crew, Vleirand influence 80% |

Mission chain: New Face → A Favour → Know the Block → First Crew → Local Respect →
Hold the Corner → (unlock Rooiduin) → Beyond the Block.
