# OI-31 Impact — Why Single-Line Deployment Breaks the Identifier Sequence

**For:** Ben (MPP production / scheduling SME)
**From:** Blue Ridge Automation
**Date:** 2026-04-24
**Reading time:** ~8 minutes
**Context:** The customer has asked us to deploy the replacement MES on **one line first** (e.g., AP4-A2) while the rest of the plant continues on Flexware. OI-31 in our Open Issues Register is about the identifier-counter table that generates LTT barcode numbers and serialized-item IDs. This memo explains why the single-line phased rollout interacts badly with OI-31 and what we'd need to make it work.

---

## The 30-second version

Both Flexware and the new MES mint LTT barcodes (`MESL0000001`, `MESL0000002`, …) from the same numeric sequence. Today Flexware is at `MESL1710932`. If we cut one line over to the new MES at this value and leave Flexware running the other lines, **both systems will immediately start minting the same numbers in parallel**, because neither knows what the other is doing. Within hours we will have two physical baskets with the same LTT barcode in the plant and in Honda's AIM records. Genealogy, quality holds, and shipping traceability all depend on the LTT being unique — collisions break all of them.

**Our position:** a single-line rollout is technically workable but only with one of three specific mitigations listed below. Without a mitigation, we don't recommend it. With a mitigation, it can be made safe.

---

## What OI-31 actually is

Flexware has a table called `IdentifierFormat` that holds two counters MPP uses every day:

| Counter | Format | Purpose | Last sampled value |
|---|---|---|---|
| Lot | `MESL{0:D7}` | The LTT barcode printed on every physical basket (Die Cast output, Trim output, Machining, Assembly intermediates, finished containers all carry one) | 1,710,932 |
| Serialized Item | `MESI{0:D7}` | The serial number laser-etched on serialized finished goods (5G0 fronts/rears) | 2,492 |

These are MPP-internal identifiers, distinct from Honda's AIM shipper IDs. They are stamped onto physical labels, scanned at every movement, written into `ConsumptionEvent` / `LotGenealogy` rows, and printed on shipping labels. They are how Honda can ask "which specific cavity of which die made this part" two years from now.

Our replacement MES has an equivalent table — `Lots.IdentifierSequence` — and a stored proc `Lots.IdentifierSequence_Next` that hands out the next number atomically. At cutover day, we seed our counter to match Flexware's current value so there's no gap and no collision with anything already in circulation.

**This only works as a one-shot.** One system mints, the other system is retired. At the cutover moment, ownership of the counter transfers.

---

## Why the single-line proposal breaks this

If AP4-A2 cuts over to the new MES on (say) 2026-06-01 at `LastValue = 1,800,000`:

- At 6:05am Carlos logs a cavity-A basket on AP4-A2 via the new MES. The new MES mints `MESL1800001`. A physical LTT label with that barcode goes on the basket. The value in our `Lots.IdentifierSequence.LastValue` is now 1,800,001.
- At 6:06am an operator on 5G0-A1 logs a basket in Flexware. Flexware doesn't know the new MES exists. Its `IdentifierFormat.LastCounterValue` was 1,799,999 and it mints `MESL1800000`. That number is fine (Flexware didn't use 1,800,001 yet).
- At 6:15am 5G0-A1 produces another basket. Flexware mints `MESL1800001`. Two physical baskets, same barcode, same plant, same day.

This is not a theoretical edge case. Flexware is doing ~hundreds of LTT mints per shift today. The new MES on a single line will do its own hundreds per shift. Both sequences will race forward from the same starting point. **Collisions are certain within the first full shift.**

## What the collisions break

| System | What breaks | How bad |
|---|---|---|
| **MES genealogy** | `LotGenealogy` / `ConsumptionEvent` link LOTs by LTT number. Two LOTs with the same LTT means the trace query returns the wrong ancestry. | **Critical** — Honda trace is the core contractual deliverable. |
| **AIM shipping IDs** | Honda EDI validates shipper IDs against the parts inside. If two containers present the same LTT on their LOT manifest, AIM will reject or mis-assign. | **High** — shipping rejections cost money and time. |
| **Quality holds** | When Quality places a hold on `MESL1800001`, which LOT gets held? The one in the new MES or the one in Flexware? In the worst case the new MES holds its LOT while the bad parts ship from Flexware's LOT. | **Critical** — safety / recall exposure. |
| **Duplicate detection** | Our `Lot_Create` enforces `LotName UNIQUE`. If we ever cross-import Flexware LOTs into the new MES, we hit constraint violations on overlapping numbers. | **High** — cutover data migration becomes manual cleanup. |
| **Label reprints** | An operator re-prints a damaged label from the new MES. The barcode gets applied but now matches a Flexware LOT. | **Medium** — daily noise, genealogy corruption. |

Note this is only the LTT counter. The serialized-item counter (`MESI{0:D7}`) has the same problem if any AP4-A2 production is serialized (it's not — AP4-A2 is cast, not assembly — but serialized lines like 5G0-A1 and 5G0-A2 get the same analysis if they move into the phased rollout).

---

## Three mitigations that make single-line viable

### Option A — **Prefix split** (cleanest, operationally simple)

Change the new MES's counter format to a different prefix at cutover day. Flexware continues minting `MESL{0:D7}`; new MES mints something like `MESM{0:D7}` or `NEWL{0:D7}`, starting from `1`.

**How it works:**
- `Lots.IdentifierSequence` seed: `FormatString='MESM{0:D7}'`, `LastValue=0`.
- No numeric overlap possible regardless of what Flexware does.
- Post-full-cutover: either stay with `MESM` (accept the fork in history) or run a renaming migration to merge namespaces.

**Pros:** Guaranteed-no-collision. Zero coordination with Flexware's runtime. Easiest to explain to operators ("if it starts with M, it's the new system").

**Cons:** Honda may care about LTT format continuity on shipping labels. The AIM contract (FDS-07-010 / §13.1) needs to confirm it accepts both formats for the transition period. The Zebra ZPL templates need to render the new format. History reports that filter on `MESL` stop catching new-MES rows unless the filter is generalized.

**Risk rating:** Low-medium. Technically clean. Upstream confirmation needed from Honda/AIM.

### Option B — **Range partition** (works if Flexware can be configured)

Reserve a numeric range for each system. Flexware is told: "never mint past `3,000,000`." New MES seeds at `3,000,001` and goes up from there.

**How it works:**
- We'd need to modify Flexware's `IdentifierFormat.EndingValue` (or equivalent) to cap it at 3M.
- Our seed: `StartingValue=3000001, LastValue=3000000`.
- Both systems mint in their own range. No overlap.

**Pros:** Keeps `MESL` prefix everywhere — Honda/AIM sees no format change. Zero impact on shipping labels.

**Cons:** **Requires a Flexware-side change.** Someone (Ben? Flexware vendor?) has to modify the running system to respect the cap. If nobody will touch Flexware, this is off the table. Also: if Flexware hits the cap before we fully retire it, production stops until we lift the cap — so Flexware needs monitoring on its remaining range (say, alert at 2.8M). Operational burden during the rollout.

**Risk rating:** Medium. The technical design is sound; the risk is organizational (who changes Flexware) and operational (monitoring the cap).

### Option C — **New MES calls Flexware as the counter authority** (worst of both worlds, documented for completeness)

The new MES doesn't mint numbers itself during the phased rollout. It calls Flexware's `IdentifierFormat_Next` (or equivalent stored proc) every time it needs a new LTT. Flexware remains the single source of truth for the counter until fully retired.

**Pros:** No risk of collision — one system mints.

**Cons:** Hard dependency on a system being retired. Every LOT-create in the new MES now has a cross-DB call to an old system. If Flexware goes down, the new MES can't print labels. When Flexware is finally turned off, we need a hard cutover of the counter-ownership anyway — same work as Option A, deferred. And we've added a runtime coupling to a system we're trying to escape.

**Risk rating:** High. Not recommended. Listed only so Ben knows we considered it.

---

## Other concerns I'd raise at the same meeting

Even with counter collisions solved, the single-line rollout surfaces other dependencies that are worth discussing together:

**1. Genealogy across the line boundary.** If AP4-A2 is the single line and its upstream (Casting C1, Tumbling T1, Machining M1) stays on Flexware, then the trim / assembly LOTs in the new MES will consume cast LOTs that exist only in Flexware's DB. Our `ConsumptionEvent.SourceLotId FK → Lots.Lot.Id` can't reference a row in a different database. Options: (a) daily import of Flexware's LOTs into our `Lots.Lot` read-only, (b) cross-DB views, (c) accept broken upstream genealogy for the transition period and rebuild when the rest cuts over.

**2. AIM hold state.** When Honda reports a defect on a LOT shipped during the transition, who places the hold in which system? If the defective container was built in new-MES-era AP4-A2 but also contained 6B2 Cam Holder parts from Flexware-era 5G0, both systems need to hold something. We'd need a shared convention: every AIM hold fires on both systems for the transition period, or one system is authoritative and the other polls.

**3. BOM drift.** Engineering changes a BOM in Flexware. Does the new MES pick it up? If BOM ownership is unclear, the new MES may build parts with a stale BOM version. OI-13 (BOM source at Flexware @.919) covers the one-shot cutover case; the transition period needs a polling or daily-sync arrangement.

**4. Reports and OEE.** If the business expects consolidated shift reports across the plant, having half the data in one MES and half in the other breaks the existing reports. Either reports run twice (ugly), or someone builds a union view, or we accept losing the plant-level report for the transition.

**5. Training and operator rotation.** Operators who rotate between AP4-A2 and other lines have to use both UIs every shift. Error rate goes up during the transition. Low-priority from a design perspective, high-priority from an operational one.

---

## My recommendation

- **Don't proceed with single-line rollout without one of Options A / B explicitly chosen up front.** Going in without a plan = collisions in the first shift.
- **Option A (prefix split) is my recommended path** if single-line is the rollout shape. It is technically clean, requires zero Flexware change, and only needs a Honda/AIM confirmation that both LTT formats are acceptable in-flight. Get that confirmation before committing to a date.
- **Option B (range partition) is viable** if Ben's team can modify Flexware's `IdentifierFormat.EndingValue` and will commit to the monitoring discipline.
- **Option C (authority is Flexware) is not recommended.**
- **Alternatively — and this is the case I'd actually argue for — do a full-plant cutover weekend** rather than a phased rollout. The LTT counter problem goes away (one system, one counter, one moment of handoff). The BOM drift problem goes away. The report problem goes away. The operator training problem compresses to one focused week. A single-line rollout is attractive because it feels like lower risk, but the inter-system issues it creates are actually **higher** risk than a committed cutover weekend.

If the customer's ask is "do a single-line first to de-risk the UI / terminal hardware / operator training," there's a simpler alternative: **deploy the new MES in parallel / shadow mode on a single line** — operators enter data into both systems for two weeks, we compare outputs, find the gaps, and then do a full-plant cutover. Shadow mode avoids the identifier collision problem entirely (only Flexware is authoritative; the new MES is reading and validating, not minting).

---

## What we need from Ben to close OI-31 on this front

1. **Which rollout shape is MPP actually committing to** — single-line, full cutover weekend, or shadow?
2. **If single-line:** which mitigation (A / B / C), and is Honda/AIM format-change acceptance in hand?
3. **If full cutover:** what's the target date, and who owns the Flexware-DB export of `IdentifierFormat.LastCounterValue` at T-minus-0?
4. **Either way:** confirm the Flexware `IdentifierFormat` table still contains only the two rows (`Lot`, `SerializedItem`) — no counters we haven't seen.

Item 4 is independent of rollout shape and is already the open counter-inventory question in OI-31. Items 1–3 are new and are what this memo is really about.

---

## Revision History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-04-24 | Blue Ridge Automation | Initial memo for Ben — OI-31 impact under a single-line deployment proposal. Three mitigation options + recommendation + ancillary concerns + ask-list. |
