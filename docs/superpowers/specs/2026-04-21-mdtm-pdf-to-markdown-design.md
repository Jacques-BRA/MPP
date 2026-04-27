# Manufacturing Director Technical Manual — PDF → Markdown Conversion

**Status:** Approved (verbal, 2026-04-21)
**Owner:** Jacques Potgieter
**Purpose:** Convert the 2009 Flexware "Manufacturing Director Technical Manual" PDF (145 pages, `reference/Manufacturing Director Technical Manual.pdf`) into a single Markdown file so Claude can consume it naturally when researching the legacy MES being replaced.

## Why this doc matters

It is the technical manual for the 2008–2009 VCM Traceability System — the original traceability MES installed at MPP by Flexware Innovation. Authored by the same vendor as the current FRS, it documents the foundation that the replacement MES builds on. Machine integration, Cognex/PLC touch points, part interlocking logic, terminal configuration, and operator workflows are all described here — exactly the context Claude needs when the FRS references legacy behavior.

## Source characteristics (verified)

- **145 pages**, **2.48 MB**, text-based PDF (selectable text, not scanned)
- Numbered outline `1.0 / 1.1 / 1.1.1` throughout — maps cleanly to `#`/`##`/`###`
- **TOC** occupies pages 2–7 (dot-leader lines with trailing page numbers)
- **Running footer** on every page — 4 predictable lines starting with `Title:`, `Project:`, `Last Saved:`, `Confidential:`
- Heavy screenshot content (user confirmed) — dropped in text-first pass, extracted on demand
- `pdftotext -enc UTF-8` fixes the em-dash mojibake observed in default-encoding output

## Tool inventory on this machine

| Tool | Location | Usable |
|---|---|---|
| `pdftotext` (Xpdf 4.00) | `/mingw64/bin/pdftotext` | ✅ Primary extractor |
| `pdfimages` | **Not bundled with Xpdf** | ❌ — would need Poppler-for-Windows if we later want images |
| `pdftoppm` | Missing | ❌ — blocks Claude's Read tool on this PDF |
| Node.js | `/c/Program Files/nodejs` | ✅ Post-processor runtime |
| Pandoc | `%LOCALAPPDATA%\Pandoc` | ✅ (not needed for this job) |
| Python | MS Store stub only | ❌ |

## Approach

**Option A + D:** Text-first extraction with a Node post-processor. Images deferred — extract specific ones on demand if a future question requires seeing a UI screen.

### Pipeline

1. **Extract:** `pdftotext -enc UTF-8 -layout "<PDF>" /tmp/mdtm/full.txt`
   - `-enc UTF-8` → correct em-dash / special chars
   - `-layout` → preserves column structure for Task/Operation tables
2. **Post-process (Node):** `reference/scripts/convert_mdtm_to_md.js`
   - Split input on `\f` (form feed) into 145 page blocks
   - Drop the 4-line running footer at the end of each page
   - Detect and drop TOC pages (pages where >30% of non-blank lines match `\.{4,}\s*\d+\s*$`)
   - Promote numbered sections to Markdown headings:
     - `N.0` → `#` (top level)
     - `N.M` (not ending in .0) → `##`
     - `N.M.K` → `###`, etc.
     - Skip matches containing dot leaders (TOC residue)
   - Insert `<!-- Page N -->` HTML comments at each page boundary so Claude can cite PDF page numbers
   - Normalize line endings to LF, collapse 3+ blank lines to 2
3. **Emit:** `reference/Manufacturing_Director_Technical_Manual.md`
4. **Spot-check:** Sample 5–10 representative pages — title page, TOC boundary, a multi-column table page, a dense prose section, and the end — to validate heading levels and footer stripping.

### What's intentionally out of scope

- **Screenshots:** Replaced with inline `<!-- Page N -->` markers only. If a later ask needs a specific image, install Poppler-for-Windows and run `pdfimages -png -p <PDF> <outdir>` for the relevant page range.
- **Perfect table reconstruction:** Multi-column Task/Operation blocks will stay as preformatted layout text. Manually converting ~30 tables to Markdown tables is not worth the effort for a reference doc.
- **Table of Contents:** Dropped. Markdown renderers auto-generate a TOC from headings; the extracted TOC would be redundant and lossy (page refs are meaningless in Markdown).

## Deliverables

- `reference/Manufacturing_Director_Technical_Manual.md` — the output
- `reference/scripts/convert_mdtm_to_md.js` — the post-processor (reusable for any similarly-structured Flexware technical manual)
- This spec, committed for traceability

## Success criteria

- Full text content of sections 1.0–18.x (or wherever the doc ends) is present in the `.md`
- Section numbering is preserved and rendered as proper Markdown headings
- No running-footer clutter in the output
- No TOC clutter in the output
- Em-dashes and special characters render correctly (no `�` placeholders)
- Grep-able — I can find any section or phrase from the PDF via `Grep` on the `.md`
