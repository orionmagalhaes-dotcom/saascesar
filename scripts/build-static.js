const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dist = path.join(root, "dist");
const files = [
  "index.html",
  "styles.css",
  "app.js",
  "manifest.webmanifest",
  "sw.js",
  "icon.svg",
  "icon-192.png",
  "icon-512.png",
  "apple-touch-icon.png",
  "brand-logo.png",
  "brand-login.png",
  "_headers"
];

function ensureDistReady() {
  if (!fs.existsSync(dist)) {
    fs.mkdirSync(dist, { recursive: true });
    return;
  }

  try {
    fs.rmSync(dist, { recursive: true, force: true });
    fs.mkdirSync(dist, { recursive: true });
  } catch (error) {
    if (error && (error.code === "EPERM" || error.code === "EACCES")) {
      console.warn("[build] Não foi possível limpar dist; continuando com os arquivos existentes.");
      return;
    }
    throw error;
  }
}

ensureDistReady();

for (const file of files) {
  const src = path.join(root, file);
  const dst = path.join(dist, file);

  if (!fs.existsSync(src)) {
    console.warn(`[build] Arquivo nao encontrado, ignorado: ${file}`);
    continue;
  }

  fs.copyFileSync(src, dst);
}

console.log("Build concluido: pasta dist criada com arquivos estaticos.");
