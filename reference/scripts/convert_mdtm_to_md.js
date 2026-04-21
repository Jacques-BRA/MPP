#!/usr/bin/env node
/*
 * Convert the Flexware "Manufacturing Director Technical Manual" PDF text dump
 * into a cleaned-up Markdown file.
 *
 * Input:  the output of `pdftotext -enc UTF-8 -layout <PDF> -` or a file
 * Output: Markdown with:
 *   - Per-page running footer stripped (Title:/Project:/Last Saved:/Confidential:)
 *   - TOC pages dropped (detected via dot-leader density)
 *   - Numbered sections promoted to Markdown headings (N.0 -> #, N.M -> ##, N.M.K -> ###)
 *   - <!-- Page N --> markers at every page boundary for PDF-page traceability
 *   - Collapsed blank-line runs
 *
 * Usage:
 *   node reference/scripts/convert_mdtm_to_md.js <input.txt> <output.md>
 *   # or with defaults matching the MPP pipeline:
 *   node reference/scripts/convert_mdtm_to_md.js
 */

'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_IN = '.tmp/mdtm_full.txt';
const DEFAULT_OUT = 'reference/Manufacturing_Director_Technical_Manual.md';

const inPath = process.argv[2] || DEFAULT_IN;
const outPath = process.argv[3] || DEFAULT_OUT;

const FOOTER_KEYS = ['Confidential:', 'Last Saved:', 'Project:', 'Title:'];
const TOC_LINE_RE = /\.{4,}\s*\d+\s*$/;
const HEADING_RE = /^(\s*)(\d+(?:\.\d+)+)\s+(.+?)\s*$/;
const TOC_THRESHOLD = 0.3;  // page is TOC if >30% of non-blank lines have dot leaders

function stripFooter(lines) {
    while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
    for (const key of FOOTER_KEYS) {
        if (lines.length && lines[lines.length - 1].trimStart().startsWith(key)) {
            lines.pop();
            while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
        }
    }
    return lines;
}

function isTocPage(lines) {
    const nonBlank = lines.filter(l => l.trim() !== '');
    if (nonBlank.length < 5) return false;
    const hits = nonBlank.filter(l => TOC_LINE_RE.test(l)).length;
    return hits / nonBlank.length > TOC_THRESHOLD;
}

function promoteHeading(line) {
    const m = line.match(HEADING_RE);
    if (!m) return line;
    const num = m[2];
    const title = m[3];
    if (/\.{4,}/.test(title) || /\s+\d+$/.test(title)) return line;
    const parts = num.split('.');
    let depth;
    if (parts.length === 2 && parts[1] === '0') depth = 1;
    else depth = parts.length;
    const hashes = '#'.repeat(Math.min(depth, 6));
    return `${hashes} ${num} ${title}`;
}

function cleanPage(raw, pageNum) {
    let lines = raw.split('\n').map(l => l.replace(/\r$/, ''));
    lines = stripFooter(lines);
    if (lines.length === 0) return null;
    if (isTocPage(lines)) return null;
    lines = lines.map(promoteHeading);
    while (lines.length && lines[0].trim() === '') lines.shift();
    while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
    if (lines.length === 0) return null;
    return `<!-- Page ${pageNum} -->\n\n${lines.join('\n')}`;
}

function main() {
    const raw = fs.readFileSync(inPath, 'utf8');
    const pages = raw.split('\f');
    console.error(`Read ${inPath}: ${pages.length} page blocks, ${raw.length} bytes`);

    let dropped = 0;
    const kept = [];
    pages.forEach((pg, i) => {
        const cleaned = cleanPage(pg, i + 1);
        if (cleaned === null) { dropped++; return; }
        kept.push(cleaned);
    });

    let body = kept.join('\n\n');
    body = body.replace(/\n{3,}/g, '\n\n');

    const header = [
        '<!--',
        '  Generated from: reference/Manufacturing Director Technical Manual.pdf',
        '  Source: Flexware Innovation, project 2008178_VTS_VCMTraceabilitySystem (Feb 2009)',
        '  Pipeline: pdftotext -enc UTF-8 -layout  |  convert_mdtm_to_md.js',
        '  Images NOT extracted in text-first pass — install Poppler and run',
        '  `pdfimages -png -p -f <N> -l <N> <PDF> <outdir>` to pull screenshots on demand.',
        '-->',
        '',
        '# Manufacturing Director — Technical Manual',
        '',
        '> **Legacy reference only.** This is the 2009 Flexware Manufacturing Director technical',
        '> manual for the VCM Traceability System installed at Madison Precision Products —',
        '> the system being replaced by the new Ignition + SQL Server MES. Content preserved',
        '> verbatim from the source PDF; running footers and TOC stripped, headings promoted',
        '> from the original outline numbering. Screenshots are not included; `<!-- Page N -->`',
        '> markers reference the source-PDF page for cross-referencing.',
        ''
    ].join('\n');

    fs.writeFileSync(outPath, header + body + '\n', 'utf8');
    console.error(`Wrote ${outPath}: ${kept.length} pages kept, ${dropped} dropped, ${body.length} chars`);
}

main();
