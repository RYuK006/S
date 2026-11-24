// tools/build_web.js
// Concatenates modular web source files into the standalone self-contained index.html
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');
const webDir = path.join(rootDir, 'web');
const outputPath = path.join(rootDir, 'index.html');

console.log("Building standalone self-contained index.html from web modules...");

const modules = [
  'audio.js',
  'physics.js',
  'vehicles.js',
  'weapons.js',
  'tracks.js',
  'combat.js',
  'ai.js',
  'ui.js',
  'main.js'
];

// Syntax check all modules
for (const mod of modules) {
  const modPath = path.join(webDir, mod);
  if (fs.existsSync(modPath)) {
    try {
      execSync(`node --check "${modPath}"`, { stdio: 'pipe' });
    } catch (err) {
      console.error(`Syntax error in ${mod}:`, err.message);
      process.exit(1);
    }
  }
}

// Read template
const templatePath = path.join(webDir, 'template.html');
if (!fs.existsSync(templatePath)) {
  console.error("Missing template.html");
  process.exit(1);
}

let template = fs.readFileSync(templatePath, 'utf8');

// Combine script modules
let combinedScript = "";
for (const mod of modules) {
  const modPath = path.join(webDir, mod);
  if (fs.existsSync(modPath)) {
    const banner = `\n// ============================================================================\n// MODULE: ${mod.toUpperCase()}\n// ============================================================================\n`;
    combinedScript += banner + fs.readFileSync(modPath, 'utf8') + "\n";
  }
}

// Replace script bundle placeholder
const outputHtml = template.replace('/* === BUNDLED_SCRIPTS === */', combinedScript);
fs.writeFileSync(outputPath, outputHtml, 'utf8');

console.log(`Successfully generated index.html (${(fs.statSync(outputPath).size / 1024).toFixed(1)} KB)`);
