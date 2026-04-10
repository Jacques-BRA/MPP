// Parses Appendix C (OPC Tags) from the FRS PDF text extract.
//
// Input:  _appendix_c_raw.txt (output of `pdftotext -table -f 87 -l 91 reference/MPP_FRS_Draft.pdf`)
// Output: opc_tags.csv
//
// 5 columns: ServerName, ServerPid, Direction, AccessPath, OpcItemId
// Strategy: split each row by 2+ whitespace. 4 fields = no AccessPath; 5 fields = AccessPath present.

const fs = require('fs');
const path = require('path');

const INPUT = process.argv[2] || path.join(__dirname, '..', '_appendix_c_raw.txt');
const OUTPUT = process.argv[3] || path.join(__dirname, '..', 'opc_tags.csv');

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

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;

    // Skip headers, footers, page boundaries
    if (/^Appendix C\.|^MADISON PRECISION|^FUNCTIONAL REQUIREMENT|^\s*\d+\s+OF\s+\d+|SECTION 6|^\s*OPC\s*$|^\s*Server\s*$|^\s*Name\s*$|^\s*PID\s*$|^\s*\(omni|^3\/15\/2024/.test(line)) continue;

    // Data rows must start with "Omni" or "TOP" after leading whitespace
    if (!/^\s*(Omni|TOP)\s/.test(line)) {
      warnings.push({ line: i + 1, content: line });
      continue;
    }

    // Split by 2+ whitespace
    const parts = line.trim().split(/\s{2,}/);

    let row;
    if (parts.length === 4) {
      // No AccessPath
      row = {
        ServerName: parts[0],
        ServerPid: parts[1],
        Direction: parts[2],
        AccessPath: '',
        OpcItemId: parts[3],
      };
    } else if (parts.length === 5) {
      row = {
        ServerName: parts[0],
        ServerPid: parts[1],
        Direction: parts[2],
        AccessPath: parts[3],
        OpcItemId: parts[4],
      };
    } else {
      warnings.push({ line: i + 1, content: `unexpected ${parts.length} fields: ${line.trim()}` });
      continue;
    }

    rows.push(row);
  }

  return { rows, warnings };
}

function toCsv(rows) {
  const headers = ['ServerName', 'ServerPid', 'Direction', 'AccessPath', 'OpcItemId'];
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

// Sanity: count by ServerName
const counts = {};
for (const r of rows) counts[r.ServerName] = (counts[r.ServerName] || 0) + 1;
console.log(`\nBy server: ${JSON.stringify(counts)}`);
