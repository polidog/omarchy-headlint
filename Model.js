// Pure helpers for `headlint --json` output. Test: node test.js

function parse(text) {
  var r = JSON.parse(text)
  if (!r || !Array.isArray(r.sections)) throw new Error("sections がありません")
  return r
}

// "polidog.jp" -> "https://polidog.jp"; empty stays empty.
function normalizeUrl(s) {
  s = String(s || "").trim()
  if (!s) return ""
  return /^https?:\/\//i.test(s) ? s : "https://" + s
}

// First http(s) URL inside a headlint value ("https://x/a.png  (200 image/png 1KB)").
function firstUrl(value) {
  var m = String(value || "").match(/https?:\/\/[^\s)]+/)
  return m ? m[0] : ""
}

// headlint appends "  [11文字…]" hints to title/description; drop them for previews.
function stripHint(value) {
  return String(value || "").replace(/\s{2}\[[^\]]*\].*$/, "")
}

function item(result, section, label) {
  var secs = result.sections
  for (var i = 0; i < secs.length; i++) {
    if (secs[i].name !== section) continue
    for (var j = 0; j < secs[i].items.length; j++)
      if (secs[i].items[j].label === label) return secs[i].items[j]
  }
  return null
}

function val(result, section, label) {
  var it = item(result, section, label)
  return it ? stripHint(it.value) : ""
}

// Card preview as SNS / search results would show it.
function preview(result) {
  var title = val(result, "OGP", "og:title") || val(result, "OGP", "title")
  var desc = val(result, "OGP", "og:description") || val(result, "OGP", "description")
  var page = val(result, "OGP", "og:url") || result.url || ""
  var hostMatch = page.match(/^https?:\/\/([^\/]+)/)
  return {
    title: title,
    description: desc,
    image: firstUrl(val(result, "OGP", "twitter:image")) || firstUrl(val(result, "OGP", "og:image")),
    ogImage: firstUrl(val(result, "OGP", "og:image")),
    siteName: val(result, "OGP", "og:site_name"),
    host: hostMatch ? hostMatch[1] : "",
    url: page
  }
}

// Favicon rows that actually fetched, deduped by URL: [{label, url}].
function favicons(result) {
  var out = [], seen = {}
  result.sections.forEach(function(s) {
    if (s.name !== "Favicon") return
    s.items.forEach(function(it) {
      var u = firstUrl(it.value)
      if (!u || it.level === "ng" || seen[u] || /manifest/i.test(it.label)) return
      seen[u] = true
      out.push({ label: it.label, url: u })
    })
  })
  return out
}

function counts(result) {
  var c = { ok: 0, warn: 0, ng: 0, info: 0 }
  result.sections.forEach(function(s) {
    s.items.forEach(function(it) { if (c[it.level] !== undefined) c[it.level]++ })
  })
  return c
}

var MARK = { ok: "✓", warn: "!", ng: "✗", info: "-" }
function mark(level) { return MARK[level] || "?" }

if (typeof module !== "undefined")
  module.exports = { parse: parse, normalizeUrl: normalizeUrl, firstUrl: firstUrl, stripHint: stripHint,
                     preview: preview, favicons: favicons, counts: counts, mark: mark }
