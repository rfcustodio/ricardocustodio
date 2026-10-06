-- filters/projects.lua — Projects V1.3
-- Multilingual presentation over the single canonical project registry.

local stringify = pandoc.utils.stringify
local project = require("lib.project")
local i18n = require("lib.i18n")

-- Internationalization state is initialized from the effective
-- document metadata before block transformations are executed.
local I = nil
local L = {}
local project_topics = {}

local function configure_i18n(meta)
  local lang = i18n.meta_language(meta)

  I = i18n.load(lang)
  L = I.labels or {}
  project_topics = I.project_topic_labels or {}
end

local function tr(key, fallback)
  return i18n.tr(L, key, fallback)
end

local function text(v)
  if v == nil then return "" end
  return stringify(v)
end

local function title(p)
  local t = text(p.public_title)
  if t ~= "" then return t end
  return text(p.title)
end

local function summary(p)
  local s = text(p.public_summary)
  if s ~= "" then return s end
  return text(p.summary)
end

local function topics(p)
  if not p.topics or #p.topics == 0 then return nil end

  local x = pandoc.Inlines({})

  for i,v in ipairs(p.topics) do
    if i > 1 then
      x:insert(pandoc.Space())
      x:insert(pandoc.Str("·"))
      x:insert(pandoc.Space())
    end

    local id = text(v)
    local label = i18n.tr(project_topics, id, id)

    x:insert(
      pandoc.Span(
        pandoc.Inlines(label),
        pandoc.Attr("", {"project-topic"})
      )
    )
  end

  return pandoc.Para(x)
end

local function website(p)
  if p.links then
    for _,l in ipairs(p.links) do
      if text(l.type) == "website" and text(l.url) ~= "" then
        return text(l.url)
      end
    end
  end
end

local function sort_title(xs)
  table.sort(xs, function(a,b)
    return title(a):lower() < title(b):lower()
  end)
end

local function card(p, cls, level)
  local b = {
    pandoc.Header(level or 3, pandoc.Inlines(title(p)))
  }

  local st = text(p.subtitle)
  if st ~= "" then
    table.insert(
      b,
      pandoc.Para({
        pandoc.Emph(pandoc.Inlines(st))
      })
    )
  end

  local s = summary(p)
  if s ~= "" then
    table.insert(b, pandoc.Para(pandoc.Inlines(s)))
  end

  local tb = topics(p)
  if tb then
    table.insert(b, tb)
  end

  local u = website(p)
  if u then
    table.insert(
      b,
      pandoc.Para({
        pandoc.Link(
          pandoc.Inlines(tr("project_website", "Project website")),
          u
        )
      })
    )
  end

  return pandoc.Div(b, pandoc.Attr("", {cls}))
end

local function current_sets(ps)
  local programs, roots, children = {}, {}, {}

  for _,p in ipairs(ps) do
    if text(p.status) == "current" then
      local par = text(p.parent)

      if par ~= "" then
        children[par] = children[par] or {}
        table.insert(children[par], p)
      elseif text(p.scope) == "research-program" then
        table.insert(programs, p)
      else
        table.insert(roots, p)
      end
    end
  end

  sort_title(programs)
  sort_title(roots)

  for _,x in pairs(children) do
    sort_title(x)
  end

  return programs, roots, children
end

local function parent_card(p, children)
  local base = card(p, "project-parent-content", 3)
  local b = {}

  for _,x in ipairs(base.content) do
    table.insert(b, x)
  end

  local xs = children[text(p.id)]

  if xs and #xs > 0 then
    table.insert(
      b,
      pandoc.Header(
        4,
        pandoc.Inlines(
          tr("related_initiatives", "Related initiatives")
        )
      )
    )

    local cb = {}

    for _,c in ipairs(xs) do
      table.insert(
        cb,
        card(c, "project-child-card", 4)
      )
    end

    table.insert(
      b,
      pandoc.Div(
        cb,
        pandoc.Attr("", {"project-children-grid"})
      )
    )
  end

  return pandoc.Div(
    b,
    pandoc.Attr(
      "",
      {"project-card", "project-parent-card"}
    )
  )
end

local function yn(v)
  return tonumber(text(v))
end

local function pkey(p)
  local y = yn(p.start)

  if not y then
    return "undated"
  elseif y >= 2020 then
    return "2020-2026"
  elseif y >= 2010 then
    return "2010-2019"
  elseif y >= 2000 then
    return "2000-2009"
  else
    return "before-2000"
  end
end

local order = {
  "2020-2026",
  "2010-2019",
  "2000-2009",
  "before-2000",
  "undated"
}

local function period_label(k)
  if k == "before-2000" then
    return tr("before_2000", "Before 2000")
  elseif k == "undated" then
    return tr("undated", "Undated")
  end

  return k:gsub("-", "–")
end

local nature_keys = {
  ["research"] = "nature_research",
  ["technological-development"] =
    "nature_technological_development",
  ["extension"] = "nature_extension"
}

local function nature_label(nature)
  local key = nature_keys[nature]

  if not key then
    return nature
  end

  return tr(key, nature)
end

local function archives(ps)
  local g = {}
  local n = 0

  for _,p in ipairs(ps) do
    if text(p.status) == "completed" then
      n = n + 1
      local k = pkey(p)

      g[k] = g[k] or {}
      table.insert(g[k], p)
    end
  end

  for _,xs in pairs(g) do
    table.sort(xs, function(a,b)
      local ay = yn(a.start) or 0
      local by = yn(b.start) or 0

      if ay ~= by then
        return ay > by
      end

      return title(a):lower() < title(b):lower()
    end)
  end

  return g, n
end

local function archive_item(p)
  local b = {}

  local a = text(p.start)
  local e = text(p["end"])
  local yrs = a

  if e ~= "" then
    yrs = a .. "–" .. e
  elseif a ~= "" then
    yrs = a .. "–?"
  end

  local h = title(p)

  if yrs ~= "" then
    h = h .. " · " .. yrs
  end

  table.insert(
    b,
    pandoc.Header(4, pandoc.Inlines(h))
  )

  local nature = text(p.nature)

  if nature ~= "" then
    table.insert(
      b,
      pandoc.Para({
        pandoc.Strong(
          pandoc.Inlines(nature_label(nature))
        )
      })
    )
  end

  local s = summary(p)

  if s ~= "" then
    table.insert(
      b,
      pandoc.Para(pandoc.Inlines(s))
    )
  end

  local legacy = text(p.legacy_note)

  if legacy ~= "" then
    table.insert(
      b,
      pandoc.Para({
        pandoc.Emph(
          pandoc.Inlines(
            tr("legacy", "Legacy") ..
            ": " ..
            legacy
          )
        )
      })
    )
  end

  return pandoc.Div(
    b,
    pandoc.Attr("", {"archive-project"})
  )
end

local function current(meta)
  local programs, roots, children =
    current_sets(meta.projects)

  local b = {}

  table.insert(
    b,
    pandoc.Header(
      2,
      pandoc.Inlines(
        tr(
          "current_research_programs",
          "Current Research Programs"
        ) ..
        " (" ..
        #programs ..
        ")"
      )
    )
  )

  local pg = {}

  for _,p in ipairs(programs) do
    table.insert(
      pg,
      card(
        p,
        "research-program-card",
        3
      )
    )
  end

  table.insert(
    b,
    pandoc.Div(
      pg,
      pandoc.Attr(
        "",
        {"research-programs-grid"}
      )
    )
  )

  table.insert(
    b,
    pandoc.Header(
      2,
      pandoc.Inlines(
        tr(
          "current_projects",
          "Current Projects"
        ) ..
        " (" ..
        #roots ..
        ")"
      )
    )
  )

  local cg = {}

  for _,p in ipairs(roots) do
    table.insert(
      cg,
      parent_card(p, children)
    )
  end

  table.insert(
    b,
    pandoc.Div(
      cg,
      pandoc.Attr("", {"projects-grid"})
    )
  )

  return pandoc.Div(
    b,
    pandoc.Attr(
      "",
      {"projects-generated"}
    )
  )
end

local function archive(meta)
  local g, n = archives(meta.projects)
  local b = {}

  table.insert(
    b,
    pandoc.Header(
      2,
      pandoc.Inlines(
        tr(
          "project_archive",
          "Project Archive"
        )
      )
    )
  )

  table.insert(
    b,
    pandoc.Para({
      pandoc.Emph(
        pandoc.Inlines(
          tostring(n) ..
          " " ..
          tr(
            "historical_projects",
            "historical projects"
          )
        )
      )
    })
  )

  table.insert(
    b,
    pandoc.Para(
      pandoc.Inlines(
        tr(
          "project_archive_explanation",
          "Historical projects are grouped by starting year. An unknown closing year is shown as “?”."
        )
      )
    )
  )

  for _,k in ipairs(order) do
    local xs = g[k]

    if xs and #xs > 0 then
      table.insert(
        b,
        pandoc.RawBlock(
          "html",
          '<details class="project-period"><summary>' ..
          period_label(k) ..
          ' (' ..
          #xs ..
          ')</summary>'
        )
      )

      for _,p in ipairs(xs) do
        table.insert(
          b,
          archive_item(p)
        )
      end

      table.insert(
        b,
        pandoc.RawBlock(
          "html",
          "</details>"
        )
      )
    end
  end

  return pandoc.Div(
    b,
    pandoc.Attr(
      "",
      {"project-archive-generated"}
    )
  )
end

local function process_div(div)
  if not div.classes:includes(
      "projects-current-generated"
    )
    and not div.classes:includes(
      "projects-archive-generated"
    ) then
    return nil
  end

  local m =
    project.yaml_meta(
      "data/projects.yml"
    )

  if not m or not m.projects then
    return pandoc.Div({
      pandoc.Para({
        pandoc.Strong(
          pandoc.Inlines(
            tr(
              "unable_load_project_data",
              "Unable to load project data."
            )
          )
        )
      })
    })
  end

  if div.classes:includes(
      "projects-current-generated"
    ) then
    return current(m)
  end

  return archive(m)
end

-- Explicit two-pass filter.
-- Pass 1 reads the effective Quarto/Pandoc metadata (`lang`).
-- Pass 2 renders generated project sections using the selected vocabulary.
return {
  {
    Meta = function(meta)
      configure_i18n(meta)
      return nil
    end
  },
  {
    Div = process_div
  }
}

