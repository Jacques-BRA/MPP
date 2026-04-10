// Builds reference/seed_data.xlsx by combining the four CSVs into a single Excel workbook,
// one sheet per CSV. Auto-generated derivative — the CSVs are the canonical source.

const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const SEED_DIR = __dirname;
const OUTPUT = path.join(SEED_DIR, '..', 'seed_data.xlsx');

const CSVS = [
  { file: 'machines.csv', sheet: 'Machines' },
  { file: 'opc_tags.csv', sheet: 'OPC Tags' },
  { file: 'downtime_reason_codes.csv', sheet: 'Downtime Codes' },
  { file: 'defect_codes.csv', sheet: 'Defect Codes' },
];

function parseCsv(text) {
  // Simple CSV parser supporting quoted fields with embedded commas
  const rows = [];
  const lines = text.split(/\r?\n/);
  for (const line of lines) {
    if (!line) continue;
    const fields = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (inQuotes) {
        if (c === '"') {
          if (line[i + 1] === '"') { cur += '"'; i++; }
          else inQuotes = false;
        } else cur += c;
      } else {
        if (c === '"') inQuotes = true;
        else if (c === ',') { fields.push(cur); cur = ''; }
        else cur += c;
      }
    }
    fields.push(cur);
    rows.push(fields);
  }
  return rows;
}

const wb = XLSX.utils.book_new();

for (const { file, sheet } of CSVS) {
  const csvPath = path.join(SEED_DIR, file);
  if (!fs.existsSync(csvPath)) {
    console.error(`Missing: ${csvPath}`);
    continue;
  }
  const text = fs.readFileSync(csvPath, 'utf8');
  const rows = parseCsv(text);
  if (rows.length === 0) continue;

  const ws = XLSX.utils.aoa_to_sheet(rows);

  // Set column widths based on header text and a sample of data
  const headers = rows[0];
  const colWidths = headers.map((h, i) => {
    let maxLen = h.length;
    for (let r = 1; r < Math.min(rows.length, 50); r++) {
      const cellLen = (rows[r][i] || '').length;
      if (cellLen > maxLen) maxLen = cellLen;
    }
    return { wch: Math.min(Math.max(maxLen + 2, 8), 50) };
  });
  ws['!cols'] = colWidths;

  // Freeze the header row
  ws['!freeze'] = { xSplit: 0, ySplit: 1 };

  // Add an autofilter on the data range
  if (rows.length > 1) {
    const lastCol = String.fromCharCode(65 + headers.length - 1);
    ws['!autofilter'] = { ref: `A1:${lastCol}1` };
  }

  XLSX.utils.book_append_sheet(wb, ws, sheet);
  console.log(`Sheet "${sheet}": ${rows.length - 1} data rows, ${headers.length} columns`);
}

XLSX.writeFile(wb, OUTPUT);
console.log(`\nWrote ${OUTPUT}`);
