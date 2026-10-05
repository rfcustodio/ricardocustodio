-- filters/scholarly-registry.lua — Scholarly Registry V1
-- Generates persistent Quarto pages for featured canonical scholarly works.
-- Source of truth: data/publications.yml + bibliography/publications.bib.

local stringify=pandoc.utils.stringify

local function read_file(path)
  local f=assert(io.open(path,"r"),"Cannot read "..path)
  local s=f:read("*all"); f:close(); return s
end
local function write_file(path,s)
  local f=assert(io.open(path,"w"),"Cannot write "..path)
  f:write(s); f:close()
end
local function yaml_meta(path)
  return pandoc.read("---\n"..read_file(path).."\n---\n","markdown").meta
end
local function ms(x) if x==nil then return "" end return stringify(x) end
local function list(x) local r={} if x then for _,v in ipairs(x) do r[#r+1]=stringify(v) end end return r end
local function clean(s)
  if not s then return "" end
  return s:gsub("[{}]",""):gsub("\\&","&"):gsub("\\textendash","–")
          :gsub("\\_","_"):gsub("%s+"," ")
end
local function esc_html(s)
  s=clean(s); return s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
end
local function esc_json(s)
  return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end
local function jq(s) return '"'..esc_json(s)..'"' end
local function slugkey(s) return s:gsub("[^%w%-%.~_]","-"):gsub("%-+","-") end
local function yaml_quote(s) return '"'..tostring(s):gsub("\\","\\\\"):gsub('"','\\"')..'"' end

local function parse_bib(path)
  local s=read_file(path); local result={}; local pos=1
  while true do
    local a,b,typ=s:find("@([%w]+)%s*%{",pos); if not a then break end
    local depth=1; local j=b+1
    while j<=#s and depth>0 do
      local c=s:sub(j,j); if c=="{" then depth=depth+1 elseif c=="}" then depth=depth-1 end; j=j+1
    end
    local body=s:sub(b+1,j-2); local comma=body:find(",")
    if comma then
      local key=body:sub(1,comma-1):gsub("^%s+",""):gsub("%s+$","")
      local fields={type=typ:lower(),key=key}; local rest=body:sub(comma+1); local p=1
      while true do
        local x,y,name=rest:find("([%w%-]+)%s*=%s*",p); if not x then break end
        local q=y+1; local value=""
        if rest:sub(q,q)=="{" then
          local d=1; local k=q+1
          while k<=#rest and d>0 do
            local c=rest:sub(k,k); if c=="{" then d=d+1 elseif c=="}" then d=d-1 end; k=k+1
          end
          value=rest:sub(q+1,k-2); p=k
        elseif rest:sub(q,q)=='"' then
          local k=q+1; while k<=#rest and rest:sub(k,k)~='"' do k=k+1 end
          value=rest:sub(q+1,k-1); p=k+1
        else
          local k=rest:find(",",q) or (#rest+1); value=rest:sub(q,k-1); p=k+1
        end
        fields[name:lower()]=value:gsub("%s+"," ")
      end
      result[key]=fields
    end
    pos=j
  end
  return result
end

local function manifestation_label(e,key,preferred)
  local typ=(e.type or ""):lower(); local venue=(e.journal or e.booktitle or ""):lower()
  local label
  if venue:find("iacr") or key:find("journals/iacr",1,true) then label="IACR ePrint"
  elseif key:find("journals/corr",1,true) or venue:find("corr") then label="arXiv / CoRR"
  elseif typ=="article" then label="Journal article"
  elseif typ=="inproceedings" or typ=="conference" then label="Conference paper"
  elseif typ=="incollection" then label="Book chapter"
  elseif typ=="book" then label="Book"
  else label="Bibliographic record" end
  if key==preferred then label=label.." · preferred" end
  return label
end
local function schema_type(e)
  local t=(e.type or ""):lower()
  if t=="article" or t=="inproceedings" or t=="conference" or t=="incollection" then return "ScholarlyArticle" end
  if t=="book" then return "Book" end
  return "CreativeWork"
end
local function authors(s)
  local r={}; s=clean(s or "")
  for n in (s.." and "):gmatch("(.-)%s+and%s+") do if n~="" then r[#r+1]=n end end
  return r
end
local function author_json(s)
  local r={}
  for _,n in ipairs(authors(s)) do
    local id=""
    if n:lower():find("ricardo") and n:lower():find("cust") then id=',"@id":"https://ricardocustodio.com.br/#person"' end
    r[#r+1]='{"@type":"Person","name":'..jq(n)..id..'}'
  end
  return "["..table.concat(r,",").."]"
end

local function jsonld(w,bib,labels)
  local wid=ms(w.id); local workid="https://ricardocustodio.com.br/id/work/"..wid.."/"
  local preferred=ms(w.preferred_bibtex); local pe=bib[preferred] or {}
  local topics={}; for _,t in ipairs(list(w.topics)) do topics[#topics+1]=jq(labels[t] or t) end
  local examples={}; local nodes={}
  for _,key in ipairs(list(w.versions)) do
    local e=bib[key] or {}; local mid=workid.."#manifestation-"..slugkey(key)
    examples[#examples+1]='{"@id":'..jq(mid)..'}'
    local f={
      '"@type":'..jq(schema_type(e)),
      '"@id":'..jq(mid),
      '"exampleOfWork":{"@id":'..jq(workid)..'}'
    }
    if e.title then f[#f+1]='"name":'..jq(clean(e.title)) end
    if e.author then f[#f+1]='"author":'..author_json(e.author) end
    if e.year then f[#f+1]='"datePublished":'..jq(clean(e.year)) end
    local venue=e.journal or e.booktitle
    if venue then f[#f+1]='"isPartOf":{"@type":"CreativeWork","name":'..jq(clean(venue))..'}' end
    if e.doi and e.doi~="" then
      local d=clean(e.doi)
      f[#f+1]='"identifier":{"@type":"PropertyValue","propertyID":"DOI","value":'..jq(d)..'}'
      f[#f+1]='"sameAs":'..jq("https://doi.org/"..d)
    elseif e.url and e.url~="" then f[#f+1]='"url":'..jq(clean(e.url)) end
    nodes[#nodes+1]="{"..table.concat(f,",").."}"
  end
  local work='{"@type":"CreativeWork","@id":'..jq(workid)..
    ',"name":'..jq(clean(pe.title or wid))..
    ',"creator":{"@id":"https://ricardocustodio.com.br/#person"}'..
    ',"about":['..table.concat(topics,",")..']'..
    ',"workExample":['..table.concat(examples,",")..']}'
  return '<script type="application/ld+json">\n{"@context":"https://schema.org","@graph":['..
    work..","..table.concat(nodes,",")..']}\n</script>'
end

local function page(w,bib,labels)
  local wid=ms(w.id); local preferred=ms(w.preferred_bibtex); local pe=bib[preferred] or {}
  local title=clean(pe.title or wid); local auth=table.concat(authors(pe.author or "")," · ")
  local topics={}; for _,t in ipairs(list(w.topics)) do topics[#topics+1]=labels[t] or t end
  local b={}
  b[#b+1]="---"
  b[#b+1]="title: "..yaml_quote(title)
  b[#b+1]="pagetitle: "..yaml_quote(title.." · Ricardo Custódio")
  b[#b+1]="toc: true"
  b[#b+1]="title-block-banner: false"
  b[#b+1]="---\n"
  b[#b+1]='<div class="scholarly-work-meta">'
  if auth~="" then b[#b+1]="**Authors:** "..auth.."  " end
  if pe.year then b[#b+1]="**Year:** "..clean(pe.year).."  " end
  if #topics>0 then b[#b+1]="**Research areas:** "..table.concat(topics," · ") end
  b[#b+1]="</div>\n"
  if w.selected and w.selected.reason then
    b[#b+1]="## Significance\n\n"..ms(w.selected.reason).."\n"
  end
  b[#b+1]="## Bibliographic manifestations\n"
  local versions=list(w.versions); if #versions==0 then versions={preferred} end
  for _,key in ipairs(versions) do
    local e=bib[key] or {}
    b[#b+1]="### "..manifestation_label(e,key,preferred).."\n"
    if e.title then b[#b+1]="**"..clean(e.title).."**  " end
    if e.author then b[#b+1]=table.concat(authors(e.author),", ").."  " end
    local venue=clean(e.journal or e.booktitle or e.publisher or "")
    if venue~="" then b[#b+1]=venue..(e.year and ", "..clean(e.year) or "").."  "
    elseif e.year then b[#b+1]=clean(e.year).."  " end
    if e.volume then b[#b+1]="Volume "..clean(e.volume)..(e.number and ", no. "..clean(e.number) or "").."  " end
    if e.pages then b[#b+1]="Pages "..clean(e.pages).."  " end
    if e.doi and e.doi~="" then
      local d=clean(e.doi); b[#b+1]="DOI: ["..d.."](https://doi.org/"..d..")"
    elseif e.url and e.url~="" then b[#b+1]="[Publication record]("..clean(e.url)..")" end
    b[#b+1]="\n"
  end
  b[#b+1]="## Persistent identifier\n"
  b[#b+1]="`https://ricardocustodio.com.br/id/work/"..wid.."/`\n"
  b[#b+1]="This page represents the canonical scholarly work. Bibliographic versions above are treated as manifestations of the same intellectual contribution.\n"
  b[#b+1]=jsonld(w,bib,labels)
  return table.concat(b,"\n")
end

function Pandoc(doc)
  local meta=yaml_meta("data/publications.yml"); local bib=parse_bib("bibliography/publications.bib")
  local labels={}; for k,v in pairs(meta.taxonomy.topics or {}) do labels[stringify(k)]=ms(v.label) end
  local selected={}
  for _,w in ipairs(meta.works or {}) do
    if w.selected and ms(w.selected.featured)=="true" then selected[#selected+1]=w end
  end
  table.sort(selected,function(a,b) return tonumber(ms(a.selected.order))<tonumber(ms(b.selected.order)) end)
  os.execute("mkdir -p id/work")
  for _,w in ipairs(selected) do
    local dir="id/work/"..ms(w.id)
    os.execute("mkdir -p "..dir)
    write_file(dir.."/index.qmd",page(w,bib,labels))
  end
  io.stderr:write("Scholarly Registry V1: generated "..#selected.." featured work pages.\n")
  return doc
end
