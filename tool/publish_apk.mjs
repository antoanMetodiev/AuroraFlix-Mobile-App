// Puts the release APK and its version.json into the website's
// public/downloads/ — committing and pushing my-app then deploys both.
//
//   node tool/publish_apk.mjs "Bulgarian release notes" "English release notes"
//   node tool/publish_apk.mjs --tv "Bulgarian release notes" "English release notes"
//
// Run after `shorebird release android --artifact apk --target-platform android-arm64`.
// With --tv, after `flutter build apk --release --target-platform android-arm`:
// the 32-bit build Android TVs need, published as auroraflix-tv.apk under
// version.json's "tv" key, with a version of its own.
// Small Dart-only changes don't need this: `shorebird patch android` reaches
// every installed app by itself.
import { copyFileSync, existsSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const downloads = join(root, '..', 'my-app', 'public', 'downloads');

const version = readFileSync(join(root, 'pubspec.yaml'), 'utf8').match(/^version:\s*([\d.]+)\+(\d+)/m);
if (!version) throw new Error('No version: x.y.z+N in pubspec.yaml');
const [, versionName, versionCode] = version;

const apk = join(root, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const size = statSync(apk).size;
// Cloudflare Workers serves static assets up to 25 MiB each.
if (size > 25 * 1024 * 1024) throw new Error(`APK is ${(size / 1048576).toFixed(1)} MiB — over Cloudflare's 25 MiB limit`);

const args = process.argv.slice(2);
const tv = args[0] === '--tv';
const [bg = '', en = bg] = tv ? args.slice(1) : args;
const file = tv ? 'auroraflix-tv.apk' : 'auroraflix.apk';

copyFileSync(apk, join(downloads, file));
const release = {
  versionCode: Number(versionCode),
  versionName,
  url: `https://auroraflix.cloud/downloads/${file}`,
  notes: { bg, en },
};
// Each build leaves the other one's entry as it was.
const manifestPath = join(downloads, 'version.json');
const current = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, 'utf8')) : {};
const manifest = tv ? { ...current, tv: release } : { ...release, ...(current.tv && { tv: current.tv }) };
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Published ${tv ? 'TV ' : ''}${versionName} (${versionCode}), ${(size / 1048576).toFixed(1)} MiB`);
