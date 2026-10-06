-- filters/software.lua — Software & Data V1.3
-- Multilingual presentation over the single canonical data/software.yml registry.

local stringify = pandoc.utils.stringify
local project = require("lib.project")
local i18n = require("lib.i18n")

local L = {}
local artifact_type_labels = {}
local software_topic_labels = {}

local function configure_i18n(meta)
  local I = i18n.load(i18n.meta_language(meta))
  L = I.labels or {}
  artifact_type_labels = I.artifact_type_labels or {}
  software_topic_labels = I.software_topic_labels or {}
end

local function tr(key, fallback)
  return i18n.tr(L, key, fallback)
end

local function val(x)
  if x == nil then return nil end
  return stringify(x)
end

local function seq(x)
  local r = {}
  if x == nil then return r end
  for _, v in ipairs(x) do table.insert(r, val(v)) end
  return r
end

local function esc(s)
  s = s or ""
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  s = s:gsub('"', "&quot;")
  return s
end

local function title_of(item)
  return val(item.public_title) or val(item.title) or tr("untitled", "Untitled")
end

local function type_label(item, type_defs)
  local t = val(item.type) or "artifact"

  if artifact_type_labels[t] then
    return i18n.tr(artifact_type_labels, t, t)
  end

  local def = type_defs and type_defs[t]
  return (def and val(def.label)) or t:gsub("-", " "):gsub("^%l", string.upper)
end

local function chips(values)
  if not values or #values == 0 then return "" end
  local out = {}

  for _, key in ipairs(values) do
    local label = i18n.tr(software_topic_labels, key, key:gsub("-", " "))
    table.insert(out, '<span class="artifact-chip">' .. esc(label) .. '</span>')
  end

  return '<div class="artifact-chips">' .. table.concat(out, "") .. '</div>'
end

local function links_html(item)
  if not item.links then return "" end
  local out = {}

  for _, link in ipairs(item.links) do
    local label = val(link.label) or tr("link", "Link")
    local url = val(link.url)

    if url then
      table.insert(out,
        '<a class="artifact-link" href="' .. esc(url) .. '">' .. esc(label) .. '</a>')
    end
  end

  if #out == 0 then return "" end
  return '<div class="artifact-links">' .. table.concat(out, " · ") .. '</div>'
end

local function card_html(item, type_defs, extra_class)
  local meta = {type_label(item, type_defs)}
  local year = val(item.year)
  if year then table.insert(meta, year) end

  local h = {
    '<article class="artifact-card ' .. (extra_class or "") .. '">',
    '<div class="artifact-meta">' .. esc(table.concat(meta, " · ")) .. '</div>',
    '<h3>' .. esc(title_of(item)) .. '</h3>'
  }

  local subtitle = val(item.subtitle)
  local summary = val(item.summary) or ""

  if subtitle then
    table.insert(h, '<div class="artifact-subtitle">' .. esc(subtitle) .. '</div>')
  end
  if summary ~= "" then
    table.insert(h, '<p>' .. esc(summary) .. '</p>')
  end

  table.insert(h, chips(seq(item.topics)))
  table.insert(h, links_html(item))
  table.insert(h, '</article>')
  return table.concat(h, "\n")
end

local function family_block(family, members, type_defs)
  local h = {
    '<section class="artifact-family">',
    '<h3>' .. esc(val(family.title) or val(family.id)) .. '</h3>'
  }

  if family.summary then
    table.insert(h, '<p class="family-summary">' .. esc(val(family.summary)) .. '</p>')
  end

  table.insert(h, '<div class="artifact-grid">')
  for _, item in ipairs(members) do
    table.insert(h, card_html(item, type_defs, "family-member"))
  end
  table.insert(h, '</div></section>')
  return table.concat(h, "\n")
end

local function period_key(year)
  local y = tonumber(year or "")
  if not y then return "undated" end
  if y >= 2020 then return "2020–2026" end
  if y >= 2010 then return "2010–2019" end
  if y >= 2000 then return "2000–2009" end
  return "before-2000"
end

local function period_label(key)
  if key == "before-2000" then return tr("before_2000", "Before 2000") end
  if key == "undated" then return tr("undated", "Undated") end
  return key
end

local function sort_newest(a, b)
  local ya, yb = tonumber(val(a.year) or "0"), tonumber(val(b.year) or "0")
  if ya ~= yb then return ya > yb end
  return title_of(a) < title_of(b)
end

local function render_current(reg)
  local items = reg.current_artifacts or {}
  table.sort(items, function(a,b) return title_of(a) < title_of(b) end)

  local h = {
    '<div class="software-generated">',
    '<h2>' .. esc(tr("current_technological_artifacts",
      "Current Technological Artifacts")) .. ' (' .. #items .. ')</h2>',
    '<div class="artifact-grid">'
  }

  for _, item in ipairs(items) do
    table.insert(h, card_html(item, reg.artifact_types, "current-artifact"))
  end

  table.insert(h, '</div></div>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

local function render_families(reg)
  local all = {}

  for _, section in ipairs({
    "current_artifacts", "software", "technological_products", "research_artifacts"
  }) do
    for _, item in ipairs(reg[section] or {}) do table.insert(all, item) end
  end

  local by_family = {}
  for _, item in ipairs(all) do
    local fid = val(item.family)
    if fid then
      by_family[fid] = by_family[fid] or {}
      table.insert(by_family[fid], item)
    end
  end

  local blocks = {}
  for _, fam in ipairs(reg.families or {}) do
    local members = by_family[val(fam.id)] or {}
    if #members > 0 then
      table.sort(members, sort_newest)
      table.insert(blocks, family_block(fam, members, reg.artifact_types))
    end
  end

  return pandoc.RawBlock("html", table.concat({
    '<div class="software-families-generated">',
    '<h2>' .. esc(tr("technology_families", "Technology Families")) .. '</h2>',
    table.concat(blocks, "\n"),
    '</div>'
  }, "\n"))
end

local function render_archive(reg)
  local items = {}

  for _, section in ipairs({"software", "technological_products", "research_artifacts"}) do
    for _, item in ipairs(reg[section] or {}) do
      if val(item.status) == "historical" then table.insert(items, item) end
    end
  end

  table.sort(items, sort_newest)

  local groups = {
    ["2020–2026"] = {}, ["2010–2019"] = {}, ["2000–2009"] = {},
    ["before-2000"] = {}, ["undated"] = {}
  }
  for _, item in ipairs(items) do
    table.insert(groups[period_key(val(item.year))], item)
  end

  local order = {"2020–2026", "2010–2019", "2000–2009", "before-2000", "undated"}
  local h = {
    '<div class="software-archive-generated">',
    '<h2>' .. esc(tr("technology_archive", "Technology Archive")) .. '</h2>',
    '<p><em>' .. #items .. ' ' ..
      esc(tr("historical_technological_artifacts",
        "historical technological artifacts")) .. '</em></p>'
  }

  for _, key in ipairs(order) do
    local g = groups[key]
    if #g > 0 then
      table.insert(h, '<details class="artifact-period">')
      table.insert(h, '<summary><strong>' .. esc(period_label(key)) ..
        '</strong> <span>(' .. #g .. ')</span></summary>')
      table.insert(h, '<div class="archive-artifacts">')
      for _, item in ipairs(g) do
        table.insert(h, card_html(item, reg.artifact_types, "archive-artifact"))
      end
      table.insert(h, '</div></details>')
    end
  end

  table.insert(h, '</div>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

local function render_unresolved(reg)
  local items = reg.unresolved_project_artifacts or {}
  if #items == 0 then return pandoc.Null() end

  local h = {
    '<div class="artifact-unresolved">',
    '<h2>' .. esc(tr("artifacts_under_identification",
      "Artifacts Under Identification")) .. '</h2>',
    '<p>' .. esc(tr("artifacts_under_identification_explanation",
      "These active research areas are expected to produce software, datasets, prototypes, or other research artifacts, but no distinct canonical technological object has yet been identified.")) .. '</p>',
    '<ul>'
  }

  for _, item in ipairs(items) do
    table.insert(h, '<li><code>' .. esc(val(item.project)) .. '</code></li>')
  end

  table.insert(h, '</ul></div>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

local function process_doc(doc)
  local reg = project.yaml_meta("data/software.yml")
  local out = {}

  for _, block in ipairs(doc.blocks) do
    if block.t == "Div" and block.classes:includes("software-current-generated") then
      table.insert(out, render_current(reg))
    elseif block.t == "Div" and block.classes:includes("software-families-generated") then
      table.insert(out, render_families(reg))
    elseif block.t == "Div" and block.classes:includes("software-archive-generated") then
      table.insert(out, render_archive(reg))
    elseif block.t == "Div" and block.classes:includes("software-unresolved-generated") then
      table.insert(out, render_unresolved(reg))
    else
      table.insert(out, block)
    end
  end

  doc.blocks = out
  return doc
end

return {
  {
    Meta = function(meta)
      configure_i18n(meta)
      return nil
    end
  },
  {
    Pandoc = process_doc
  }
}
