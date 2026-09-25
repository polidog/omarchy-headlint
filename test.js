const assert = require("assert")
const M = require("./Model.js")
const r = M.parse(JSON.stringify({ url: "https://polidog.jp", ok: false, sections: [
  { name: "OGP", items: [
    { label: "title", level: "warn", value: "polidog lab  [11文字・幅11] 短すぎ" },
    { label: "description", level: "ok", value: "個人サイト  [28文字]" },
    { label: "og:title", level: "info", value: "" },
    { label: "og:image", level: "ok", value: "https://polidog.jp/og.jpg" },
    { label: "og:url", level: "ok", value: "https://polidog.jp/" },
  ] },
  { name: "Favicon", items: [
    { label: "icon 32x32", level: "ok", value: "https://polidog.jp/icon-32.png  (200 image/png 0.9KB)" },
    { label: "/favicon.ico", level: "ok", value: "https://polidog.jp/favicon.ico  (200 image/vnd.microsoft.icon 7.2KB)" },
    { label: "icon", level: "ok", value: "https://polidog.jp/icon-32.png  (200 image/png 0.9KB)" },
    { label: "apple-touch-icon", level: "ng", value: "https://polidog.jp/x.png  (404)" },
    { label: "manifest", level: "ok", value: "https://polidog.jp/site.webmanifest  (200)" },
  ] },
] }))
const p = M.preview(r)
assert.strictEqual(p.title, "polidog lab")        // og:title empty -> title, hint stripped
assert.strictEqual(p.description, "個人サイト")
assert.strictEqual(p.image, "https://polidog.jp/og.jpg")
assert.strictEqual(p.host, "polidog.jp")
assert.deepStrictEqual(M.favicons(r).map(f => f.url), ["https://polidog.jp/icon-32.png", "https://polidog.jp/favicon.ico"])
assert.deepStrictEqual(M.counts(r), { ok: 7, warn: 1, ng: 1, info: 1 })
assert.strictEqual(M.normalizeUrl(" polidog.jp "), "https://polidog.jp")
assert.strictEqual(M.normalizeUrl("http://a.b"), "http://a.b")
assert.strictEqual(M.firstUrl("x (200)"), "")
assert.throws(() => M.parse("{}"))
assert.deepStrictEqual(M.uniq(["a", "", "b", "a"]), ["a", "b"])
console.log("ok")
