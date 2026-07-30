import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const source = fileURLToPath(new URL(
  "../../App/Assets.xcassets/AppIcon.appiconset/Tali-1024.png",
  import.meta.url,
));
const output = fileURLToPath(new URL("../src/contact-photo.ts", import.meta.url));
const temporaryDirectory = mkdtempSync(join(tmpdir(), "tali-contact-photo-"));
const jpeg = join(temporaryDirectory, "Tali-contact-512.jpg");

try {
  execFileSync("/usr/bin/sips", [
    "-s", "format", "jpeg",
    "-s", "formatOptions", "90",
    "-z", "512", "512",
    source,
    "--out", jpeg,
  ], { stdio: "ignore" });

  const base64 = readFileSync(jpeg).toString("base64");
  const chunks = base64.match(/.{1,100}/g) ?? [];
  const generated = [
    "// Generated from Tali's app icon by `npm run generate:contact-photo`.",
    "// 512 px JPEG for sharp iOS contact previews.",
    "export const contactPhotoBase64 = [",
    ...chunks.map((chunk) => `  "${chunk}",`),
    '].join("");',
    "",
  ].join("\n");
  writeFileSync(output, generated);
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}
