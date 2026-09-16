import fs from "node:fs";
import path from "node:path";
import { assetsDir } from "../../paths.js";
const assetPath = path.join(assetsDir, "dashboard", "dashboard-experience.css");
let cached = null;
export function GET(_req, res) {
    if (cached === null)
        cached = fs.readFileSync(assetPath, "utf8");
    res.writeHead(200, { "Content-Type": "text/css; charset=utf-8" });
    res.end(cached);
}
