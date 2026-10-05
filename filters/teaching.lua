local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&","&amp;")
  s = s:gsub("<","&lt;")
  s = s:gsub(">","&gt;")
  s = s:gsub('"',"&quot;")
  return s
end

-- Parse YAML using Pandoc itself. This works with Quarto's bundled Pandoc
-- and does not depend on pandoc.utils.from_yaml.
local function load_data()
  local f = io.open("data/teaching.yml","r")
  if not f then return nil end
  local txt = f:read("*all")
  f:close()

  local doc = pandoc.read("---\n" .. txt .. "\n---\n", "markdown")
  return doc.meta
end

local function str(v)
  if v == nil then return "" end
  return pandoc.utils.stringify(v)
end

local function bool(v)
  return v == true or str(v) == "true"
end

local function offering_map(data)
  local m = {}
  for _,o in ipairs(data.offerings or {}) do
    local cid = str(o.course_id)
    m[cid] = m[cid] or {}
    table.insert(m[cid], o)
  end
  return m
end

local function cards(data)
  local om = offering_map(data)
  local html = {'<div class="teaching-grid">'}
  for _,c in ipairs(data.courses or {}) do
    if bool(c.featured) then
      table.insert(html,'<article class="teaching-card">')
      local code = c.code and ('<span class="teaching-code">'..esc(str(c.code))..'</span>') or ''
      table.insert(html,'<div class="teaching-card-head">'..code..'<span class="teaching-level">'..esc(str(c.level))..'</span></div>')
      table.insert(html,'<h3>'..esc(str(c.public_title or c.title))..'</h3>')
      if c.official_title and c.public_title then
        table.insert(html,'<p class="teaching-official">'..esc(str(c.official_title))..'</p>')
      end
      table.insert(html,'<p>'..esc(str(c.summary))..'</p>')
      local offs = om[str(c.id)] or {}
      if #offs > 0 then
        local terms={}
        for _,o in ipairs(offs) do table.insert(terms, esc(str(o.term))) end
        table.insert(html,'<p class="teaching-meta"><strong>Documented offerings:</strong> '..table.concat(terms,", ")..'</p>')
      end
      if c.topics and #c.topics>0 then
        table.insert(html,'<div class="teaching-tags">')
        for _,t in ipairs(c.topics) do table.insert(html,'<span>'..esc(str(t))..'</span>') end
        table.insert(html,'</div>')
      end
      table.insert(html,'</article>')
    end
  end
  table.insert(html,'</div>')
  return table.concat(html,"\n")
end

local function resources(data)
  local groups = {
    ["course-program"]="Course programs",
    ["teaching-plan"]="Teaching plans",
    ["assessment"]="Assessments",
    ["exam"]="Exams"
  }
  local order={"course-program","teaching-plan","assessment","exam"}
  local by={}
  for _,m in ipairs(data.materials or {}) do
    local typ=str(m.type)
    by[typ]=by[typ] or {}
    table.insert(by[typ],m)
  end
  local html={}
  for _,typ in ipairs(order) do
    if by[typ] then
      table.insert(html,'<div class="teaching-resource-group"><h3>'..groups[typ]..'</h3><ul>')
      for _,m in ipairs(by[typ]) do
        local visibility=str(m.visibility_candidate)
        local badge = visibility=="public" and "public candidate" or "review before publication"
        local label = str(m.topic)
        if label=="" then label=str(m.date_or_term) end
        if label=="" then label=str(m.date) end
        if label=="" then label=str(m.id) end
        table.insert(html,'<li><strong>'..esc(label)..'</strong> <span class="teaching-status">'..esc(badge)..'</span></li>')
      end
      table.insert(html,'</ul></div>')
    end
  end
  return table.concat(html,"\n")
end

local function history(data)
  local html={'<div class="teaching-history-list">'}
  for _,h in ipairs(data.historical_courses_from_lattes or {}) do
    table.insert(html,'<div class="teaching-history-item">'..esc(str(h))..'</div>')
  end
  table.insert(html,'</div>')
  return table.concat(html,"\n")
end

function Div(el)
  local data = load_data()
  if not data then return el end
  if el.identifier=="teaching-current" then
    return pandoc.RawBlock("html",cards(data))
  end
  if el.identifier=="teaching-resources" then
    return pandoc.RawBlock("html",resources(data))
  end
  if el.identifier=="teaching-history" then
    return pandoc.RawBlock("html",history(data))
  end
  return el
end
