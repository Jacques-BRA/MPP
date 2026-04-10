// Parses Appendix E (Defect Codes) from the FRS PDF text extract.
//
// Input:  appendix_e_table.txt (output of `pdftotext -table -f 106 -l 110 reference/MPP_FRS_Draft.pdf`)
// Output: defect_codes.csv
//
// Format: each row has 5 columns — DefectCode, DefectDescription, DeptId, DeptDesc, Excused
// Wrapping rule: lines without a leading numeric ID are description prefix fragments for the NEXT data row.

const fs = require('fs');
const path = require('path');

const INPUT = process.argv[2] || path.join(__dirname, '..', '_appendix_e_raw.txt');
const OUTPUT = process.argv[3] || path.join(__dirname, '..', 'defect_codes.csv');

function csvEscape(s) {
  if (s == null) return '';
  s = String(s).trim();
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

function parse(text) {
  const lines = text.split(/\r?\n/);
  const rows = [];
  const warnings = [];
  let prefixBuffer = [];

  // Pattern: leading whitespace, 3-digit defect code, whitespace, description, whitespace, dept id, whitespace, dept desc, whitespace, excused
  // Columns are space-separated but description can contain spaces.
  // Strategy: capture ID at start, then split the remainder by recognizing the rightmost "10  Die Cast  0/1" pattern.
  const dataRowRe = /^\s*(\d{3})\s+(.+?)\s{2,}(\d+)\s{2,}(\S(?:.*?\S)?)\s{2,}([01])\s*$/;

  // Fragment lines: indented text only, no leading digits
  const fragmentRe = /^\s{15,}([A-Za-z(].*?)\s*$/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Skip blank lines
    if (!line.trim()) continue;

    // Skip header/footer junk
    if (/^Appendix E\.|^Defect|^Code\s+Defect|MADISON PRECISION|FUNCTIONAL REQUIREMENT|^\s*\d+\s+OF\s+\d+|SECTION 6/.test(line)) continue;
    if (/^\s+Dept\s+Dept\s*$/.test(line)) continue;
    if (/^\s+Defect\s*$/.test(line)) continue;
    if (/^\s+Code\s+Defect Description/.test(line)) continue;

    // Try to match a data row
    const m = line.match(dataRowRe);
    if (m) {
      const [, code, desc, deptId, deptDesc, excused] = m;
      const fullDesc = (prefixBuffer.join(' ') + ' ' + desc).trim().replace(/\s+/g, ' ');
      rows.push({
        DefectCode: parseInt(code, 10),
        DefectDescription: fullDesc,
        DeptId: parseInt(deptId, 10),
        DeptDesc: deptDesc.trim(),
        Excused: parseInt(excused, 10),
      });
      prefixBuffer = [];
      continue;
    }

    // Try to match a fragment line (description prefix for next row)
    const f = line.match(fragmentRe);
    if (f) {
      const fragment = f[1].trim();
      // Skip if it looks like a column header that snuck through
      if (/^Dept\s+Dept$/.test(fragment) || /^Code\s/.test(fragment)) continue;
      prefixBuffer.push(fragment);
      continue;
    }

    // Anything else: warn
    warnings.push({ line: i + 1, content: line });
  }

  return { rows, warnings };
}

function toCsv(rows) {
  const headers = ['DefectCode', 'DefectDescription', 'DeptId', 'DeptDesc', 'Excused'];
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
  warnings.slice(0, 10).forEach(w => console.log(`  line ${w.line}: ${w.content.trim().substring(0, 80)}`));
  if (warnings.length > 10) console.log(`  ... and ${warnings.length - 10} more`);
}

// Sanity check: verify the wrapped row 122 worked
const row122 = rows.find(r => r.DefectCode === 122);
if (row122) {
  console.log(`\nWrapped row check — Code 122: "${row122.DefectDescription}"`);
}
