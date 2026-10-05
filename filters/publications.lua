
-- publications.lua — Publications V4.1
-- Canonical-work rendering, research-area navigation, bibliographic manifestations,
-- and visual refinements. Uses Quarto/Pandoc only.

local stringify = pandoc.utils.stringify

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s=f:read("*all"); f:close(); return s
end

local function yaml_meta(path)
  local s=assert(read_file(path),"Cannot read "..path)
  return pandoc.read("---\n"..s.."\n---\n","markdown").meta
end

local function parse_bib(path)
  local s=assert(read_file(path),"Cannot read "..path)
  local result={}; local pos=1
  while true do
    local a,b,typ=s:find("@([%w]+)%s*%{",pos)
    if not a then break end
    local depth=1; local j=b+1
    while j<=#s and depth>0 do
      local c=s:sub(j,j)
      if c=="{" then depth=depth+1 elseif c=="}" then depth=depth-1 end
      j=j+1
    end
    local body=s:sub(b+1,j-2); local comma=body:find(",")
    if comma then
      local key=body:sub(1,comma-1):gsub("^%s+",""):gsub("%s+$","")
      local fields={type=typ:lower(),key=key}; local rest=body:sub(comma+1); local p=1
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

local function ms(x) if x==nil then return "" end return stringify(x) end
local function list(x)
  local r={}; if x then for _,v in ipairs(x) do table.insert(r,stringify(v)) end end; return r
end
local function clean(s)
  if not s then return "" end
  return s:gsub("[{}]",""):gsub("\\&","&"):gsub("\\textendash","–"):gsub("%s+"," ")
end
local function esc(s)
  s=clean(s); return s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
end
local function slug(s)
  s=s:lower():gsub("[^%w%-]+","-"):gsub("%-+","-"):gsub("^%-",""):gsub("%-$","")
  return s
end

local function topic_info(meta)
  local labels,groups={},{}
  local topics=meta.taxonomy and meta.taxonomy.topics or {}
  for k,v in pairs(topics) do
    labels[stringify(k)]=ms(v.label)
    groups[stringify(k)]=ms(v.group)
  end
  return labels,groups
end

local function manifestation_label(e,key,preferred)
  local typ=(e.type or ""):lower()
  local venue=(e.journal or e.booktitle or ""):lower()
  local label
  if venue:find("iacr") or key:find("journals/iacr",1,true) then label="IACR ePrint"
  elseif key:find("journals/corr",1,true) or venue:find("corr") then label="arXiv / CoRR"
  elseif typ=="article" then label="Journal article"
  elseif typ=="inproceedings" or typ=="conference" then label="Conference paper"
  elseif typ=="incollection" then label="Book chapter"
  elseif typ=="book" then label="Book"
  elseif typ=="phdthesis" then label="PhD thesis"
  elseif typ=="mastersthesis" then label="Master's thesis"
  else label="Bibliographic record" end
  if key==preferred then label=label.." · preferred" end
  return label
end

local function manifestation_links(w,bib)
  local keys=list(w.versions)
  if #keys==0 then keys={ms(w.preferred_bibtex)} end
  local preferred=ms(w.preferred_bibtex); local items={}
  for _,key in ipairs(keys) do
    local e=bib[key] or {}
    local label=manifestation_label(e,key,preferred)
    local target=""
    if e.doi and e.doi~="" then target="https://doi.org/"..clean(e.doi)
    elseif e.url and e.url~="" then target=clean(e.url) end
    if target~="" then
      table.insert(items,'<a class="pub-version" href="'..esc(target)..'">'..esc(label)..'</a>')
    else
      table.insert(items,'<span class="pub-version">'..esc(label)..'</span>')
    end
  end
  return table.concat(items," ")
end

local function work_card(w,bib,labels,selected,compact)
  local key=ms(w.preferred_bibtex); local e=bib[key] or {}
  local title=esc(e.title or ms(w.id))
  local author=esc((e.author or ""):gsub("%s+and%s+",", "))
  local year=esc(e.year or "")
  local venue=esc(e.journal or e.booktitle or e.publisher or "")
  local chips={}
  for _,t in ipairs(list(w.topics)) do
    table.insert(chips,'<a class="pub-topic" href="#area-'..slug(t)..'">'..esc(labels[t] or t)..'</a>')
  end
  local reason=""
  if selected and w.selected and w.selected.reason then
    reason='<div class="pub-reason">'..esc(ms(w.selected.reason))..'</div>'
  end
  local versions=manifestation_links(w,bib)
  local cls=compact and "pub-card pub-card-compact" or "pub-card"
  return pandoc.RawBlock("html",
    '<article class="'..cls..'">'
    ..'<div class="pub-title">'..title..'</div>'
    ..'<div class="pub-authors">'..author..'</div>'
    ..'<div class="pub-venue">'..venue..(venue~="" and year~="" and ", " or "")..year..'</div>'
    ..reason
    ..'<div class="pub-topics">'..table.concat(chips," ")..'</div>'
    ..'<div class="pub-versions">'..versions..'</div>'
    ..'</article>')
end

local function works(meta)
  local r={}; for _,w in ipairs(meta.works or {}) do table.insert(r,w) end; return r
end

function Div(el)
  if el.identifier~="publications-generated" then return nil end
  local meta=yaml_meta("data/publications.yml")
  local bib=parse_bib("bibliography/publications.bib")
  local labels,groups=topic_info(meta)
  local ws=works(meta); local blocks={}

  table.insert(blocks,pandoc.Header(2,"Selected Publications"))
  table.insert(blocks,pandoc.Para{pandoc.Str("A curated selection of publications that mark significant stages in my research trajectory.")})
  local selected={}
  for _,w in ipairs(ws) do
    if w.selected and ms(w.selected.featured)=="true" then table.insert(selected,w) end
  end
  table.sort(selected,function(a,b) return tonumber(ms(a.selected.order))<tonumber(ms(b.selected.order)) end)
  for _,w in ipairs(selected) do table.insert(blocks,work_card(w,bib,labels,true,false)) end

  -- Area navigator
  table.insert(blocks,pandoc.Header(2,"Browse by Research Area"))
  local bytopic={}
  for _,w in ipairs(ws) do
    for _,t in ipairs(list(w.topics)) do
      bytopic[t]=bytopic[t] or {}; table.insert(bytopic[t],w)
    end
  end
  local tids={}
  for t,_ in pairs(bytopic) do table.insert(tids,t) end
  table.sort(tids,function(a,b)
    local ga,gb=groups[a] or "",groups[b] or ""
    if ga~=gb then return ga<gb end
    return (labels[a] or a)<(labels[b] or b)
  end)
  local nav={}
  for _,t in ipairs(tids) do
    table.insert(nav,'<a class="topic-summary" href="#area-'..slug(t)..'">'
      ..esc(labels[t] or t)..' <strong>'..#bytopic[t]..'</strong></a>')
  end
  table.insert(blocks,pandoc.RawBlock("html",'<nav class="topic-summary-grid">'..table.concat(nav," ")..'</nav>'))

  -- Actual area sections: compact canonical-work listings.
  local lastgroup=nil
  for _,t in ipairs(tids) do
    local group=groups[t] or "Research Areas"
    if group~=lastgroup then
      table.insert(blocks,pandoc.Header(3,group))
      lastgroup=group
    end
    local h=pandoc.Header(4,(labels[t] or t).." ("..#bytopic[t]..")")
    h.identifier="area-"..slug(t); table.insert(blocks,h)
    table.sort(bytopic[t],function(a,b)
      local ea=bib[ms(a.preferred_bibtex)] or {}; local eb=bib[ms(b.preferred_bibtex)] or {}
      local ya=tonumber(ea.year or "0") or 0; local yb=tonumber(eb.year or "0") or 0
      if ya~=yb then return ya>yb end
      return clean(ea.title or "")<clean(eb.title or "")
    end)
    for _,w in ipairs(bytopic[t]) do table.insert(blocks,work_card(w,bib,labels,false,true)) end
  end

  -- Chronological master list.
  table.insert(blocks,pandoc.Header(2,"All Publications"))
  table.insert(blocks,pandoc.Para{pandoc.Str("Each canonical scholarly work is listed once. Preprints, ePrints, and other manifestations are shown as versions of the same work.")})
  table.sort(ws,function(a,b)
    local ea=bib[ms(a.preferred_bibtex)] or {}; local eb=bib[ms(b.preferred_bibtex)] or {}
    local ya=tonumber(ea.year or "0") or 0; local yb=tonumber(eb.year or "0") or 0
    if ya~=yb then return ya>yb end
    return clean(ea.title or "")<clean(eb.title or "")
  end)
  local last=nil
  for _,w in ipairs(ws) do
    local e=bib[ms(w.preferred_bibtex)] or {}; local y=clean(e.year or "Undated")
    if y~=last then table.insert(blocks,pandoc.Header(3,y)); last=y end
    table.insert(blocks,work_card(w,bib,labels,false,false))
  end
  return blocks
end
