// Parses Appendix D (Downtime Reason Codes) from the FRS PDF text extract.
//
// 8 columns: ReasonId, ReasonDesc, DeptId, DeptDesc, DeptCode, TypeId, TypeDesc, Excused
//
// Wrapping rule: lines without a leading numeric ID are fragment lines whose tokens are
// prefix-prepended to the columns of the NEXT data row, matched by character position.
//
// Common case: "Machine Shop" gets split into "Machine" (prefix line) + "Shop" (data row).

const fs = require('fs');
const path = require('path');

const INPUT = process.argv[2] || path.join(__dirname, '..', '_appendix_d_raw.txt');
const OUTPUT = process.argv[3] || path.join(__dirname, '..', 'downtime_reason_codes.csv');

function csvEscape(s) {
  if (s == null) return '';
  s = String(s).trim();
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

// Tokenize a line into [{text, col}] pairs by 2+ whitespace
function tokenize(line) {
  const tokens = [];
  const re = /\S(?:[^\s]|\s(?!\s))*/g;  // non-whitespace, allowing single spaces inside
  let m;
  // Simpler: split by 2+ whitespace and recover positions
  let i = 0;
  while (i < line.length) {
    while (i < line.length && line[i] === ' ') i++;
    if (i >= line.length) break;
    const start = i;
    let j = i;
    // Read until 2+ consecutive spaces or end of line
    while (j < line.length) {
      if (line[j] === ' ' && line[j + 1] === ' ') break;
      j++;
    }
    tokens.push({ text: line.substring(start, j).trim(), col: start });
    i = j;
  }
  return tokens;
}

// Determine if a line is a "data row" — leading whitespace then a number followed by 2+ spaces
function isDataRow(line) {
  return /^\s+\d+\s{2,}\S/.test(line);
}

// Determine if a line is a "fragment line" — leading whitespace, no leading number, has content
function isFragmentLine(line) {
  return /^\s{15,}\S/.test(line) && !isDataRow(line);
}

// Skip line — header, footer, page boundary
function isSkipLine(line) {
  if (!line.trim()) return true;
  if (/^Appendix D\.|^MADISON PRECISION|^FUNCTIONAL REQUIREMENT|SECTION 6|^3\/15\/2024|^\s*\d+\s+OF\s+\d+/.test(line)) return true;
  if (/^\s+Reason\s*$/.test(line) || /^\s+Reason Desc/.test(line)) return true;
  if (/^\s+Dept\s+Dept\s+Type\s*$/.test(line)) return true;
  if (/^\s+ID\s+Reason Desc/.test(line)) return true;
  return false;
}

// Parse a data row into a structured row object using token positions
function parseDataRow(line, prefixFragments) {
  const tokens = tokenize(line);
  if (tokens.length < 5) return null;

  // Token 0 = ReasonId
  const reasonId = parseInt(tokens[0].text, 10);
  if (isNaN(reasonId)) return null;

  // Token N-1 (last) = Excused (0 or 1)
  const lastTok = tokens[tokens.length - 1];
  const excused = parseInt(lastTok.text, 10);
  if (excused !== 0 && excused !== 1) return null;

  // Identify DeptCode by looking for a 2-3 letter all-uppercase token
  let deptCodeIdx = -1;
  for (let i = tokens.length - 2; i >= 1; i--) {
    if (/^[A-Z]{2,3}$/.test(tokens[i].text)) {
      deptCodeIdx = i;
      break;
    }
  }
  if (deptCodeIdx === -1) return null;

  // Tokens before DeptCode: ReasonDesc, DeptId, DeptDesc
  // Tokens after DeptCode: TypeId (optional), TypeDesc (optional), Excused

  // Find DeptId — first integer to the left of DeptCode
  let deptIdIdx = -1;
  for (let i = deptCodeIdx - 1; i >= 1; i--) {
    if (/^\d+$/.test(tokens[i].text)) {
      deptIdIdx = i;
      break;
    }
  }
  if (deptIdIdx === -1) return null;

  // ReasonDesc tokens: from index 1 to deptIdIdx-1
  const reasonDescTokens = tokens.slice(1, deptIdIdx);
  // DeptDesc tokens: from deptIdIdx+1 to deptCodeIdx-1
  const deptDescTokens = tokens.slice(deptIdIdx + 1, deptCodeIdx);
  // After DeptCode, before Excused: optional TypeId (integer) and TypeDesc (text)
  const afterDeptCode = tokens.slice(deptCodeIdx + 1, tokens.length - 1);

  let typeId = '';
  let typeDescTokens = [];
  if (afterDeptCode.length >= 1 && /^\d+$/.test(afterDeptCode[0].text)) {
    typeId = parseInt(afterDeptCode[0].text, 10);
    typeDescTokens = afterDeptCode.slice(1);
  } else if (afterDeptCode.length > 0) {
    typeDescTokens = afterDeptCode;
  }

  // Now apply prefix fragments — each fragment has a text and col
  // For each fragment, find which destination column it belongs to by closest data-row token col
  const reasonDescStartCol = reasonDescTokens.length > 0 ? reasonDescTokens[0].col : tokens[1].col;
  const deptDescStartCol = deptDescTokens.length > 0 ? deptDescTokens[0].col : tokens[deptIdIdx + 1]?.col ?? 0;
  const typeDescStartCol = typeDescTokens.length > 0 ? typeDescTokens[0].col : 0;

  const reasonDescPrefixes = [];
  const deptDescPrefixes = [];
  const typeDescPrefixes = [];

  for (const fragLine of prefixFragments) {
    const fragTokens = tokenize(fragLine);
    for (const ft of fragTokens) {
      // Determine destination by closest column match
      const distToReason = Math.abs(ft.col - reasonDescStartCol);
      const distToDept = Math.abs(ft.col - deptDescStartCol);
      const distToType = typeDescStartCol > 0 ? Math.abs(ft.col - typeDescStartCol) : Infinity;
      const minDist = Math.min(distToReason, distToDept, distToType);
      if (minDist === distToReason) reasonDescPrefixes.push(ft.text);
      else if (minDist === distToDept) deptDescPrefixes.push(ft.text);
      else typeDescPrefixes.push(ft.text);
    }
  }

  const reasonDesc = (reasonDescPrefixes.join(' ') + ' ' + reasonDescTokens.map(t => t.text).join(' ')).trim().replace(/\s+/g, ' ');
  const deptDesc = (deptDescPrefixes.join(' ') + ' ' + deptDescTokens.map(t => t.text).join(' ')).trim().replace(/\s+/g, ' ');
  const typeDesc = (typeDescPrefixes.join(' ') + ' ' + typeDescTokens.map(t => t.text).join(' ')).trim().replace(/\s+/g, ' ');

  return {
    ReasonId: reasonId,
    ReasonDesc: reasonDesc,
    DeptId: parseInt(tokens[deptIdIdx].text, 10),
    DeptDesc: deptDesc,
    DeptCode: tokens[deptCodeIdx].text,
    TypeId: typeId,
    TypeDesc: typeDesc,
    Excused: excused,
  };
}

function parse(text) {
  const lines = text.split(/\r?\n/);
  const rows = [];
  const warnings = [];
  let prefixBuffer = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (isSkipLine(line)) { continue; }

    if (isDataRow(line)) {
      const row = parseDataRow(line, prefixBuffer);
      if (row) {
        rows.push(row);
      } else {
        warnings.push({ line: i + 1, content: `failed to parse data row: ${line.trim()}` });
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
  const headers = ['ReasonId', 'ReasonDesc', 'DeptId', 'DeptDesc', 'DeptCode', 'TypeId', 'TypeDesc', 'Excused'];
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
  warnings.slice(0, 15).forEach(w => console.log(`  line ${w.line}: ${w.content.trim().substring(0, 100)}`));
  if (warnings.length > 15) console.log(`  ... and ${warnings.length - 15} more`);
}

// Sanity: distribution by dept
const counts = {};
for (const r of rows) counts[r.DeptCode] = (counts[r.DeptCode] || 0) + 1;
console.log(`\nBy dept: ${JSON.stringify(counts)}`);

// Spot check known wrapped row 445
const row445 = rows.find(r => r.ReasonId === 445);
if (row445) console.log(`\nRow 445 spot check: "${row445.ReasonDesc}" / "${row445.DeptDesc}"`);
const row443 = rows.find(r => r.ReasonId === 443);
if (row443) console.log(`Row 443 spot check: "${row443.ReasonDesc}" / "${row443.DeptDesc}"`);
