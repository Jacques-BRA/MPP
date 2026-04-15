// Schema-qualifies every backtick-delimited table, procedure, and table.column
// reference in a markdown file, based on a known entity-to-schema map.
//
// Usage: node schema_qualify.js <input.md>
//
// Rules:
//   - Only touches content inside single backticks (`...`) — prose is untouched.
//   - Handles three reference shapes:
//       1. Bare table:          `Location`            -> `Location.Location`
//       2. Stored procedure:    `Location_Create`     -> `Location.Location_Create`
//       3. Table + column:      `Lot.CurrentLocationId` -> `Lots.Lot.CurrentLocationId`
//   - Processes longer entity names before shorter ones so that
//     `LocationTypeDefinition` isn't partially qualified as `Location` or `LocationType`.
//   - Uses a sentinel marker to prevent re-matching already-qualified content.

const fs = require('fs');

const schemaMap = {
  // Location schema
  'LocationAttributeDefinition': 'Location',
  'LocationTypeDefinition':      'Location',
  'LocationAttribute':           'Location',
  'LocationType':                'Location',
  'Location':                    'Location',
  'AppUser':                     'Location',

  // Parts schema
  'OperationTemplate': 'Parts',
  'ContainerConfig':   'Parts',
  'RouteTemplate':     'Parts',
  'ItemLocation':      'Parts',
  'RouteStep':         'Parts',
  'BomLine':           'Parts',
  'ItemType':          'Parts',
  'Item':              'Parts',
  'Bom':               'Parts',
  'Uom':               'Parts',

  // Lots schema
  'GenealogyRelationshipType': 'Lots',
  'LotAttributeChange':        'Lots',
  'LotStatusHistory':          'Lots',
  'ContainerStatusCode':       'Lots',
  'SerializedPart':            'Lots',
  'ContainerSerial':           'Lots',
  'ShippingLabel':             'Lots',
  'LotOriginType':             'Lots',
  'LotStatusCode':             'Lots',
  'ContainerTray':             'Lots',
  'LotGenealogy':              'Lots',
  'LotMovement':               'Lots',
  'Container':                 'Lots',
  'LotLabel':                  'Lots',
  'Lot':                       'Lots',

  // Workorder schema
  'WorkOrderOperation': 'Workorder',
  'ConsumptionEvent':   'Workorder',
  'ProductionEvent':    'Workorder',
  'OperationStatus':    'Workorder',
  'WorkOrderStatus':    'Workorder',
  'RejectEvent':        'Workorder',
  'WorkOrder':          'Workorder',

  // Quality schema
  'QualitySpecAttribute': 'Quality',
  'QualitySpecVersion':   'Quality',
  'QualityAttachment':    'Quality',
  'NonConformance':       'Quality',
  'QualityResult':        'Quality',
  'QualitySample':        'Quality',
  'QualitySpec':          'Quality',
  'DefectCode':           'Quality',
  'HoldEvent':            'Quality',

  // Oee schema
  'DowntimeReasonType': 'Oee',
  'DowntimeReasonCode': 'Oee',
  'DowntimeEvent':      'Oee',
  'ShiftSchedule':      'Oee',
  'OeeSnapshot':        'Oee',
  'Shift':              'Oee',

  // Audit schema — shared procs (treated as "entities" with no proc suffix)
  'Audit_LogInterfaceCall': 'Audit',
  'Audit_LogConfigChange':  'Audit',
  'Audit_LogOperation':     'Audit',
  'Audit_LogFailure':       'Audit',

  // Audit schema — tables
  'LogEntityType': 'Audit',
  'LogEventType':  'Audit',
  'LogSeverity':   'Audit',
  'InterfaceLog':  'Audit',
  'OperationLog':  'Audit',
  'ConfigLog':     'Audit',
  'FailureLog':    'Audit',
};

// Sort entities by length descending so longer matches win
const sortedEntities = Object.keys(schemaMap).sort((a, b) => b.length - a.length);

const MARKER = '\u0001'; // SOH — control char, will never appear in content

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function schemaQualify(content) {
  let result = content;

  for (const entity of sortedEntities) {
    const schema = schemaMap[entity];
    const esc = escapeRegex(entity);

    // 1. Proc pattern: `Entity_Action` — action starts with uppercase, 2+ letters
    // Only matches if backtick is NOT preceded by MARKER (so we don't re-qualify)
    const procRe = new RegExp('`(?!' + MARKER + ')' + esc + '_([A-Z][A-Za-z]+)`', 'g');
    result = result.replace(procRe, '`' + MARKER + schema + '.' + entity + '_$1`');

    // 2. Column pattern: `Entity.ColumnName`
    const colRe = new RegExp('`(?!' + MARKER + ')' + esc + '\\.([A-Z][A-Za-z0-9]*)`', 'g');
    result = result.replace(colRe, '`' + MARKER + schema + '.' + entity + '.$1`');

    // 3. Exact pattern: `Entity`
    const exactRe = new RegExp('`(?!' + MARKER + ')' + esc + '`', 'g');
    result = result.replace(exactRe, '`' + MARKER + schema + '.' + entity + '`');
  }

  // Remove all markers
  result = result.replace(new RegExp(MARKER, 'g'), '');

  return result;
}

// Count backtick-bounded references to a given entity (for before/after stats)
function countRefs(content, entity) {
  const esc = escapeRegex(entity);
  const procRe = new RegExp('`' + esc + '_[A-Z][A-Za-z]+`', 'g');
  const colRe = new RegExp('`' + esc + '\\.[A-Z][A-Za-z0-9]*`', 'g');
  const exactRe = new RegExp('`' + esc + '`', 'g');
  return (content.match(procRe) || []).length
       + (content.match(colRe) || []).length
       + (content.match(exactRe) || []).length;
}

const inputPath = process.argv[2];
if (!inputPath) {
  console.error('Usage: node schema_qualify.js <input.md>');
  process.exit(1);
}

const before = fs.readFileSync(inputPath, 'utf8');

// Before stats
const beforeCounts = {};
for (const entity of sortedEntities) {
  const n = countRefs(before, entity);
  if (n > 0) beforeCounts[entity] = n;
}

const after = schemaQualify(before);

// After stats (should all be zero since we qualified everything)
const afterCounts = {};
for (const entity of sortedEntities) {
  const n = countRefs(after, entity);
  if (n > 0) afterCounts[entity] = n;
}

fs.writeFileSync(inputPath, after);

console.log('Wrote', inputPath);
console.log('\nReferences qualified (entity: count before):');
const sortedBefore = Object.entries(beforeCounts).sort((a, b) => b[1] - a[1]);
for (const [entity, count] of sortedBefore) {
  console.log('  ' + entity.padEnd(35) + count);
}

if (Object.keys(afterCounts).length > 0) {
  console.log('\nWARNING: unqualified references remaining after run:');
  for (const [entity, count] of Object.entries(afterCounts)) {
    console.log('  ' + entity.padEnd(35) + count);
  }
}
