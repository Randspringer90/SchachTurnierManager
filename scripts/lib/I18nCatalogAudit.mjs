// Parse catalogue data with the existing TypeScript compiler; never import/evaluate it.
export class CatalogError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = code => { throw new CatalogError(code); };
const validKey = value => /^[A-Za-z][A-Za-z0-9]*(?:[._-][A-Za-z0-9]+)*$/.test(value);

export function parseCatalog(source, locale, ts) {
  if (!/^[a-z]{2}$/.test(locale)) fail('INVALID_LOCALE');
  if (typeof source !== 'string' || source.length > 262144) fail('SOURCE_LIMIT');
  const file = ts.createSourceFile(`${locale}.ts`, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  if (file.parseDiagnostics.length) fail('SYNTAX_ERROR');
  let initializer;
  for (const statement of file.statements) {
    if (ts.isImportDeclaration(statement) && statement.importClause?.isTypeOnly) continue;
    if (ts.isTypeAliasDeclaration(statement) || ts.isInterfaceDeclaration(statement) || ts.isEmptyStatement(statement)) continue;
    if (!ts.isVariableStatement(statement)
        || !statement.modifiers?.some(modifier => modifier.kind === ts.SyntaxKind.ExportKeyword)
        || !(statement.declarationList.flags & ts.NodeFlags.Const)
        || statement.declarationList.declarations.length !== 1 || initializer) fail('UNSUPPORTED_STATEMENT');
    const declaration = statement.declarationList.declarations[0];
    if (!ts.isIdentifier(declaration.name) || declaration.name.text !== locale || !declaration.initializer) fail('INVALID_EXPORT');
    initializer = declaration.initializer;
  }
  if (!initializer) fail('MISSING_EXPORT');
  while (ts.isAsExpression(initializer) || ts.isSatisfiesExpression(initializer) || ts.isParenthesizedExpression(initializer)) initializer = initializer.expression;
  if (!ts.isObjectLiteralExpression(initializer)) fail('NON_LITERAL_CATALOG');
  const entries = new Map();
  for (const property of initializer.properties) {
    if (!ts.isPropertyAssignment(property) || !ts.isStringLiteral(property.name)) fail('NON_LITERAL_PROPERTY');
    const key = property.name.text;
    if (!validKey(key)) fail('INVALID_KEY');
    if (entries.has(key)) fail('DUPLICATE_KEY');
    if (!ts.isStringLiteral(property.initializer) && !ts.isNoSubstitutionTemplateLiteral(property.initializer)) fail('NON_LITERAL_VALUE');
    entries.set(key, property.initializer.text);
  }
  return entries;
}

export function placeholders(text) {
  return [...new Set([...text.matchAll(/\{([^{}]+)\}/g)].map(match => match[1]))].sort();
}

export function auditCatalogs(catalogs, { requireComplete = false } = {}) {
  const base = catalogs.get('de');
  if (!(base instanceof Map) || base.size === 0) fail('MISSING_BASE_CATALOG');
  const keys = [...base.keys()].sort();
  const rows = [];
  let errors = 0; let missing = 0;
  for (const [locale, values] of [...catalogs].sort(([a], [b]) => a.localeCompare(b, 'en'))) {
    const missingKeys = keys.filter(key => !values.has(key));
    const unknownKeys = [...values.keys()].filter(key => !base.has(key)).sort();
    const emptyKeys = [...values].filter(([, text]) => !text.trim()).map(([key]) => key).sort();
    const placeholderErrors = [];
    for (const key of keys) {
      if (!values.has(key) || !values.get(key).trim()) continue;
      const expected = placeholders(base.get(key)); const actual = placeholders(values.get(key));
      if (JSON.stringify(expected) !== JSON.stringify(actual)) placeholderErrors.push({ key, expected, actual });
    }
    errors += unknownKeys.length + emptyKeys.length + placeholderErrors.length;
    missing += missingKeys.length;
    rows.push({ locale, translated: keys.length - missingKeys.length - emptyKeys.filter(key => base.has(key)).length,
      missingKeys, unknownKeys, emptyKeys, placeholderErrors });
  }
  const status = errors || (requireComplete && missing) ? 'FAIL' : missing ? 'PARTIAL' : 'PASS';
  return { schemaVersion: 1, status, valid: status !== 'FAIL', baseKeys: keys.length, catalogCount: rows.length,
    missingTranslations: missing, errors, requireComplete, catalogs: rows };
}
