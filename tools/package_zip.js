// tools/package_zip.js
// Creates gridlethal.zip containing the entire project distribution.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log("Packaging GRIDLETHAL distribution into gridlethal.zip...");

// Use PowerShell Compress-Archive for zero external dependency compression
const rootDir = path.resolve(__dirname, '..');
const zipPath = path.join(rootDir, 'gridlethal.zip');

if (fs.existsSync(zipPath)) {
  fs.unlinkSync(zipPath);
}

const cmd = `powershell -Command "Compress-Archive -Path '${rootDir}\\src', '${rootDir}\\tests', '${rootDir}\\tools', '${rootDir}\\web', '${rootDir}\\index.html', '${rootDir}\\project.godot' -DestinationPath '${zipPath}' -Force"`;

try {
  execSync(cmd, { stdio: 'inherit' });
  const stats = fs.statSync(zipPath);
  console.log(`Successfully created gridlethal.zip (${(stats.size / 1024).toFixed(1)} KB)`);
} catch (err) {
  console.error("Packaging failed:", err.message);
  process.exit(1);
}
