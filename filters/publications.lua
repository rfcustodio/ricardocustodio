
-- publications.lua
-- Generates the Publications page from data/publications.yml and bibliography/publications.bib.
-- Requires Quarto's bundled Pandoc only; no Python dependency.

local stringify = pandoc.utils.stringify

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*all")
  f:close()
  return s
end

local function yaml_meta(path)
  local s = read_file(path)
  if not s then error("Cannot read " .. path) end
  local doc = pandoc.read("---\n" .. s .. "\n---\n", "markdown")
  return doc.meta
end

local function bib_entries(path)
  local s = read_file(path)
  if not s then error("Cannot read " .. path) end
  local doc = pandoc.read(s, "biblatex")
  local entries = {}
  for _,b in ipairs(doc.blocks) do
    if b.t == "Div" and b.identifier ~= "" then entries[b.identifier] = b end
  end
  return entries
end

-- BibTeX is parsed directly for robust access to fields and exact keys.
local function parse_bib(path)
  local s = assert(read_file(path), "Cannot read " .. path)
  local result = {}
  local pos=1
  while true do
    local a,b,typ = s:find("@([%w]+)%s*%{",pos)
    if not a then break end
    local depth=1; local j=b+1
    while j<=#s and depth>0 do
      local c=s:sub(j,j)
      if c=="{" then depth=depth+1 elseif c=="}" then depth=depth-1 end
      j=j+1
    end
    local body=s:sub(b+1,j-2)
    local comma=body:find(",")
    if comma then
      local key=body:sub(1,comma-1):gsub("^%s+",""):gsub("%s+$","")
      local fields={type=typ:lower(), key=key}
      local rest=body:sub(comma+1)
      local p=1
      while true do
        local x,y,name=rest:find("([%w%-]+)%s*=%s*",p)
        if not x then break end
        local q=y+1; local value=""
        if rest:sub(q,q)=="{" then
          local d=1; local k=q+1
          while k<=#rest and d>0 do
            local c=rest:sub(k,k)
            if c=="{" then d=d+1 elseif c=="}" then d=d-1 end
            k=k+1
          end
          value=rest:sub(q+1,k-2); p=k
        elseif rest:sub(q,q)=='"' then
          local k=q+1
          while k<=#rest and rest:sub(k,k)~='"' do k=k+1 end
          value=rest:sub(q+1,k-1); p=k+1
        else
          local k=rest:find(",",q) or (#rest+1)
          value=rest:sub(q,k-1); p=k+1
        end
        fields[name:lower()]=value:gsub("%s+"," ")
      end
      result[key]=fields
    end
    pos=j
  end
  return result
end

local function clean_tex(s)
  if not s then return "" end
  s=s:gsub("[{}]","")
  s=s:gsub("\\&","&")
  s=s:gsub("\\textendash","–")
  return s
end

local function meta_string(x)
  if x == nil then return "" end
  return stringify(x)
end

local function list_values(x)
  local r={}
  if x then for _,v in ipairs(x) do table.insert(r, stringify(v)) end end
  return r
end

local function topic_labels(meta)
  local r={}
  local topics=meta.taxonomy and meta.taxonomy.topics
  if topics then
    for k,v in pairs(topics) do
      r[stringify(k)] = meta_string(v.label)
    end
  end
  return r
end

local function authors(s)
  if not s then return "" end
  local names={}
  for n in s:gmatch("([^;]+)") do table.insert(names,n) end
  if #names==0 then
    for n in s:gmatch("([^%s].-)%s+and%s+") do table.insert(names,n) end
  end
  if #names==0 then
    s=s:gsub("%s+and%s+",", ")
    return clean_tex(s)
  end
  return clean_tex(table.concat(names,", "))
end

local function work_card(w,bib,labels,selected)
  local key=meta_string(w.preferred_bibtex)
  local e=bib[key] or {}
  local title=clean_tex(e.title or meta_string(w.id))
  local author=clean_tex((e.author or ""):gsub("%s+and%s+",", "))
  local year=clean_tex(e.year or "")
  local venue=clean_tex(e.journal or e.booktitle or e.publisher or "")
  local doi=clean_tex(e.doi or "")
  local url=clean_tex(e.url or "")
  local topics=list_values(w.topics)
  local chips={}
  for _,t in ipairs(topics) do
    table.insert(chips, '<span class="pub-topic">' .. (labels[t] or t) .. '</span>')
  end
  local links={}
  if doi~="" then table.insert(links,'<a href="https://doi.org/'..doi..'">DOI</a>') end
  if url~="" then table.insert(links,'<a href="'..url..'">Publication</a>') end
  local versions=list_values(w.versions)
  if #versions>1 then table.insert(links,'<span>'..(#versions)..' versions</span>') end
  local reason=""
  if selected and w.selected and w.selected.reason then
    reason='<div class="pub-reason">'..meta_string(w.selected.reason)..'</div>'
  end
  local html='<article class="pub-card">'
    ..'<div class="pub-title">'..title..'</div>'
    ..'<div class="pub-authors">'..author..'</div>'
    ..'<div class="pub-venue">'..venue..(venue~="" and year~="" and ", " or "")..year..'</div>'
    ..reason
    ..'<div class="pub-topics">'..table.concat(chips," ")..'</div>'
    ..'<div class="pub-links">'..table.concat(links," · ")..'</div>'
    ..'</article>'
  return pandoc.RawBlock("html",html)
end

local function works(meta)
  local r={}
  for _,w in ipairs(meta.works or {}) do table.insert(r,w) end
  return r
end

function Div(el)
  if el.identifier ~= "publications-generated" then return nil end

  local meta=yaml_meta("data/publications.yml")
  local bib=parse_bib("bibliography/publications.bib")
  local labels=topic_labels(meta)
  local ws=works(meta)
  local blocks={}

  -- Selected Publications
  table.insert(blocks,pandoc.Header(2,"Selected Publications"))
  table.insert(blocks,pandoc.Para{pandoc.Str("A curated selection of publications that mark significant stages in my research trajectory.")})
  local selected={}
  for _,w in ipairs(ws) do
    if w.selected and meta_string(w.selected.featured)=="true" then table.insert(selected,w) end
  end
  table.sort(selected,function(a,b)
    return tonumber(meta_string(a.selected.order)) < tonumber(meta_string(b.selected.order))
  end)
  for _,w in ipairs(selected) do table.insert(blocks,work_card(w,bib,labels,true)) end

  -- Browse by Research Area
  table.insert(blocks,pandoc.Header(2,"Browse by Research Area"))
  local counts={}
  for _,w in ipairs(ws) do
    for _,t in ipairs(list_values(w.topics)) do counts[t]=(counts[t] or 0)+1 end
  end
  local topic_ids={}
  for t,_ in pairs(counts) do table.insert(topic_ids,t) end
  table.sort(topic_ids,function(a,b) return (labels[a] or a)<(labels[b] or b) end)
  local chips={}
  for _,t in ipairs(topic_ids) do
    table.insert(chips,'<span class="topic-summary">'..(labels[t] or t)..' <strong>'..counts[t]..'</strong></span>')
  end
  table.insert(blocks,pandoc.RawBlock("html",'<div class="topic-summary-grid">'..table.concat(chips," ")..'</div>'))

  -- All Publications, one canonical work per entry
  table.insert(blocks,pandoc.Header(2,"All Publications"))
  table.insert(blocks,pandoc.Para{pandoc.Str("Canonical works are listed once. Preprints and other manifestations are consolidated under the same scholarly work.")})
  table.sort(ws,function(a,b)
    local ea=bib[meta_string(a.preferred_bibtex)] or {}
    local eb=bib[meta_string(b.preferred_bibtex)] or {}
    local ya=tonumber(ea.year or "0") or 0
    local yb=tonumber(eb.year or "0") or 0
    if ya~=yb then return ya>yb end
    return clean_tex(ea.title or "") < clean_tex(eb.title or "")
  end)
  local last=nil
  for _,w in ipairs(ws) do
    local e=bib[meta_string(w.preferred_bibtex)] or {}
    local y=clean_tex(e.year or "Undated")
    if y~=last then table.insert(blocks,pandoc.Header(3,y)); last=y end
    table.insert(blocks,work_card(w,bib,labels,false))
  end

  return blocks
end
