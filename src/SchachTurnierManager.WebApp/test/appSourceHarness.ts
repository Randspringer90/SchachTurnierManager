import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

// Execute the actual reviewed handler/JSX, not a handwritten copy of its logic.
// Only browser/API/state dependencies are stubbed; no application is launched.
export const appSource = readFileSync(new URL('../src/app/App.tsx', import.meta.url), 'utf8');
const parsed = ts.createSourceFile('App.tsx', appSource, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
function find(predicate: (node: ts.Node) => boolean): ts.Node | undefined {
  let found: ts.Node | undefined;
  function visit(node: ts.Node): void {
    if (found) return;
    if (predicate(node)) found = node;
    else ts.forEachChild(node, visit);
  }
  visit(parsed);
  return found;
}
function execute(code: string, bindings: Record<string, unknown>): any {
  const output = ts.transpileModule(`(${code})`, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.None, jsx: ts.JsxEmit.React },
  }).outputText;
  return vm.runInNewContext(output, bindings);
}
export function appHandler(name: string, bindings: Record<string, unknown>): any {
  const node = find(node => ts.isFunctionDeclaration(node) && node.name?.text === name);
  if (!node) throw new Error(`Missing application handler: ${name}`);
  return execute(node.getText(parsed), bindings);
}
export function hasAppHandler(name: string): boolean {
  return find(node => ts.isFunctionDeclaration(node) && node.name?.text === name) !== undefined;
}
export function appCallback(name: string, bindings: Record<string, unknown>): any {
  const node = find(node => ts.isVariableDeclaration(node) && node.name.getText(parsed) === name);
  if (!node || !ts.isVariableDeclaration(node) || !node.initializer || !ts.isCallExpression(node.initializer)) {
    throw new Error(`Missing application callback: ${name}`);
  }
  return execute(node.initializer.arguments[0].getText(parsed), bindings);
}
export function sourceFunction(url: URL, name: string, bindings: Record<string, unknown> = {}): any {
  const source = ts.createSourceFile(url.pathname, readFileSync(url, 'utf8'), ts.ScriptTarget.Latest, true);
  const node = source.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === name);
  if (!node) throw new Error(`Missing helper: ${name}`);
  return execute(node.getText(source).replace(/^export\s+/, ''), bindings);
}
export function appJsx(marker: string, tag: string, bindings: Record<string, unknown>): any {
  const node = find(node => (ts.isJsxElement(node) && node.openingElement.tagName.getText(parsed) === tag
    && node.openingElement.getText(parsed).includes(marker))
    || (ts.isJsxSelfClosingElement(node) && node.tagName.getText(parsed) === tag && node.getText(parsed).includes(marker)));
  if (!node) throw new Error(`Missing application JSX: ${marker}`);
  return execute(node.getText(parsed), {
    React: { createElement: (type: string, props: unknown, ...children: unknown[]) => ({ type, props, children: children.flat(Infinity) }) },
    ...bindings,
  });
}
export function deferred<T>() {
  let resolve!: (value: T) => void, reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
