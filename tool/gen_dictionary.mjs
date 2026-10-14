// Regenerates lib/core/i18n/dictionary.g.dart from the website's own
// dictionary (my-app/lib/i18n/dictionary.ts), so both apps share one source
// of UI copy. Uses my-app's own TypeScript compiler to strip the types.
//
//   node tool/gen_dictionary.mjs [path/to/my-app]
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const appDir = path.resolve(process.argv[2] ?? path.join(root, "..", "my-app"));
const outFile = path.join(root, "lib", "core", "i18n", "dictionary.g.dart");

const require = createRequire(path.join(appDir, "package.json"));
const ts = require("typescript");

const source = fs.readFileSync(path.join(appDir, "lib", "i18n", "dictionary.ts"), "utf8");
const js = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = await import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));

const BACKSLASH = String.fromCharCode(92);
function dartString(value) {
  const escaped = value
    .split(BACKSLASH).join(BACKSLASH + BACKSLASH)
    .split("'").join(BACKSLASH + "'")
    .split("$").join(BACKSLASH + "$")
    .split("\n").join(BACKSLASH + "n");
  return `'${escaped}'`;
}

function block(name, entries) {
  const lines = Object.entries(entries).map(
    ([key, value]) => `  ${dartString(key)}: {'en': ${dartString(value.en)}, 'bg': ${dartString(value.bg)}},`
  );
  return `const Map<String, Map<String, String>> ${name} = {\n${lines.join("\n")}\n};\n`;
}

const output =
  "// GENERATED from my-app/lib/i18n/dictionary.ts by tool/gen_dictionary.mjs.\n" +
  "// Do not edit by hand — change the website's dictionary and regenerate.\n\n" +
  block("dictionary", mod.dictionary) +
  "\n" +
  block("genreTranslations", mod.GENRE_TRANSLATIONS);

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, output);
console.log(`${Object.keys(mod.dictionary).length} keys, ${Object.keys(mod.GENRE_TRANSLATIONS).length} genres -> ${outFile}`);
