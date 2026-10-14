// Builds the iOS app icon set and launch image from the Android ones, so both
// platforms show the same logo: node tool/gen_ios_icons.mjs
// (uses sharp from ../my-app/node_modules).
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";

const require = createRequire(import.meta.url);
const sharp = require("../../my-app/node_modules/sharp");

const res = "android/app/src/main/res/mipmap-xxxhdpi";
const iconDir = "ios/Runner/Assets.xcassets/AppIcon.appiconset";
const launchDir = "ios/Runner/Assets.xcassets/LaunchImage.imageset";

// iOS icons must be square and opaque (iOS rounds the corners itself): the
// adaptive-icon foreground on its #151515 background, like on Android.
const master = await sharp(`${res}/ic_launcher_foreground.png`)
  .resize(1024, 1024, { kernel: "lanczos3" })
  .flatten({ background: "#151515" })
  .removeAlpha()
  .png()
  .toBuffer();

const contents = JSON.parse(readFileSync(`${iconDir}/Contents.json`, "utf8"));
for (const image of contents.images) {
  const size = Math.round(parseFloat(image.size) * parseInt(image.scale));
  await sharp(master).resize(size, size, { kernel: "lanczos3" }).png().toFile(`${iconDir}/${image.filename}`);
}

// Launch screen: the logo on black (the storyboard's background is black too).
for (const [file, size] of [["LaunchImage.png", 128], ["LaunchImage@2x.png", 256], ["LaunchImage@3x.png", 384]]) {
  await sharp(`${res}/launch_image.png`).resize(size, size, { kernel: "lanczos3" }).png().toFile(`${launchDir}/${file}`);
}
console.log("iOS icons + launch image written");
