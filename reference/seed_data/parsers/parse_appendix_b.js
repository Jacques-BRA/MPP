// Parses Appendix B (Machines and Processes) from the FRS PDF text extract.
//
// 16 columns:
//   MachId, MachNo, MachDesc, Tonnage, DeptDesc, MinPerShift, RefCycleTime, ProdPerShift,
//   CycleTime, OeeTarget, PlannedQty100p, DeptCode, DeptCode2Desc, ProcId, ProcDesc, OrigProc
//
// Reliable anchors per row:
//   - MachId: leading integer
//   - MachNo: second integer
//   - DeptCode: 2-3 letter all-uppercase token (DC, MS, TS, PC, AS)
//   - OrigProc: trailing 0 or 1
//   - ProcDesc: alphabetic word right before OrigProc
//
// Wrapping rule: fragment lines (no leading ID) carry text fragments that belong to columns
// of the NEXT data row, matched by character position.

const fs = require('fs');
const path = require('path');

const INPUT = process.argv[2] || path.join(__dirname, '..', '_appendix_b_raw.txt');
const OUTPUT = process.argv[3] || path.join(__dirname, '..', 'machines.csv');

function csvEscape(s) {
  if (s == null) return '';
  s = String(s).trim();
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

// Tokenize: capture (text, col) pairs separated by 2+ whitespace
function tokenize(line) {
  const tokens = [];
  let i = 0;
  while (i < line.length) {
    while (i < line.length && line[i] === ' ') i++;
    if (i >= line.length) break;
    const start = i;
    let j = i;
    while (j < line.length) {
      if (line[j] === ' ' && line[j + 1] === ' ') break;
      j++;
    }
    tokens.push({ text: line.substring(start, j).trim(), col: start });
    i = j;
  }
  return tokens;
}

function isDataRow(line) {
  // Leading whitespace + integer + 2+ spaces + content
  return /^\s+\d+\s{2,}\S/.test(line);
}

function isFragmentLine(line) {
  return /^\s{15,}\S/.test(line) && !isDataRow(line);
}

function isSkipLine(line) {
  if (!line.trim()) return true;
  if (/^Appendix B\.|^MADISON PRECISION|^FUNCTIONAL REQUIREMENT|SECTION 6|^3\/15\/2024|^\s*\d+\s+OF\s+\d+/.test(line)) return true;
  if (/^\s+Min\s+Ref\s+Prod/.test(line)) return true;
  if (/^\s+Mach\s+Mach/.test(line)) return true;
  if (/^\s+ID\s+No\s+Mach Desc/.test(line)) return true;
  if (/^\s+Per\s+Cycle\s+Per/.test(line)) return true;
  return false;
}

function isInt(s) { return /^\d+$/.test(s); }
function isDecimalish(s) { return /^[\d.]+$/.test(s); }
function isUpperShortCode(s) { return /^[A-Z]{2,3}$/.test(s); }

// Partial row: PDF source has only MachId, MachNo, MachDesc, [Tonnage], [some numerics]
// — no DeptCode, DeptDesc, ProcId, ProcDesc, OrigProc visible
function parsePartialRow(tokens, prefixFragments) {
  // Try wrapped-desc-suffix merge first
  const merged = mergeWrappedDescSuffix(tokens, prefixFragments);
  tokens = merged.tokens;
  prefixFragments = merged.prefixFragments;

  // tokens[0]=MachId, tokens[1]=MachNo
  // remaining tokens: MachDesc (text, possibly multi) + optional numerics
  // Partial rows on page 85 have NO Tonnage — leave it empty and put all numerics into MinPerShift+
  const remaining = tokens.slice(2);
  let machDescTokens = [];
  const numericLefts = [];

  let mode = 'machDesc';
  for (const t of remaining) {
    if (mode === 'machDesc' && !isDecimalish(t.text)) {
      machDescTokens.push(t);
    } else if (isDecimalish(t.text)) {
      numericLefts.push(t.text);
      mode = 'numerics';
    }
  }
  // tonnage is always empty for partial rows
  const tonnage = '';

  // Apply prefix fragments — for partial rows, all fragments go to MachDesc since
  // we don't have other text columns to disambiguate against
  const machDescPrefixes = [];
  for (const fragLine of prefixFragments) {
    const fragTokens = tokenize(fragLine);
    for (const ft of fragTokens) {
      machDescPrefixes.push(ft.text);
    }
  }

  const machDesc = (machDescPrefixes.join(' ') + ' ' + machDescTokens.map(t => t.text).join(' '))
    .trim()
    .replace(/\s+/g, ' ');

  const numericNames = ['MinPerShift', 'RefCycleTime', 'ProdPerShift', 'CycleTime', 'OeeTarget', 'PlannedQty100p'];
  const numericMap = {};
  for (let i = 0; i < numericNames.length; i++) {
    numericMap[numericNames[i]] = i < numericLefts.length ? numericLefts[i] : '';
  }

  return {
    MachId: parseInt(tokens[0].text, 10),
    MachNo: tokens[1].text,
    MachDesc: machDesc,
    Tonnage: tonnage,
    DeptDesc: '',
    MinPerShift: numericMap.MinPerShift,
    RefCycleTime: numericMap.RefCycleTime,
    ProdPerShift: numericMap.ProdPerShift,
    CycleTime: numericMap.CycleTime,
    OeeTarget: numericMap.OeeTarget,
    PlannedQty100p: numericMap.PlannedQty100p,
    DeptCode: '',
    DeptCode2Desc: '',
    ProcId: '',
    ProcDesc: '',
    OrigProc: '',
  };
}

// Known DeptDesc tokens (single-token, possibly wrapped suffix forms)
// Used to disambiguate the left-side column boundary between MachDesc and DeptDesc
const KNOWN_DEPT_DESC_SUFFIXES = new Set([
  'Die Cast', 'Trim Shop', 'Machine Shop', 'Assembly', 'Prod. Control',
  'Shop', 'Cast', 'Control', // wrapped suffixes (after a "Machine" / "Die" / "Trim" / "Prod." prefix)
]);

// Detect if a prefix line has a fragment that ends with a hyphen at approximately
// the same column as the first post-MachNo token on the data row.
// Used to merge wrapped MachDesc where the suffix is purely numeric (e.g., "Side Case OP30-" + "2" → "Side Case OP30-2")
function mergeWrappedDescSuffix(tokens, prefixFragments) {
  if (tokens.length < 3) return { tokens, prefixFragments };
  const firstDescTok = tokens[2]; // first token after MachId/MachNo
  if (!isInt(firstDescTok.text)) return { tokens, prefixFragments }; // only merge if it's numeric

  // Look for a prefix fragment at approximately the same column ending with a hyphen
  for (let pi = prefixFragments.length - 1; pi >= 0; pi--) {
    const fragLine = prefixFragments[pi];
    const fragTokens = tokenize(fragLine);
    for (const ft of fragTokens) {
      if (Math.abs(ft.col - firstDescTok.col) <= 4 && /-$/.test(ft.text)) {
        // Merge: replace the data row's first desc token with prefix + data
        const merged = ft.text + firstDescTok.text;
        const newTokens = [...tokens];
        newTokens[2] = { text: merged, col: ft.col };
        // Remove this fragment from the prefix line (rebuild it without this token)
        const newFragLine = fragLine.replace(ft.text, ' '.repeat(ft.text.length));
        const newPrefixFragments = [...prefixFragments];
        newPrefixFragments[pi] = newFragLine;
        return { tokens: newTokens, prefixFragments: newPrefixFragments };
      }
    }
  }
  return { tokens, prefixFragments };
}

function parseDataRow(line, prefixFragments) {
  let tokens = tokenize(line);
  if (tokens.length < 3) return null;

  // Validate: token 0 must be integer (MachId), token 1 must be integer (MachNo)
  if (!isInt(tokens[0].text) || !isInt(tokens[1].text)) return null;

  // Try to merge wrapped MachDesc with numeric suffix
  const merged = mergeWrappedDescSuffix(tokens, prefixFragments);
  tokens = merged.tokens;
  prefixFragments = merged.prefixFragments;

  // Find DeptCode — rightmost 2-3 letter uppercase token
  let deptCodeIdx = -1;
  for (let i = tokens.length - 2; i >= 2; i--) {
    if (isUpperShortCode(tokens[i].text)) {
      deptCodeIdx = i;
      break;
    }
  }

  // PARTIAL ROW: no DeptCode found. Parse only the left-side fields and return.
  if (deptCodeIdx === -1) {
    return parsePartialRow(tokens, prefixFragments);
  }

  // Find OrigProc — last token, must be 0 or 1
  const lastTok = tokens[tokens.length - 1];
  let origProc = '';
  if (lastTok.text === '0' || lastTok.text === '1') {
    origProc = parseInt(lastTok.text, 10);
  }

  // Tokens after DeptCode and before OrigProc are: DeptCode2Desc (text), ProcId (int), ProcDesc (text)
  // Pattern: DeptCode, [text...], [int], [text...], OrigProc
  //   DeptCode2Desc could be 1+ words
  //   ProcId is a single integer
  //   ProcDesc could be 1+ words
  //
  // Strategy: from deptCodeIdx+1, scan forward and find an integer (ProcId).
  // Tokens before that integer are DeptCode2Desc; tokens after are ProcDesc.

  let procIdIdx = -1;
  for (let i = deptCodeIdx + 1; i < tokens.length - 1; i++) {
    if (isInt(tokens[i].text)) {
      procIdIdx = i;
      break;
    }
  }

  let deptCode2DescTokens = [];
  let procIdValue = '';
  let procDescTokens = [];
  if (procIdIdx !== -1) {
    deptCode2DescTokens = tokens.slice(deptCodeIdx + 1, procIdIdx);
    procIdValue = parseInt(tokens[procIdIdx].text, 10);
    procDescTokens = tokens.slice(procIdIdx + 1, tokens.length - (origProc !== '' ? 1 : 0));
  } else {
    deptCode2DescTokens = tokens.slice(deptCodeIdx + 1, tokens.length - (origProc !== '' ? 1 : 0));
  }

  // Parse the LEFT side: tokens 2..deptCodeIdx-1 are MachDesc, Tonnage, DeptDesc, MinPerShift, RefCycleTime, ProdPerShift, CycleTime, OeeTarget, PlannedQty100p
  //
  // Strategy:
  //   - Find the DeptDesc token by matching against KNOWN_DEPT_DESC_SUFFIXES
  //   - Tokens before DeptDesc that are text = MachDesc
  //   - First numeric between MachDesc and DeptDesc = Tonnage (optional)
  //   - Numeric tokens after DeptDesc = MinPerShift, RefCycleTime, ProdPerShift, CycleTime, OeeTarget, PlannedQty100p

  const leftTokens = tokens.slice(2, deptCodeIdx);

  // Find DeptDesc token by known suffix match
  let deptDescIdx = -1;
  for (let i = leftTokens.length - 1; i >= 0; i--) {
    if (KNOWN_DEPT_DESC_SUFFIXES.has(leftTokens[i].text)) {
      deptDescIdx = i;
      break;
    }
  }

  let machDescTokens = [];
  let tonnage = '';
  let deptDescTokens = [];
  const numericLefts = [];

  if (deptDescIdx !== -1) {
    // Tokens before DeptDesc: MachDesc (text) + optional Tonnage (numeric)
    for (let i = 0; i < deptDescIdx; i++) {
      const t = leftTokens[i];
      if (isDecimalish(t.text) && !tonnage) {
        tonnage = t.text;
      } else {
        machDescTokens.push(t);
      }
    }
    deptDescTokens.push(leftTokens[deptDescIdx]);
    // Tokens after DeptDesc: numeric run
    for (let i = deptDescIdx + 1; i < leftTokens.length; i++) {
      const t = leftTokens[i];
      if (isDecimalish(t.text)) numericLefts.push(t.text);
      // Skip stray text tokens after DeptDesc (rare)
    }
  } else {
    // Fallback: original mode-based parsing
    let mode = 'machDesc';
    for (const tok of leftTokens) {
      if (mode === 'machDesc') {
        if (isDecimalish(tok.text)) {
          tonnage = tok.text;
          mode = 'deptDesc';
        } else {
          machDescTokens.push(tok);
        }
      } else if (mode === 'deptDesc') {
        if (isDecimalish(tok.text)) {
          numericLefts.push(tok.text);
          mode = 'numerics';
        } else {
          deptDescTokens.push(tok);
        }
      } else {
        if (isDecimalish(tok.text)) numericLefts.push(tok.text);
        else deptDescTokens.push(tok);
      }
    }
  }

  // numericLefts maps to: MinPerShift, RefCycleTime, ProdPerShift, CycleTime, OeeTarget, PlannedQty100p
  // (in order, though some may be missing if the row is short)
  const numericNames = ['MinPerShift', 'RefCycleTime', 'ProdPerShift', 'CycleTime', 'OeeTarget', 'PlannedQty100p'];
  const numericMap = {};
  for (let i = 0; i < numericNames.length; i++) {
    numericMap[numericNames[i]] = i < numericLefts.length ? numericLefts[i] : '';
  }

  // Apply prefix fragments — distribute by column proximity
  const machDescStartCol = machDescTokens.length > 0 ? machDescTokens[0].col : (tokens[2]?.col ?? 0);
  const deptDescStartCol = deptDescTokens.length > 0 ? deptDescTokens[0].col : 0;
  const deptCode2DescStartCol = deptCode2DescTokens.length > 0 ? deptCode2DescTokens[0].col : 0;
  const procDescStartCol = procDescTokens.length > 0 ? procDescTokens[0].col : 0;

  const machDescPrefixes = [];
  const deptDescPrefixes = [];
  const deptCode2DescPrefixes = [];
  const procDescPrefixes = [];

  for (const fragLine of prefixFragments) {
    const fragTokens = tokenize(fragLine);
    for (const ft of fragTokens) {
      // Distance to each column anchor
      const distances = [];
      if (machDescStartCol > 0) distances.push({ name: 'machDesc', d: Math.abs(ft.col - machDescStartCol) });
      if (deptDescStartCol > 0) distances.push({ name: 'deptDesc', d: Math.abs(ft.col - deptDescStartCol) });
      if (deptCode2DescStartCol > 0) distances.push({ name: 'deptCode2Desc', d: Math.abs(ft.col - deptCode2DescStartCol) });
      if (procDescStartCol > 0) distances.push({ name: 'procDesc', d: Math.abs(ft.col - procDescStartCol) });
      if (distances.length === 0) continue;
      distances.sort((a, b) => a.d - b.d);
      const winner = distances[0].name;
      if (winner === 'machDesc') machDescPrefixes.push(ft.text);
      else if (winner === 'deptDesc') deptDescPrefixes.push(ft.text);
      else if (winner === 'deptCode2Desc') deptCode2DescPrefixes.push(ft.text);
      else procDescPrefixes.push(ft.text);
    }
  }

  const joinDesc = (prefixes, tokenList) =>
    (prefixes.join(' ') + ' ' + tokenList.map(t => t.text).join(' '))
      .trim()
      .replace(/\s+/g, ' ');

  return {
    MachId: parseInt(tokens[0].text, 10),
    MachNo: tokens[1].text,
    MachDesc: joinDesc(machDescPrefixes, machDescTokens),
    Tonnage: tonnage,
    DeptDesc: joinDesc(deptDescPrefixes, deptDescTokens),
    MinPerShift: numericMap.MinPerShift,
    RefCycleTime: numericMap.RefCycleTime,
    ProdPerShift: numericMap.ProdPerShift,
    CycleTime: numericMap.CycleTime,
    OeeTarget: numericMap.OeeTarget,
    PlannedQty100p: numericMap.PlannedQty100p,
    DeptCode: tokens[deptCodeIdx].text,
    DeptCode2Desc: joinDesc(deptCode2DescPrefixes, deptCode2DescTokens),
    ProcId: procIdValue,
    ProcDesc: joinDesc(procDescPrefixes, procDescTokens),
    OrigProc: origProc,
  };
}

function parse(text) {
  const lines = text.split(/\r?\n/);
  const rows = [];
  const warnings = [];
  let prefixBuffer = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (isSkipLine(line)) continue;

    if (isDataRow(line)) {
      const row = parseDataRow(line, prefixBuffer);
      if (row) {
        rows.push(row);
      } else {
        warnings.push({ line: i + 1, content: `failed: ${line.trim().substring(0, 100)}` });
      }
      prefixBuffer = [];
    } else if (isFragmentLine(line)) {
      prefixBuffer.push(line);
    } else {
      warnings.push({ line: i + 1, content: `unrecognized: ${line.trim().substring(0, 80)}` });
    }
  }

  return { rows, warnings };
}

function toCsv(rows) {
  const headers = ['MachId', 'MachNo', 'MachDesc', 'Tonnage', 'DeptDesc', 'MinPerShift', 'RefCycleTime', 'ProdPerShift', 'CycleTime', 'OeeTarget', 'PlannedQty100p', 'DeptCode', 'DeptCode2Desc', 'ProcId', 'ProcDesc', 'OrigProc'];
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map(h => csvEscape(row[h])).join(','));
  }
  return lines.join('\n') + '\n';
}

const text = fs.readFileSync(INPUT, 'utf8');
const { rows, warnings } = parse(text);
fs.writeFileSync(OUTPUT, toCsv(rows));
console.log(`Wrote ${rows.length} rows to ${OUTPUT}`);

if (warnings.length > 0) {
  console.log(`\n${warnings.length} parse warnings:`);
  warnings.slice(0, 15).forEach(w => console.log(`  line ${w.line}: ${w.content.substring(0, 100)}`));
  if (warnings.length > 15) console.log(`  ... and ${warnings.length - 15} more`);
}

// Sanity by department
const counts = {};
for (const r of rows) counts[r.DeptCode] = (counts[r.DeptCode] || 0) + 1;
console.log(`\nBy dept: ${JSON.stringify(counts)}`);

// Spot check known rows
const spot = [1, 80, 188, 191, 230];
for (const id of spot) {
  const r = rows.find(x => x.MachId === id);
  if (r) console.log(`Row ${id}: MachNo=${r.MachNo} MachDesc="${r.MachDesc}" Tonnage=${r.Tonnage} DeptDesc="${r.DeptDesc}" DeptCode=${r.DeptCode}`);
}
