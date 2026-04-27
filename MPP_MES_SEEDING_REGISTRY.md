# MPP MES — Seeding Registry

**Document:** FDS-MPP-MES-SEED-001
**Version:** 1.0 — Initial draft
**Date:** 2026-04-27
**Prepared By:** Blue Ridge Automation
**Prepared For:** Madison Precision Products, Inc. (Madison, IN)

This registry tracks every seed-data item the MES requires from sources **external to Blue Ridge** (MPP IT, MPP Quality, MPP Engineering, Honda AIM, vendor exports). Internal code-table seeds baked into migrations are NOT tracked here — those ship with the SQL.

> **Seeding items are NOT blockers for design or SQL build work.** Schemas, procs, and screens proceed in parallel; this registry exists so we collect the data alongside the build and load it during the cutover phase. An item is only a "blocker" if a downstream design decision genuinely requires its content (rare — flagged explicitly per item below).

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 1.0 | 2026-04-27 | Blue Ridge Automation | Initial registry. Catalogues 11 external-source seed items extracted from CLAUDE.md "MPP-owed" + "MPP data loads" sections. Establishes the registry as the single source of truth for seed-data tracking, removing seed items from the "blocking specific downstream work" framing in CLAUDE.md. |

---

## Status Legend

| Badge | Meaning |
|---|---|
| ⬜ **Owed** | File / list / decision not yet received from external source. |
| 🟡 **Received** | Delivered to Blue Ridge; not yet loaded into dev. |
| ✅ **Loaded (Dev)** | Loaded into dev SQL DB; queryable; tests passing where applicable. |
| 🔵 **Verified (Cutover)** | Loaded into production-equivalent + validated by the responsible MPP stakeholder. |

---

## Summary

| ID | Item | Target | Status | Owner | Blocking? |
|---|---|---|---|---|---|
| S-01 | Plant equipment master | `Location.Location` (Cell-tier) | 🟡 Received | MPP Eng. for tier mapping | No |
| S-02 | Downtime reason codes | `Oee.DowntimeReasonCode` | 🟡 Received | MPP Eng. for DC/MS/TS→Area mapping | No |
| S-03 | Defect codes | `Quality.DefectCode` | 🟡 Received | MPP Quality for Area mapping | No |
| S-04 | OPC tag catalog | Ignition OPC config (not SQL) | 🟡 Received | MPP Eng. for endpoint validation | No |
| S-05 | Parts master list | `Parts.Item` | ⬜ Owed | MPP IT (export from Macola/Flexware) | No |
| S-06 | Flexware BOM export | `Parts.Bom` + `Parts.BomLine` | ⬜ Owed | MPP IT (OI-13 — two-pull) | No |
| S-07 | Die rank list | `Tools.DieRank` | ⬜ Owed | MPP Quality | No |
| S-08 | Die rank compatibility matrix | `Tools.DieRankCompatibility` | ⬜ Owed | MPP Quality | **Yes** — gates cross-die merges (FDS-05-027) without supervisor override |
| S-09 | Label-type seed validation | `Lots.LabelTypeCode` (already seeded with Blue Ridge guesses) | ⬜ Owed | MPP Shipping | No |
| S-10 | Identifier sequence baselines | `Lots.IdentifierSequence.LastValue` | ⬜ Owed | MPP IT (snapshot at cutover) | **Cutover-only** — not blocking dev |
| S-11 | AIM pool config tuning | `Lots.AimPoolConfig` (defaults already seeded 50/30/20/10) | 🟡 Received (defaults) | MPP for post-deploy tuning | No |

**Counts:** 6 ⬜ Owed · 5 🟡 Received · 0 ✅ Loaded (Dev) · 0 🔵 Verified (Cutover)

**True blockers:** 1 (S-08 die rank compatibility — and even this has a supervisor-override workaround until populated).

---

## Per-Item Detail

### S-01 — Plant Equipment Master (Machines)

**Status:** 🟡 Received
**Source:** `reference/seed_data/machines.csv` (209 rows extracted from FRS Appendix B by Blue Ridge)
**Target:** `Location.Location` rows (Cell tier) + `Location.LocationAttribute` values for tonnage / cycle time / etc.
**Owner:** MPP Engineering — for tier mapping (DeptCode → AreaLocationId) and verification that the 2024 FRS extract still reflects today's plant.
**Blocking:** No — schema, procs, and screens proceed without this. Plant model exercises against 12 dev sample rows in `sql/seeds/seed_locations.sql`.

**File format:** CSV — columns: `MachId`, `MachNo`, `MachDesc`, `Tonnage`, `DeptDesc`, `MinPerShift`, `RefCycleTime`, `DeptCode`, `ProcId`, `ProcDesc`. Full column docs in `reference/seed_data/README.md`.

**Mapping owed from MPP Engineering:**
- `DeptCode` (DC, MS, TR, AS) → `AreaLocationId` (the actual `Location.Id` of each Area row).
- Confirmation that the 209-row FRS list is current — flag any decommissioned / new equipment since 2024.
- Validation that each row's `LocationTypeDefinition` (DieCastMachine vs CNCMachine vs TrimPress vs AssemblyStation, derived from `ProcDesc`) is correct.

**Loading procedure:** Bulk-load proc not yet written. Follows the `Oee.DowntimeReasonCode_BulkLoadFromSeed` JSON-fed pattern (S-02) — caller supplies a `@DeptCodeToAreaIdMap` JSON; proc inserts `Location.Location` rows + `Location.LocationAttribute` values per the FRS columns; deterministic Code generation `{DeptCode}-{MachNo}`.

**Acceptance criteria:**
1. All 209 rows (or MPP-revised count) load without error.
2. Each row's parent `AreaLocationId` matches the MPP-supplied mapping.
3. `LocationAttribute` rows for `Tonnage`, `RefCycleTime`, `MinPerShift` are present where the CSV has non-empty values.
4. `Location.LocationTypeDefinitionId` matches the CSV's `ProcDesc`.

---

### S-02 — Downtime Reason Codes

**Status:** 🟡 Received
**Source:** `reference/seed_data/downtime_reason_codes.csv` (353 rows extracted from FRS Appendix D — DC=86, MS=239, TS=25)
**Target:** `Oee.DowntimeReasonCode`
**Owner:** MPP Engineering — for DC/MS/TS → Area mapping and per-row `DowntimeReasonType` backfill where the CSV has missing TypeDesc.
**Blocking:** No — `Oee.DowntimeEvent` capture works against an empty DowntimeReasonCode set; reasons can be assigned later. OEE reporting requires this loaded before go-live.

**File format:** CSV — columns: `DeptCode`, `ReasonId`, `ReasonDesc`, `TypeDesc`, `IsExcused`. Full column docs in `reference/seed_data/README.md`.

**Mapping owed from MPP Engineering:**
- `DeptCode` (DC, MS, TS) → `AreaLocationId` (3 area Location IDs).
- Backfill `DowntimeReasonType` for any row where CSV `TypeDesc` is missing — engineering-level review can be done in dev via `_Update` calls on rows with NULL `DowntimeReasonTypeId`.

**Loading procedure:** `Oee.DowntimeReasonCode_BulkLoadFromSeed @ReasonsJson, @DcAreaId, @MsAreaId, @TsAreaId, @AppUserId` — built and tested in Phase 8. JSON-fed bulk load; deterministic Code generation `{DeptCode}-{NNNN}` (zero-padded `ReasonId`).

**Acceptance criteria:**
1. All 353 rows load (or MPP-revised count) without uniqueness violations on `Code`.
2. Rows with missing `TypeDesc` load with `DowntimeReasonTypeId = NULL`; engineering backfills via `_Update` before go-live.
3. The MPP-supplied DC/MS/TS → Area IDs match the actual Area rows in `Location.Location`.

---

### S-03 — Defect Codes

**Status:** 🟡 Received
**Source:** `reference/seed_data/defect_codes.csv` (153 rows extracted from FRS Appendix E)
**Target:** `Quality.DefectCode`
**Owner:** MPP Quality — for `AreaLocationId` mapping and confirmation that the FRS extract is current.
**Blocking:** No — non-conformance capture works against an empty DefectCode set.

**File format:** CSV — columns: `DefectId`, `DefectCode`, `DefectDesc`, `AreaCode`, `IsExcused` (or similar — see `reference/seed_data/README.md`).

**Mapping owed from MPP Quality:**
- `AreaCode` → `AreaLocationId`.
- Confirmation that the 2024 FRS list still reflects today's defect catalogue — flag adds / removes.

**Loading procedure:** Bulk-load proc not yet written. Follows the `DowntimeReasonCode_BulkLoadFromSeed` JSON pattern.

**Acceptance criteria:**
1. All 153 rows (or MPP-revised count) load.
2. `AreaLocationId` mapping matches the MPP-supplied Area IDs.

---

### S-04 — OPC Tag Catalog

**Status:** 🟡 Received
**Source:** `reference/seed_data/opc_tags.csv` (161 rows extracted from FRS Appendix C)
**Target:** Ignition OPC server configuration (NOT a SQL table). `OmniServer` for scales; `TOPServer` / `SWToolbox` for PLCs; Cognex for vision.
**Owner:** MPP Engineering — for endpoint IP / port validation and live-tag verification.
**Blocking:** No — Ignition OPC config can be assembled as Phase 7 progresses.

**File format:** CSV — columns: `ServerName`, `ServerPid`, `Direction`, `AccessPath`, `OpcItemId`. Full column docs in `reference/seed_data/README.md`.

**Validation owed from MPP Engineering:**
- Endpoint IP / port for each OPC server (cross-reference with `reference/NewInput/5GO-AP4 IPAddresses.xlsx`).
- Live verification that each tag is reachable and behaves per the FRS (read/write direction, value type, rate).

**Loading procedure:** Manual import into Ignition Designer at Arc 2 Phase 7 (OPC configuration phase).

**Acceptance criteria:**
1. Every `OpcItemId` resolves and reads/writes per the FRS spec on the live PLC/scale.

---

### S-05 — Parts Master List

**Status:** ⬜ Owed
**Source:** MPP IT export from Macola ERP and/or Flexware MES current parts table.
**Target:** `Parts.Item`
**Owner:** MPP IT — for the export.
**Blocking:** No — `Parts.Item_Create` / `_Update` procs work against an empty table; sample parts can be seeded for dev. Production cutover needs the full list before go-live.

**File format owed from MPP IT:** CSV or XLSX with at minimum: PartNumber, Description, MacolaPartNumber (optional), DefaultUomCode, UnitWeight (optional), WeightUomCode (optional), CountryOfOrigin (ISO 3166-1 alpha-2), MaxLotSize / PartsPerBasket (per-basket capacity), MaxParts (per-Location cap, optional), ItemType (Raw/Component/SubAssembly/FinishedGood). Format conversation with MPP IT pending.

**Mapping owed from MPP:**
- `ItemType` per row — likely derivable from MPP ERP categories.
- `CountryOfOrigin` per row — Honda compliance field (FDS-03-001).

**Loading procedure:** Bulk-load proc not yet written; format depends on what MPP IT exports.

**Acceptance criteria:**
1. Every part on MPP's master list loads as an `Item` row with non-empty `PartNumber` (UNIQUE), valid `UomId` FK, and correct `ItemType` FK.
2. `CountryOfOrigin` populated where MPP has the data.

---

### S-06 — Flexware BOM Export (OI-13)

**Status:** ⬜ Owed
**Source:** MPP IT export from the live Flexware MES at IP `.919`.
**Target:** `Parts.Bom` + `Parts.BomLine`
**Owner:** MPP IT — for the export tooling and execution.
**Blocking:** No — Bom / BomLine schema and procs are built (Phase 6); empty-table operation is fine for non-BOM-driven flows. BOM-driven flows (Trim 1-line BOM consumption per FDS-05-033, Assembly material verification per FDS-06-011) need this loaded before go-live.

**Two-pull plan (per OI-13):**
1. **NOW** — one-shot pull for dev validation: load into dev DB, verify schema fit, exercise the `Bom_GetActiveForItem` flow on a representative sample. Catches export-format issues before cutover.
2. **At cutover** — fresh pull on cutover day to capture any BOM changes between dev validation and go-live.

**File format owed from MPP IT:** TBD — depends on what Flexware exports. Likely two CSVs (`bom_header.csv` + `bom_line.csv`) or a JSON tree. Format conversation pending.

**Loading procedure:** Bulk-load proc not yet written; written after MPP IT confirms export format.

**Acceptance criteria:**
1. Every Flexware BOM round-trips to `Parts.Bom` + `Parts.BomLine` without error.
2. Sample-part `Bom_GetActiveForItem` returns the expected component list.
3. Versioning: imported BOMs land as `Published` rows (not Draft) — they're already in active use at MPP.

**Coupling:** Requires S-05 (Parts master) to be loaded first — BomLine.ChildItemId FKs into Item.

---

### S-07 — Die Rank List

**Status:** ⬜ Owed
**Source:** MPP Quality.
**Target:** `Tools.DieRank` (currently empty seed)
**Owner:** MPP Quality — for the canonical rank list.
**Blocking:** No — `Tools.Tool` rows can be created with `DieRankId = NULL`; rank assignment can be backfilled. Cross-die merges that require rank checks (S-08) are the only flow that needs this loaded.

**Format owed:** Simple list of rank codes + descriptions (e.g., `A`, `B`, `C` with descriptions).

**Loading procedure:** Manual `Tools.DieRank_Create` calls (~10 rows expected).

**Acceptance criteria:**
1. All MPP-defined ranks present as `Tools.DieRank` rows.

---

### S-08 — Die Rank Compatibility Matrix

**Status:** ⬜ Owed — **TRUE BLOCKER** (with supervisor-override workaround)
**Source:** MPP Quality.
**Target:** `Tools.DieRankCompatibility` (currently empty seed)
**Owner:** MPP Quality — owes the full pairwise compatibility matrix.
**Blocking:** **Yes** — `Lots.Lot_Merge` rejects cross-die merges until at least the relevant rank pair exists in the matrix. Supervisor AD elevation (FDS-04-007) provides an override path until populated, so the workaround is real but adds operator friction.

**Format owed:** Pairwise list `(RankA_Code, RankB_Code, CanMix BIT)`. Or symmetric matrix in xlsx.

**Loading procedure:** Manual `Tools.DieRankCompatibility_Create` calls per pair (or a small bulk-load proc if matrix is wide).

**Acceptance criteria:**
1. Every pair MPP Quality identifies as compatible has a row with `CanMix = 1`.
2. Default behavior for unlisted pairs: reject merge (proc enforces this).

**Depends on:** S-07 (DieRank list).

---

### S-09 — Label Type Code Validation

**Status:** ⬜ Owed (validation only — values already seeded by Blue Ridge)
**Source:** Blue Ridge proposed values from Honda shipping conventions: `Primary`, `Container`, `Master`, `Void`. Loaded via Phase 3 migration `0004_phase3_reference_lookups.sql`.
**Target:** `Lots.LabelTypeCode` (4 rows already in dev DB)
**Owner:** MPP Shipping — for confirmation / corrections.
**Blocking:** No — labels print against whatever's seeded; if values change, an update migration is trivial.

**Validation owed from MPP Shipping:**
- Confirm the four seeded values match Honda's terminology and operational vocabulary.
- Flag any additional types (e.g., `Repack`, `Reprint`) that should be seeded.

**Loading procedure:** Already loaded. Updates land as a small versioned migration if values change.

---

### S-10 — Identifier Sequence Baselines (Cutover Snapshot)

**Status:** ⬜ Owed (cutover-only — not blocking dev)
**Source:** Snapshot of Flexware live counter values for `Lot` (~1,710,932 baseline) and `SerializedItem` (~2,492 baseline) on cutover day.
**Target:** `Lots.IdentifierSequence.LastValue` for the two seeded rows (`Lot` `MESL{0:D7}`, `SerializedItem` `MESI{0:D7}`).
**Owner:** MPP IT — for the snapshot reading.
**Blocking:** No — dev DB seeds with `LastValue = 0`; the cutover migration overwrites with Flexware values to ensure ID continuity.

**Snapshot owed from MPP IT:** Two integer reads from Flexware on cutover day (delivered as a 2-row CSV or just two numbers in an email).

**Loading procedure:** Cutover migration: `UPDATE Lots.IdentifierSequence SET LastValue = @MppLotValue WHERE Code = 'Lot';` + same for SerializedItem.

**Acceptance criteria:**
1. First MES-issued `Lot` LotName = `MESL{Flexware_LastValue + 1:D7}` — no overlap, no gap.
2. Same for SerializedItem.

---

### S-11 — AIM Pool Configuration Tuning

**Status:** 🟡 Received (defaults seeded by Blue Ridge)
**Source:** Defaults shipped with Arc 2 Phase 7 migration: `TargetBufferDepth = 50, TopupThreshold = 30, AlarmWarningDepth = 20, AlarmCriticalDepth = 10`.
**Target:** `Lots.AimPoolConfig` (single-row table; one seeded row)
**Owner:** MPP — for post-deploy tuning based on observed peak container throughput vs AIM responsiveness.
**Blocking:** No.

**Tuning input owed from MPP (post-deploy):**
- Observed peak containers/hour across all dedicated Assembly terminals combined.
- Observed AIM `GetNextNumber` response time (mean + p99).
- Operational tolerance for AIM-outage windows (how long should production survive an AIM outage on the buffer alone).

**Loading procedure:** Configuration Tool exposes `Lots.AimPoolConfig_Update @TargetBufferDepth, @TopupThreshold, @AlarmWarningDepth, @AlarmCriticalDepth` (Admin-elevated per FDS-04-007).

---

## Adding a New Seeding Item

When a new external-data dependency surfaces:
1. Add a row to the **Summary** table with the next `S-NN` ID.
2. Add a per-item detail section below.
3. If the item is a true blocker (rare), flag it in both the summary table's "Blocking?" column and in CLAUDE.md's "Decision blockers" list.
4. Update the Revision History.

## Marking an Item Loaded

When MPP delivers data and it lands in dev:
1. Update the item's status badge to ✅ Loaded (Dev) in the summary table and the per-item section.
2. Capture the actual row count loaded vs the originally-quoted count.
3. Update the Revision History.

When the item is verified in a cutover-equivalent environment (post-Phase 0 customer validation workshop or equivalent):
1. Update the badge to 🔵 Verified (Cutover).
2. Capture the responsible MPP stakeholder + date of validation.
3. Update the Revision History.
