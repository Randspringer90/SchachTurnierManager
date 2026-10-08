/** Small text-only view helpers, never interpolated HTML. */
export function element(document, tag, text = '') {
  const node = document.createElement(tag); node.textContent = String(text); return node;
}
export function fillChoices(document, select, choices, empty = 'Bitte waehlen') {
  select.replaceChildren(); const first = element(document, 'option', empty); first.value = ''; select.append(first);
  for (const choice of choices) { const option = element(document, 'option', choice.name); option.value = choice.id; select.append(option); }
}
export function tableRows(document, target, rows) {
  target.replaceChildren();
  for (const values of rows) {
    const row = element(document, 'tr');
    for (const value of values) row.append(element(document, 'td', value ?? '-'));
    target.append(row);
  }
}
export function downloadLink(link, text, name, urlApi = URL) {
  const url = urlApi.createObjectURL(new Blob([text], { type: 'application/json;charset=utf-8' }));
  link.href = url; link.download = name; link.hidden = false;
  return () => { urlApi.revokeObjectURL(url); link.removeAttribute('href'); link.hidden = true; };
}
