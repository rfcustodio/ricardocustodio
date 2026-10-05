-- publications.lua — Publications V4.4
-- Canonical-work rendering, multilingual research taxonomy,
-- bibliographic manifestations, and visual refinements.
-- Uses shared project/i18n libraries and Quarto/Pandoc only.

local stringify = pandoc.utils.stringify
local project = require("lib.project")
local i18n = require("lib.i18n")

-- ---------------------------------------------------------------------------
-- BibTeX parser
-- ---------------------------------------------------------------------------

local function parse_bib(path)
  local s = project.read_file(path)
  local result = {}
  local pos = 1

  while true do
    local a, b, typ = s:find("@([%w]+)%s*%{", pos)
    if not a then break end

    local depth = 1
    local j = b + 1

    while j <= #s and depth > 0 do
      local c = s:sub(j, j)
      if c == "{" then
        depth = depth + 1
      elseif c == "}" then
        depth = depth - 1
      end
      j = j + 1
    end

    local body = s:sub(b + 1, j - 2)
    local comma = body:find(",")

    if comma then
      local key = body:sub(1, comma - 1)
        :gsub("^%s+", "")
        :gsub("%s+$", "")

      local fields = {
        type = typ:lower(),
        key = key
      }

      local rest = body:sub(comma + 1)
      local p = 1

      while true do
        local x, y, name = rest:find("([%w%-]+)%s*=%s*", p)
        if not x then break end

        local q = y + 1
        local value = ""

        if rest:sub(q, q) == "{" then
          local d = 1
          local k = q + 1

          while k <= #rest and d > 0 do
            local c = rest:sub(k, k)
            if c == "{" then
              d = d + 1
            elseif c == "}" then
              d = d - 1
            end
            k = k + 1
          end

          value = rest:sub(q + 1, k - 2)
          p = k

        elseif rest:sub(q, q) == '"' then
          local k = q + 1
          while k <= #rest and rest:sub(k, k) ~= '"' do
            k = k + 1
          end
          value = rest:sub(q + 1, k - 1)
          p = k + 1

        else
          local k = rest:find(",", q) or (#rest + 1)
          value = rest:sub(q, k - 1)
          p = k + 1
        end

        fields[name:lower()] = value:gsub("%s+", " ")
      end

      result[key] = fields
    end

    pos = j
  end

  return result
end

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

local function ms(x)
  if x == nil then return "" end
  return stringify(x)
end

local function list(x)
  local r = {}
  if x then
    for _, v in ipairs(x) do
      table.insert(r, stringify(v))
    end
  end
  return r
end

local function clean(s)
  if not s then return "" end
  return s
    :gsub("[{}]", "")
    :gsub("\\&", "&")
    :gsub("\\textendash", "–")
    :gsub("%s+", " ")
end

local function esc(s)
  s = clean(s)
  return s
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
end

local function slug(s)
  return s
    :lower()
    :gsub("[^%w%-]+", "-")
    :gsub("%-+", "-")
    :gsub("^%-", "")
    :gsub("%-$", "")
end

-- ---------------------------------------------------------------------------
-- Research taxonomy
-- ---------------------------------------------------------------------------

local function topic_info(meta, I)
  local labels = {}
  local groups = {}
  local group_ids = {}
  local topics = meta.taxonomy and meta.taxonomy.topics or {}

  -- Stable mapping from canonical English group names in publications.yml
  -- to language-independent vocabulary keys.
  local canonical_group_ids = {
    ["Research Foundations"] = "research-foundations",
    ["Digital Trust"] = "digital-trust",
    ["Emerging Directions"] = "emerging-directions",
    ["Historical & Cross-Cutting"] = "historical-cross-cutting",
    ["Security & Privacy"] = "security-privacy",
    ["Historical Research"] = "historical-research"
  }

  for k, v in pairs(topics) do
    local topic_id = stringify(k)
    local canonical_label = ms(v.label)
    local canonical_group = ms(v.group)

    labels[topic_id] = i18n.tr(I.topic_labels, topic_id, canonical_label)

    local group_id = canonical_group_ids[canonical_group] or canonical_group
    group_ids[topic_id] = group_id
    groups[topic_id] = i18n.tr(I.group_labels, group_id, canonical_group)
  end

  return labels, groups, group_ids
end

-- ---------------------------------------------------------------------------
-- Bibliographic manifestations
-- ---------------------------------------------------------------------------

local function manifestation_label(e, key, preferred, T)
  local typ = (e.type or ""):lower()
  local venue = (e.journal or e.booktitle or ""):lower()
  local label

  if venue:find("iacr") or key:find("journals/iacr", 1, true) then
    label = "IACR ePrint"
  elseif key:find("journals/corr", 1, true) or venue:find("corr") then
    label = "arXiv / CoRR"
  elseif typ == "article" then
    label = i18n.tr(T, "journal_article", "Journal article")
  elseif typ == "inproceedings" or typ == "conference" then
    label = i18n.tr(T, "conference_paper", "Conference paper")
  elseif typ == "incollection" then
    label = i18n.tr(T, "book_chapter", "Book chapter")
  elseif typ == "book" then
    label = i18n.tr(T, "book", "Book")
  elseif typ == "phdthesis" then
    label = i18n.tr(T, "phd_thesis", "PhD thesis")
  elseif typ == "mastersthesis" then
    label = i18n.tr(T, "masters_thesis", "Master's thesis")
  else
    label = i18n.tr(T, "bibliographic_record", "Bibliographic record")
  end

  if key == preferred then
    label = label .. " · " .. i18n.tr(T, "preferred", "preferred")
  end

  return label
end

local function manifestation_links(w, bib, T)
  local keys = list(w.versions)
  if #keys == 0 then
    keys = { ms(w.preferred_bibtex) }
  end

  local preferred = ms(w.preferred_bibtex)
  local items = {}

  for _, key in ipairs(keys) do
    local e = bib[key] or {}
    local label = manifestation_label(e, key, preferred, T)
    local target = ""

    if e.doi and e.doi ~= "" then
      target = "https://doi.org/" .. clean(e.doi)
    elseif e.url and e.url ~= "" then
      target = clean(e.url)
    end

    if target ~= "" then
      table.insert(
        items,
        '<a class="pub-version" href="' .. esc(target) .. '">'
          .. esc(label) .. '</a>'
      )
    else
      table.insert(
        items,
        '<span class="pub-version">' .. esc(label) .. '</span>'
      )
    end
  end

  return table.concat(items, " ")
end

-- ---------------------------------------------------------------------------
-- Publication cards
-- ---------------------------------------------------------------------------

local function work_card(w, bib, labels, selected, compact, T)
  local key = ms(w.preferred_bibtex)
  local e = bib[key] or {}

  local title = esc(e.title or ms(w.id))
  local author = esc((e.author or ""):gsub("%s+and%s+", ", "))
  local year = esc(e.year or "")
  local venue = esc(e.journal or e.booktitle or e.publisher or "")

  local chips = {}
  for _, t in ipairs(list(w.topics)) do
    table.insert(
      chips,
      '<a class="pub-topic" href="#area-' .. slug(t) .. '">'
        .. esc(labels[t] or t) .. '</a>'
    )
  end

  local reason = ""
  if selected and w.selected and w.selected.reason then
    reason = '<div class="pub-reason">' .. esc(ms(w.selected.reason)) .. '</div>'
  end

  local versions = manifestation_links(w, bib, T)
  local cls = compact and "pub-card pub-card-compact" or "pub-card"

  return pandoc.RawBlock(
    "html",
    '<article class="' .. cls .. '">'
      .. '<div class="pub-title">'
      .. (
        (w.selected and ms(w.selected.featured) == "true")
        and '<a href="/id/work/' .. esc(ms(w.id)) .. '/">' .. title .. '</a>'
        or title
      )
      .. '</div>'
      .. '<div class="pub-authors">' .. author .. '</div>'
      .. '<div class="pub-venue">'
      .. venue
      .. (venue ~= "" and year ~= "" and ", " or "")
      .. year
      .. '</div>'
      .. reason
      .. '<div class="pub-topics">' .. table.concat(chips, " ") .. '</div>'
      .. '<div class="pub-versions">' .. versions .. '</div>'
      .. '</article>'
  )
end

local function works(meta)
  local r = {}
  for _, w in ipairs(meta.works or {}) do
    table.insert(r, w)
  end
  return r
end

-- ---------------------------------------------------------------------------
-- Publications page
-- ---------------------------------------------------------------------------

function Div(el)
  if el.identifier ~= "publications-generated" then
    return nil
  end

  local lang = i18n.document_language()
  local I = i18n.load(lang)
  local T = I.labels

  local meta = project.yaml_meta("data/publications.yml")
  local bib = parse_bib(project.locate("bibliography/publications.bib"))

  local labels, groups, group_ids = topic_info(meta, I)
  local ws = works(meta)
  local blocks = {}

  -- Selected publications
  table.insert(
    blocks,
    pandoc.Header(2, i18n.tr(T, "selected_publications", "Selected Publications"))
  )

  table.insert(
    blocks,
    pandoc.Para{
      pandoc.Str(
        i18n.tr(
          T,
          "selected_publications_intro",
          "A curated selection of publications that mark significant stages in my research trajectory."
        )
      )
    }
  )

  local selected = {}
  for _, w in ipairs(ws) do
    if w.selected and ms(w.selected.featured) == "true" then
      table.insert(selected, w)
    end
  end

  table.sort(
    selected,
    function(a, b)
      return tonumber(ms(a.selected.order)) < tonumber(ms(b.selected.order))
    end
  )

  for _, w in ipairs(selected) do
    table.insert(blocks, work_card(w, bib, labels, true, false, T))
  end

  -- Research-area navigator
  table.insert(
    blocks,
    pandoc.Header(
      2,
      i18n.tr(T, "browse_by_research_area", "Browse by Research Area")
    )
  )

  local bytopic = {}
  for _, w in ipairs(ws) do
    for _, t in ipairs(list(w.topics)) do
      bytopic[t] = bytopic[t] or {}
      table.insert(bytopic[t], w)
    end
  end

  local tids = {}
  for t, _ in pairs(bytopic) do
    table.insert(tids, t)
  end

  -- Sort by stable canonical group identity first, localized topic label second.
  table.sort(
    tids,
    function(a, b)
      local ga = group_ids[a] or ""
      local gb = group_ids[b] or ""
      if ga ~= gb then
        return ga < gb
      end
      return (labels[a] or a) < (labels[b] or b)
    end
  )

  local nav = {}
  for _, t in ipairs(tids) do
    table.insert(
      nav,
      '<a class="topic-summary" href="#area-' .. slug(t) .. '">'
        .. esc(labels[t] or t)
        .. ' <strong>' .. #bytopic[t] .. '</strong></a>'
    )
  end

  table.insert(
    blocks,
    pandoc.RawBlock(
      "html",
      '<nav class="topic-summary-grid">' .. table.concat(nav, " ") .. '</nav>'
    )
  )

  -- Research-area sections
  local lastgroup = nil

  for _, t in ipairs(tids) do
    local group = groups[t]
      or i18n.tr(T, "research_areas", "Research Areas")

    if group ~= lastgroup then
      table.insert(blocks, pandoc.Header(3, group))
      lastgroup = group
    end

    local h = pandoc.Header(
      4,
      (labels[t] or t) .. " (" .. #bytopic[t] .. ")"
    )

    -- Anchor is based on the canonical topic ID, never on its translation.
    h.identifier = "area-" .. slug(t)
    table.insert(blocks, h)

    table.sort(
      bytopic[t],
      function(a, b)
        local ea = bib[ms(a.preferred_bibtex)] or {}
        local eb = bib[ms(b.preferred_bibtex)] or {}
        local ya = tonumber(ea.year or "0") or 0
        local yb = tonumber(eb.year or "0") or 0

        if ya ~= yb then
          return ya > yb
        end

        return clean(ea.title or "") < clean(eb.title or "")
      end
    )

    for _, w in ipairs(bytopic[t]) do
      table.insert(blocks, work_card(w, bib, labels, false, true, T))
    end
  end

  -- Chronological master list
  table.insert(
    blocks,
    pandoc.Header(2, i18n.tr(T, "all_publications", "All Publications"))
  )

  table.insert(
    blocks,
    pandoc.Para{
      pandoc.Str(
        i18n.tr(
          T,
          "canonical_work_note",
          "Each canonical scholarly work is listed once. Preprints, ePrints, and other manifestations are shown as versions of the same work."
        )
      )
    }
  )

  table.sort(
    ws,
    function(a, b)
      local ea = bib[ms(a.preferred_bibtex)] or {}
      local eb = bib[ms(b.preferred_bibtex)] or {}
      local ya = tonumber(ea.year or "0") or 0
      local yb = tonumber(eb.year or "0") or 0

      if ya ~= yb then
        return ya > yb
      end

      return clean(ea.title or "") < clean(eb.title or "")
    end
  )

  local last = nil

  for _, w in ipairs(ws) do
    local e = bib[ms(w.preferred_bibtex)] or {}
    local y = clean(e.year or i18n.tr(T, "undated", "Undated"))

    if y ~= last then
      table.insert(blocks, pandoc.Header(3, y))
      last = y
    end

    table.insert(blocks, work_card(w, bib, labels, false, false, T))
  end

  return blocks
end
