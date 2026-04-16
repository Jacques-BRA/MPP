# MPP MES Configuration Tool — HTML/CSS Mockup Design

**Date:** 2026-04-16
**Author:** Blue Ridge Automation
**Purpose:** Define the UI design for a standalone HTML/CSS mockup of the Configuration Tool. This mockup validates navigation, layout, and information density before Ignition Perspective development begins. It also serves as a customer-facing storyboard for functional design review with MPP.

---

## 1. Deliverable

A single `index.html` file containing all Config Tool screens. Self-contained — no dependencies, no server required. Open in a browser, click through screens. CSS custom properties enable a light/dark theme toggle.

**Not a prototype.** No real data, no API calls. Static HTML with JavaScript for navigation routing and theme switching. Realistic sample data hardcoded per screen.

---

## 2. Page Shell

The outer frame that every screen lives inside. Three zones: header, rail+nav, content.

### 2.1 Header (42px, fixed top)

Identity bar only — no navigation elements.

| Element | Position | Description |
|---|---|---|
| Logo | Left | "MPP" in brand weight + divider + "Configuration Tool" in lighter text |
| Theme toggle | Right | Moon/sun icon button. Toggles `<body class="theme-dark">`. Writes to CSS custom properties. |
| User display | Right | Initials avatar circle (e.g., "JP") + display name |

**Perspective mapping:** Top docked view, fixed 42px height.

### 2.2 Navigation Rail (52px, always visible)

A narrow vertical strip on the left edge showing 5 category icons with tiny labels underneath.

| Category | Icon | Label |
|---|---|---|
| Plant | Factory/building | Plant |
| Parts | Gear | Parts |
| Quality | Checkmark | Quality |
| Operations | Clock | Operations |
| System | Wrench | System |

**Behavior:**
- Clicking a rail icon expands the nav panel (200px) beside it, showing that category's screen entries
- Clicking the same icon again collapses the nav panel back to rail-only
- Clicking a different icon swaps the nav panel content to the new category
- The active category's icon is highlighted (blue background)
- On initial load, nav panel is collapsed — content area shows a landing prompt

**Perspective mapping:** Left docked view. Width toggled between 52px (collapsed) and 252px (expanded) via `onActionPerformed` event on each rail icon. Nav panel content bound to a session custom property `session.custom.activeCategory`.

### 2.3 Nav Panel (200px, toggled by rail)

When expanded, shows screen entries for the active category.

| Category | Screen Entries |
|---|---|
| **Plant** | Plant Hierarchy |
| **Parts** | Item Master, Operation Templates |
| **Quality** | Quality Specs, Defect Codes |
| **Operations** | Downtime Codes, Shift Schedules |
| **System** | Users, Audit Log, Failure Log |

Each entry has a small icon and text label. Active screen is highlighted. Category name appears as a small uppercase label at the top.

### 2.4 Content Area (remaining space)

Fills the area right of the rail+nav. Renders the active screen. A breadcrumb trail at the top shows the path (e.g., "Parts > Item Master > 5G0 Front Cover > Routes").

### 2.5 Theme System

CSS custom properties on `:root` and `.theme-dark` define all colors. The mockup defaults to light mode. A toggle button in the header switches the body class. Both themes define:

- Background (page, panels, cards)
- Text (primary, secondary, muted)
- Borders and dividers
- Accent color (blue for interactive elements)
- Status colors (success/green, warning/amber, error/red, info/blue)
- Badge colors (draft/amber, published/green, deprecated/gray)

---

## 3. Content Layout Patterns

Three reusable patterns compose every screen in the config tool.

### 3.1 Pattern: Tree-Detail

**Structure:** Tree or list on the left (~240px), entity details panel top-right, child collection panel bottom-right.

**Used by:** Plant Hierarchy, Item Master, Operation Templates, Quality Specs.

**Elements:**
- Left panel: search input at top, tree (Plant Hierarchy) or filterable list (Item Master, Quality Specs). Click to select.
- Top-right: detail panel with entity fields in a card. Type/status badge. Save and Deprecate buttons.
- Bottom-right: child collection (attributes, steps, lines, fields) rendered as a table with up/down arrow buttons per row for reordering.

**Key behaviors:**
- Selecting an item in the left panel loads both the top-right and bottom-right panels
- The detail panel fields are persistent — always showing the selected entity's identity (name, code, type)
- For Item Master: the bottom-right area is a tab strip with multiple sub-views (see Section 4.2)

### 3.2 Pattern: List-Detail

**Structure:** Filter panel on the left (~180px), data table filling the remaining width.

**Used by:** Defect Codes, Downtime Codes, Shift Schedules, Users, Audit Log, Failure Log.

**Elements:**
- Filter panel: dropdowns (area, type), search input, "include deprecated" toggle
- Table: sortable columns, row hover highlight, edit button per row, selected row highlight
- Add button in the title bar

### 3.3 Pattern: Builder

**Structure:** Parent entity header + ordered child list with up/down arrows, add/remove.

**Used by:** Route steps, BOM lines, Quality Spec attributes, Operation Template fields, Location attribute definitions. Always appears inside a Tree-Detail screen as the bottom-right panel.

**Elements:**
- Table with sequence number column, up/down arrow buttons column, data columns, remove button column
- Up arrow disabled on first row, down arrow disabled on last row
- Add button in the panel header
- For versioned entities: Draft/Published/Deprecated badge on the parent header drives editability — Published entities show the builder as read-only (no arrows, no add/remove, "New Version" button shown instead)

---

## 4. Screen Specifications

### 4.1 Plant Hierarchy

**Category:** Plant
**Pattern:** Tree-Detail
**Left panel:** Tree view of the ISA-95 hierarchy. Expand/collapse icons per node. Search input filters visible nodes. Nodes show location name + type icon.
**Top-right:** Location Details card — Name, Code, Description (editable). Type/Definition badge (read-only after create). Parent (read-only). Save and Deprecate buttons.
**Bottom-right:** Attributes table — columns: up/down arrows, Attribute Name, Value (editable input), UOM, Required flag. Attributes are driven by the location's LocationTypeDefinition schema.
**Title bar:** "+ Add Location" button (opens modal). Gear icon (opens Location Type Definition Editor modal).
**Modal — Add Location:** Form: select LocationTypeDefinition (dropdown filtered by valid children of the selected parent's tier), Name, Code, Description. Submit calls Location_Create.
**Modal — Location Type Definition Editor:** List of all LocationTypeDefinition rows grouped by LocationType. Add/edit definitions. Embedded sub-table of LocationAttributeDefinition rows per definition (the attribute schema) with up/down arrows for ordering. Add/remove attribute definitions.

### 4.2 Item Master

**Category:** Parts
**Pattern:** Tree-Detail (list variant)
**Left panel:** Filterable item list. Columns: PartNumber, Description, ItemType. Filter by ItemType dropdown, search by part number or description. "Include deprecated" toggle.
**Top-right:** Item Details card (always visible when an item is selected) — PartNumber (immutable after create), ItemType (immutable after create), UOM, Description, MacolaPartNumber, UnitWeight, WeightUOM, DefaultSubLotQty, MaxLotSize. Save and Deprecate buttons.
**Bottom-right:** Tab strip with 5 tabs:

| Tab | Content | Pattern |
|---|---|---|
| **Container Config** | Form: TraysPerContainer, PartsPerTray, IsSerialized, DunnageCode, CustomerCode. Disabled/hidden for non-Finished Good items. | Form fields |
| **Routes** | Version selector dropdown (showing version number + effective date + Draft/Published/Deprecated badge). Selected version shows route steps in Builder pattern. "New Version" button creates a draft clone. | Builder |
| **BOMs** | Version selector dropdown. Selected version shows BOM lines in Builder pattern. Each line: child item (picker), qty per, UOM. "New Version" button. | Builder |
| **Quality Specs** | Read-only list of quality specs linked to this item. Columns: Spec Name, Active Version, Status. "Go to spec" action navigates to the Quality Specs screen with that spec selected. | Read-only list |
| **Eligibility** | Matrix/grid of machines eligible for this item. Rows: machines (Cell-tier locations), grouped by area. Checkboxes toggle eligibility. Filter by area dropdown. | Checkbox matrix |

**Title bar:** "+ Add Item" button (opens modal with required fields).

### 4.3 Operation Templates

**Category:** Parts
**Pattern:** Tree-Detail
**Left panel:** Template list, grouped by area. Shows: template name, area, version number, Draft/Published/Deprecated badge. Filter by area dropdown, search.
**Top-right:** Template Details card — Code (immutable), Name, AreaLocationId (dropdown of Area-tier locations), Description. Version number display. Save, Deprecate, "New Version" buttons. Note: Operation Templates use clone-to-modify versioning (Code + VersionNumber) without a Publish gate — unlike Routes/BOMs/QualitySpecs, there is no Draft/Published distinction. Each version is immediately active. "New Version" clones the current version (including fields) and bumps VersionNumber.
**Bottom-right:** Data Collection Fields builder — columns: up/down arrows, Field Name (from DataCollectionField), IsRequired toggle, Remove button. "Add Field" button opens a picker from the canonical DataCollectionField list.

### 4.4 Quality Specs

**Category:** Quality
**Pattern:** Tree-Detail
**Left panel:** Spec list, filterable by item (part number search/dropdown). Shows: spec name, linked item, active version number, status badge.
**Top-right:** Spec Details card — Name, linked Item (optional), linked OperationTemplate (optional). Version selector dropdown with status badges.
**Bottom-right:** Spec Attributes builder for the selected version — columns: up/down arrows, Attribute Name, DataType, Target, Lower Limit, Upper Limit, UOM, Sample Trigger (dropdown from SampleTriggerCode), Remove. "Add Attribute" button.
**Tab strip:** Attributes (default), Version History.

### 4.5 Defect Codes

**Category:** Quality
**Pattern:** List-Detail
**Filters:** Area dropdown, search (code or description), "include deprecated" toggle.
**Table columns:** Code, Description, Area, IsExcused, Edit button.
**Add/Edit:** Modal form — Code (immutable on edit), Description, Area (dropdown), IsExcused (checkbox).

### 4.6 Downtime Codes

**Category:** Operations
**Pattern:** List-Detail
**Filters:** Area dropdown, Reason Type dropdown (Equipment/Mold/Quality/Setup/Misc/Unscheduled), search, "include deprecated" toggle.
**Table columns:** Code, Description, Area, Reason Type, IsExcused, Edit button.
**Add/Edit:** Modal form — Code (immutable on edit), Description, Area, ReasonType (dropdown), IsExcused.

### 4.7 Shift Schedules

**Category:** Operations
**Pattern:** List-Detail
**Table columns:** Name, Start Time, End Time, Days of Week (visual bitmask — M T W T F S S with filled/unfilled indicators), Effective Date, Edit button.
**Add/Edit:** Modal form — Name, Start Time (time picker), End Time (time picker), Days of Week (7 checkboxes for Mon–Sun), Effective Date (date picker).

### 4.8 Users

**Category:** System
**Pattern:** List-Detail
**Filters:** Search (name or AD account), "include deprecated" toggle.
**Table columns:** DisplayName, AdAccount, ClockNumber, IgnitionRole, Edit button.
**Add/Edit:** Modal form — AdAccount, DisplayName, ClockNumber, IgnitionRole (dropdown: Operator/Quality/Supervisor/Engineering/Admin), optional initial PIN.
**Actions:** Deprecate button (with dependency check warning), PIN Reset button (separate modal).

### 4.9 Audit Log

**Category:** System
**Pattern:** List-Detail
**Filters:** Date range (start/end date pickers), Entity Type dropdown (from LogEntityType), User dropdown (from AppUser), search (description text).
**Table columns:** Timestamp, User, Entity Type, Entity, Event Type, Description. Expandable row detail showing OldValue/NewValue JSON diff.
**Read-only.** No add/edit/delete.

### 4.10 Failure Log

**Category:** System
**Pattern:** List-Detail (with dashboard tiles)
**Top section:** Two summary tiles — "Top Rejection Reasons" (bar chart or ranked list) and "Top Failing Procedures" (bar chart or ranked list). Configurable date window.
**Filters:** Date range, Entity Type, User, Procedure Name dropdown, search.
**Table columns:** Timestamp, User, Entity Type, Procedure, Failure Reason, Attempted Parameters (expandable JSON).
**Read-only.** No add/edit/delete.

---

## 5. Interaction Patterns

### 5.1 Versioned Entity Lifecycle

Entities with Draft/Published/Deprecated states (Routes, BOMs, Quality Spec Versions) follow consistent UX. **Note:** Operation Templates use a simpler clone-to-modify model without a Publish gate — each version is immediately active upon creation. They show only Save, Deprecate, and "New Version" actions.

| State | Badge Color | Editable | Available Actions |
|---|---|---|---|
| **Draft** | Amber/orange | Yes — all fields, child add/remove/reorder | Save, Publish, Deprecate |
| **Published** | Green | No — read-only, children locked | New Version, Deprecate |
| **Deprecated** | Gray | No — read-only | None (view-only for historical reference) |

"New Version" creates a Draft clone of the Published entity, including all children (steps, lines, attributes, fields).

### 5.2 Modals

Used for: Add Item, Add Location, Location Type Definition Editor, Add/Edit code table entries (Defect Codes, Downtime Codes, Shift Schedules, Users), PIN Reset.

Consistent modal pattern:
- Overlay backdrop (semi-transparent)
- Centered card with title bar, form fields, Cancel/Submit buttons
- Validation errors shown inline below fields
- Submit disabled until required fields are filled

### 5.3 Up/Down Arrow Ordering

All sortable child lists use the same interaction:
- Two small stacked arrow buttons (up triangle, down triangle) in the leftmost column
- Up arrow disabled (grayed out) on the first row
- Down arrow disabled on the last row
- Click swaps the row with its neighbor and updates sequence numbers visually
- No drag-and-drop anywhere

### 5.4 Breadcrumbs

Format: `Category > Screen > Entity > Sub-view`

Examples:
- `Plant > Plant Hierarchy`
- `Parts > Item Master > 5G0 Front Cover > Routes`
- `Quality > Defect Codes`
- `System > Failure Log`

Breadcrumb segments are clickable for navigation back up the chain.

### 5.5 Status Messages

After mutation actions (save, deprecate, publish, add, remove), a brief toast notification appears at the top of the content area:
- Success: green bar with message (e.g., "Location saved successfully")
- Error: red bar with message (e.g., "Cannot deprecate: active dependents exist")

In the mockup these are static examples. In Perspective they would bind to the `Status`/`Message` return from stored procedures.

---

## 6. Sample Data

The mockup uses realistic hardcoded data from the MPP domain:

| Screen | Sample Data |
|---|---|
| Plant Hierarchy | MPP > Madison Facility > Die Cast/Trim Shop/Machine Shop areas > DC Machine #7, #12, etc. |
| Item Master | 5G0 Front Cover (Finished Good), 6MA Cam Holder Housing (Pass-Through), PNA Mounting Pin (Component) |
| Operation Templates | Die Cast (Die, Cavity, Weight, Good, Bad), Trim (Weight, Good, Bad), Assembly Front (Serial, Material Verify, Good, Bad) |
| Routes | 5G0: Die Cast > Trim > CNC > Assembly Front > Pack & Ship |
| BOMs | 5G0 Assembly: 1x 5G0 Casting + 2x PNA Pin |
| Quality Specs | 5G0 Flatness spec: surface flatness, bore diameter, porosity visual |
| Defect Codes | DC-0135 Porosity, DC-0136 Cold Shut, MS-0001 Dimensional |
| Downtime Codes | Equipment/Die Stick, Setup/Mold Change, Quality/Hold |
| Shift Schedules | First Shift 6:00–14:00 M–F, Second Shift 14:00–22:00 M–F |
| Users | J. Potgieter (Engineering), Bootstrap Admin (Admin) |

---

## 7. Perspective Translation Notes

Design decisions were validated against Ignition Perspective capabilities:

| Mockup Element | Perspective Component | Notes |
|---|---|---|
| Header bar | Top docked view (42px) | Fixed height, `Icon` + `Label` components |
| Rail + nav panel | Left docked view | Width toggled via `onActionPerformed` between 52px and 252px |
| Rail icons | `Icon` (Material icons) | Bound to `session.custom.activeCategory` |
| Nav panel items | `Flex Repeater` | Data source: static list filtered by active category |
| Content area | Main page view | Swaps embedded views based on `session.custom.activeScreen` |
| Theme toggle | `session.props.theme` | Ignition supports custom theme definitions |
| Tab strip | `Tab Container` | Standard Perspective component |
| Tree view | `Tree` component | Binds to `Location_GetTree` named query |
| Data tables | `Table` component | Named query data source, column config |
| Modals | `Popup` view | Triggered via `system.perspective.openPopup()` |
| Up/down arrows | `Button` components | `onActionPerformed` calls `_MoveUp`/`_MoveDown` named queries |
| Breadcrumb | `Label` with `Flex Container` | Bound to session custom properties |
| Toast notifications | `Message` component or custom docked view | Transient display after mutations |
| User avatar | `Label` in `Flex Container` | Bound to `session.props.auth.user` |

---

## 8. Out of Scope

- **Plant floor screens** (Arc 2) — this mockup covers Configuration Tool only
- **Reference Data Manager** — dropped; code tables are seeded and rarely edited
- **OPC Tag Reference** — dropped; documentation concern, not a config screen
- **Actual Perspective development** — this mockup validates design before any Perspective work
- **Responsive/mobile layout** — config tool is used at engineering desks, not on shop floor tablets
- **Real data or API integration** — all data is hardcoded sample data
- **Print/export** — not needed for the storyboard purpose
