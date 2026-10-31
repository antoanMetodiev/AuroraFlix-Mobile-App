// Builds the Android TV home-screen banner (320×180, xhdpi) from the app
// icon: the logo and the name on the icon's #151515 background.
// node tool/gen_tv_banner.mjs (uses sharp from ../my-app/node_modules).
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";

const require = createRequire(import.meta.url);
const sharp = require("../../my-app/node_modules/sharp");

const [width, height] = [320, 180];
const dir = "android/app/src/main/res/drawable-xhdpi";
mkdirSync(dir, { recursive: true });

const logo = await sharp("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png")
  .trim()
  .resize(84, 84, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
  .png()
  .toBuffer();

const name = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
  <text x="122" y="102" font-family="Segoe UI, Arial, sans-serif" font-size="34" font-weight="600" fill="#ffffff" letter-spacing="-0.5">AuroraFlix</text>
</svg>`);

await sharp({ create: { width, height, channels: 4, background: "#151515" } })
  .composite([
    { input: logo, left: 26, top: 48 },
    { input: name, left: 0, top: 0 },
  ])
  .flatten({ background: "#151515" })
  .png()
  .toFile(`${dir}/tv_banner.png`);

console.log(`${dir}/tv_banner.png`);
