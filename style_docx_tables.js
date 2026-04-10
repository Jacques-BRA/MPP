// Post-process a pandoc-generated docx to apply bordered + alternating row styling
// to all tables. Runs AFTER pandoc and modifies document.xml directly.
//
// Usage: node style_docx_tables.js <input.docx> [output.docx]
//
// Used together with pandoc + reference.docx:
//   pandoc doc.md -o doc.docx --reference-doc=reference.docx [...]
//   node style_docx_tables.js doc.docx

const fs = require('fs');
const JSZip = require('jszip');

async function styleDocx(inputPath, outputPath) {
  const data = fs.readFileSync(inputPath);
  const zip = await JSZip.loadAsync(data);
  let xml = await zip.file('word/document.xml').async('string');

  xml = xml.replace(/<w:tbl>([\s\S]*?)<\/w:tbl>/g, (match, body) => {
    // Enable banded rows in tblLook
    let newBody = body.replace(
      /<w:tblLook[^/]*\/>/,
      '<w:tblLook w:firstRow="1" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1" w:val="0220"/>'
    );

    // Apply per-row shading: header (row 0) blue, even rows gray
    let rowIndex = 0;
    newBody = newBody.replace(/<w:tr[\s\S]*?<\/w:tr>/g, (rowMatch) => {
      const currentIndex = rowIndex++;
      if (currentIndex === 0) {
        // Header row: dark blue fill, white bold text
        let styled = rowMatch.replace(/<w:tc>/g, '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="1F4E79"/></w:tcPr>');
        styled = styled.replace(/<w:tc><w:tcPr><w:shd[^/]*\/><\/w:tcPr><w:tcPr>/g, '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="1F4E79"/>');
        styled = styled.replace(/<w:r>(\s*<w:t)/g, '<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/></w:rPr>$1');
        return styled;
      } else if (currentIndex % 2 === 0) {
        // Even rows get light gray shading
        let styled = rowMatch.replace(/<w:tc>(?!<w:tcPr>)/g, '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/></w:tcPr>');
        styled = styled.replace(/<w:tc><w:tcPr>(?!<w:shd)/g, '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>');
        return styled;
      }
      return rowMatch;
    });

    // Add borders if not present
    if (!newBody.includes('<w:tblBorders>')) {
      newBody = newBody.replace(
        /(<w:tblPr>[\s\S]*?)(<w:tblLook)/,
        '$1<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="808080"/><w:left w:val="single" w:sz="4" w:space="0" w:color="808080"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="808080"/><w:right w:val="single" w:sz="4" w:space="0" w:color="808080"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/></w:tblBorders>$2'
      );
    }

    return '<w:tbl>' + newBody + '</w:tbl>';
  });

  zip.file('word/document.xml', xml);
  const output = await zip.generateAsync({ type: 'nodebuffer' });
  fs.writeFileSync(outputPath, output);
}

const input = process.argv[2];
const output = process.argv[3] || input;
if (!input) {
  console.error('Usage: node style_docx_tables.js <input.docx> [output.docx]');
  process.exit(1);
}
styleDocx(input, output)
  .then(() => console.log(`Styled: ${output}`))
  .catch(err => { console.error(err); process.exit(1); });
