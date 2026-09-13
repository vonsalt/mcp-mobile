import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const sourcePath = new URL("../connector-src/mobile-connector.luau", import.meta.url);
const servedPath = new URL("../mobile-connector.luau", import.meta.url);
const source = readFileSync(sourcePath, "utf8");
const served = readFileSync(servedPath, "utf8");

assert.equal(served, source, "The served mobile connector must match connector-src/mobile-connector.luau");

assert.match(source, /type\(syn_request\) == "function"/, "global syn_request must be detected");
assert.match(source, /type\(syn\) == "table" and type\(syn\.request\) == "function"/, "syn.request must be detected");
assert.match(source, /HTTPRequest = syn_request/, "global syn_request must be selected as a request transport");
assert.match(source, /HTTPRequest = syn\.request/, "syn.request must remain a request transport fallback");
assert.match(source, /local function HttpGetFallbackRequest/, "http_get must use the shared fallback wrapper");
assert.match(source, /http_get\/http_post cannot send Authorization headers/, "GET-only fallbacks must reject authenticated requests that cannot carry headers");
assert.match(source, /return NormalizedResponse\(fetch\(opts\.Url\)\)/, "http_get GET responses must be normalized");

console.log("mobile HTTP compatibility test passed");
