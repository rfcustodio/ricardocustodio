-- filters/software.lua
-- Generates the Software & Data page from data/software.yml.
-- Compatible with Quarto/Pandoc Lua filters.

local stringify = pandoc.utils.stringify

local function read_yaml(path)
  local f = io.open(path, "r")
  if not f then
    error("Could not open " .. path)
  end
  local body = f:read("*all")
  f:close()

  -- Pandoc can parse YAML metadata reliably when wrapped as document front matter.
  local doc = pandoc.read("---\nregistry:\n" ..
    body:gsub("\n", "\n  ") ..
    "\n---\n", "markdown")
  return doc.meta.registry
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

local function map_by_id(items)
  local m = {}
  if items then
    for _, item in ipairs(items) do
      if item.id then m[val(item.id)] = item end
    end
  end
  return m
end

local function esc(s)
  s = s or ""
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  s = s:gsub('"', "&quot;")
  return s
end

local function title_of(item)
  return val(item.public_title) or val(item.title) or "Untitled"
end

local function type_label(item, type_defs)
  local t = val(item.type) or "artifact"
  local def = type_defs and type_defs[t]
  return (def and val(def.label)) or t:gsub("-", " "):gsub("^%l", string.upper)
end

local function chips(values)
  if not values or #values == 0 then return "" end
  local out = {}
  for _, x in ipairs(values) do
    table.insert(out, '<span class="artifact-chip">' .. esc(x:gsub("-", " ")) .. '</span>')
  end
  return '<div class="artifact-chips">' .. table.concat(out, "") .. '</div>'
end

local function links_html(item)
  if not item.links then return "" end
  local out = {}
  for _, link in ipairs(item.links) do
    local label = val(link.label) or "Link"
    local url = val(link.url)
    if url then
      table.insert(out, '<a class="artifact-link" href="' .. esc(url) .. '">' .. esc(label) .. '</a>')
    end
  end
  if #out == 0 then return "" end
  return '<div class="artifact-links">' .. table.concat(out, " · ") .. '</div>'
end

local function card_html(item, type_defs, extra_class)
  local t = type_label(item, type_defs)
  local summary = val(item.summary) or ""
  local subtitle = val(item.subtitle)
  local year = val(item.year)
  local meta = {t}
  if year then table.insert(meta, year) end

  local h = {}
  table.insert(h, '<article class="artifact-card ' .. (extra_class or "") .. '">')
  table.insert(h, '<div class="artifact-meta">' .. esc(table.concat(meta, " · ")) .. '</div>')
  table.insert(h, '<h3>' .. esc(title_of(item)) .. '</h3>')
  if subtitle then table.insert(h, '<div class="artifact-subtitle">' .. esc(subtitle) .. '</div>') end
  if summary ~= "" then table.insert(h, '<p>' .. esc(summary) .. '</p>') end
  table.insert(h, chips(seq(item.topics)))
  table.insert(h, links_html(item))
  table.insert(h, '</article>')
  return table.concat(h, "\n")
end

local function family_block(family, members, type_defs)
  local h = {}
  table.insert(h, '<section class="artifact-family">')
  table.insert(h, '<h3>' .. esc(val(family.title) or val(family.id)) .. '</h3>')
  if family.summary then table.insert(h, '<p class="family-summary">' .. esc(val(family.summary)) .. '</p>') end
  table.insert(h, '<div class="artifact-grid">')
  for _, item in ipairs(members) do
    table.insert(h, card_html(item, type_defs, "family-member"))
  end
  table.insert(h, '</div></section>')
  return table.concat(h, "\n")
end

local function period(year)
  local y = tonumber(year or "")
  if not y then return "Undated" end
  if y >= 2020 then return "2020–2026" end
  if y >= 2010 then return "2010–2019" end
  if y >= 2000 then return "2000–2009" end
  return "Before 2000"
end

local function sort_newest(a, b)
  local ya, yb = tonumber(val(a.year) or "0"), tonumber(val(b.year) or "0")
  if ya ~= yb then return ya > yb end
  return title_of(a) < title_of(b)
end

local function render_current(reg)
  local items = reg.current_artifacts or {}
  table.sort(items, function(a,b) return title_of(a) < title_of(b) end)

  local h = {'<div class="software-generated">',
             '<h2>Current Technological Artifacts (' .. #items .. ')</h2>',
             '<div class="artifact-grid">'}
  for _, item in ipairs(items) do
    table.insert(h, card_html(item, reg.artifact_types, "current-artifact"))
  end
  table.insert(h, '</div></div>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

local function render_families(reg)
  local all = {}
  for _, section in ipairs({"current_artifacts", "software", "technological_products", "research_artifacts"}) do
    if reg[section] then
      for _, item in ipairs(reg[section]) do table.insert(all, item) end
    end
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
    local fid = val(fam.id)
    local members = by_family[fid] or {}
    if #members > 0 then
      table.sort(members, sort_newest)
      table.insert(blocks, family_block(fam, members, reg.artifact_types))
    end
  end

  local h = {'<div class="software-families-generated">',
             '<h2>Technology Families</h2>',
             table.concat(blocks, "\n"),
             '</div>'}
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

local function render_archive(reg)
  local items = {}
  for _, section in ipairs({"software", "technological_products", "research_artifacts"}) do
    if reg[section] then
      for _, item in ipairs(reg[section]) do
        if val(item.status) == "historical" then table.insert(items, item) end
      end
    end
  end
  table.sort(items, sort_newest)

  local groups = {
    ["2020–2026"] = {}, ["2010–2019"] = {}, ["2000–2009"] = {},
    ["Before 2000"] = {}, ["Undated"] = {}
  }
  for _, item in ipairs(items) do
    table.insert(groups[period(val(item.year))], item)
  end

  local order = {"2020–2026", "2010–2019", "2000–2009", "Before 2000", "Undated"}
  local h = {'<div class="software-archive-generated">',
             '<h2>Technology Archive</h2>',
             '<p><em>' .. #items .. ' historical technological artifacts</em></p>'}

  for _, label in ipairs(order) do
    local g = groups[label]
    if #g > 0 then
      table.insert(h, '<details class="artifact-period">')
      table.insert(h, '<summary><strong>' .. esc(label) .. '</strong> <span>(' .. #g .. ')</span></summary>')
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
  local h = {'<div class="artifact-unresolved">',
             '<h2>Artifacts Under Identification</h2>',
             '<p>These active research areas are expected to produce software, datasets, prototypes, or other research artifacts, but no distinct canonical technological object has yet been identified.</p>',
             '<ul>'}
  for _, item in ipairs(items) do
    table.insert(h, '<li><code>' .. esc(val(item.project)) .. '</code></li>')
  end
  table.insert(h, '</ul></div>')
  return pandoc.RawBlock("html", table.concat(h, "\n"))
end

function Pandoc(doc)
  local reg = read_yaml("data/software.yml")
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
