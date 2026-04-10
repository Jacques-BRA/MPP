# Seed Data Parse Warnings

Notes from the 2026-04-10 PDF extraction of FRS Appendices B, C, D, E. None of these are blocking, but the new engineer should be aware before treating these CSVs as fully authoritative.

## machines.csv (Appendix B)

**Row count:** 209 — matches the row count from the markdown extract (`mpp_frs_md/appendix_b_machines.md`).

**Missing MachIds:** 21 IDs are absent from the source PDF, indicating retired or deleted machines in the legacy MES. The gaps:
`29, 62, 66, 67, 72, 85, 93, 94, 95, 101, 106, 107, 108, 110, 120, 153, 165, 168, 181, 205, 229`

This is expected — the legacy MES has soft-deleted entries that just don't appear in the printed appendix.

**Partial rows (35 rows):** On page 85 of the source PDF, machines 182–217 (approximately) appear without right-side columns (`DeptCode`, `DeptCode2Desc`, `ProcId`, `ProcDesc`, `OrigProc`). These are likely "in development" entries that hadn't been fully classified in the legacy system. The CSV preserves them with the right-side columns blank. They share `MachId` from a sequential numbering but lack the seed data needed for direct import. **Action:** confirm with MPP whether these are real machines that need departments assigned, or if they should be excluded from MVP seed loading.

**Wrapped MachDesc handling:** The PDF wraps long descriptions across multiple lines. The parser merges these into single descriptions:
- Row 188: `"Side Case OP30-2"` (was `"Side Case OP30-"` + `"2"`)
- Row 230: `"Side Case OP20-1"` (similar)
- Row 191: `"Assembly Bridge Line 1"` (prefix `"Assembly"` + suffix `"Bridge Line 1"`)
- ~30 other rows with similar wrapping

These are spot-checked correct, but if you find rows where MachDesc looks truncated or starts with a fragment, that's a parser miss to flag.

**ProcDesc value `"Diecast"`:** Note the spelling — the source PDF uses `Diecast` (one word, lowercase 'c') for the process description, even though the area is `Die Cast` (two words, capitalized). Preserved as-is.

## opc_tags.csv (Appendix C)

**Row count:** 161 (71 Omni + 90 TOP). No issues during parsing.

**`AccessPath` is empty for all Omni rows** because OmniServer doesn't use access paths in the legacy config. This is expected, not a parse error.

## downtime_reason_codes.csv (Appendix D)

**Row count:** 353 — distributed as DC=86, MS=242, TS=25.

**ReasonId max:** 662 — the highest ID is 662, but only 353 are present (308 gaps). This is normal for a legacy system with retired codes.

**Empty `TypeId`/`TypeDesc`:** ~25 rows have empty `TypeId` and `TypeDesc` fields. These are reason codes from the legacy MES that were never categorized into a reason type. **Action:** MPP should review and assign types before MVP go-live, OR these can be loaded with `NULL` type and filtered separately.

**No Assembly (`AS`) reason codes:** The legacy MES does not have assembly-specific downtime codes — assembly machines apparently use Machine Shop (`MS`) codes. Worth confirming with MPP.

**Wrapped descriptions handled:** Most "Machine Shop" rows have the dept name wrapped as `"Machine"` (prefix) + `"Shop"` (data row). The parser stitches these together correctly.

## defect_codes.csv (Appendix E)

**Row count:** 153 — matches the markdown extract.

**Wrapped row 122:** `"Dimensional (All dimensional except pin size and or depth/height)"` is correctly stitched from 3 source lines.

**Departments:** Codes are distributed across Die Cast (10), Trim Shop (11), Machine Shop (12), Production Control, Quality Control, and HSP (high-speed supplier parts).

---

## Re-extraction Procedure

To regenerate any CSV after a source PDF update:

```bash
# 1. Extract appendix pages from PDF
pdftotext -table -f 81 -l 86 reference/MPP_FRS_Draft.pdf reference/seed_data/_appendix_b_raw.txt
pdftotext -table -f 87 -l 91 reference/MPP_FRS_Draft.pdf reference/seed_data/_appendix_c_raw.txt
pdftotext -table -f 92 -l 105 reference/MPP_FRS_Draft.pdf reference/seed_data/_appendix_d_raw.txt
pdftotext -table -f 106 -l 110 reference/MPP_FRS_Draft.pdf reference/seed_data/_appendix_e_raw.txt

# 2. Run parsers
node reference/seed_data/parsers/parse_appendix_b.js
node reference/seed_data/parsers/parse_appendix_c.js
node reference/seed_data/parsers/parse_appendix_d.js
node reference/seed_data/parsers/parse_appendix_e.js

# 3. Regenerate Excel workbook
node reference/seed_data/build_seed_workbook.js
```

The `_appendix_*_raw.txt` files are intermediate scratch files and can be deleted after parsing.
