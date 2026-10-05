local stringify=pandoc.utils.stringify
local function read_yaml(path)
 local f=io.open(path,"r"); if not f then return nil end
 local c=f:read("*all"); f:close()
 local d=pandoc.read("---\n"..c.."\n---\n","markdown+yaml_metadata_block")
 return d and d.meta or nil
end
local function text(v) if v==nil then return "" end return stringify(v) end
local function title(p) local t=text(p.public_title); if t~="" then return t end return text(p.title) end
local function summary(p) local s=text(p.public_summary); if s~="" then return s end return text(p.summary) end
local labels={["accountability"]="Accountability",["ai-agents"]="AI Agents",["artificial-intelligence"]="Artificial Intelligence",["authorization"]="Authorization",["civil-registration"]="Civil Registration",["clarciev"]="CLARCIEV",["confidentiality"]="Confidentiality",["cryptography"]="Cryptography",["data-protection"]="Data Protection",["digital-identity"]="Digital Identity",["digital-preservation"]="Digital Preservation",["digital-signatures"]="Digital Signatures",["digital-trust"]="Digital Trust",["document-management"]="Document Management",["electronic-documents"]="Electronic Documents",["finite-fields"]="Finite Fields",["information-security"]="Information Security",["irreducible-polynomials"]="Irreducible Polynomials",["modular-reduction"]="Modular Reduction",["ocr"]="OCR",["open-insurance"]="Open Insurance",["post-quantum-cryptography"]="Post-Quantum Cryptography",["public-key-infrastructure"]="PKI",["regulatory-compliance"]="Regulatory Compliance"}
local function topics(p)
 if not p.topics or #p.topics==0 then return nil end
 local x=pandoc.Inlines({})
 for i,v in ipairs(p.topics) do
  if i>1 then x:insert(pandoc.Space()); x:insert(pandoc.Str("·")); x:insert(pandoc.Space()) end
  local r=text(v); x:insert(pandoc.Span(pandoc.Inlines(labels[r] or r),pandoc.Attr("",{"project-topic"})))
 end
 return pandoc.Para(x)
end
local function website(p)
 if p.links then for _,l in ipairs(p.links) do if text(l.type)=="website" and text(l.url)~="" then return text(l.url) end end end
end
local function sort_title(xs) table.sort(xs,function(a,b) return title(a):lower()<title(b):lower() end) end
local function card(p,cls,level)
 local b={pandoc.Header(level or 3,pandoc.Inlines(title(p)))}; local st=text(p.subtitle)
 if st~="" then table.insert(b,pandoc.Para({pandoc.Emph(pandoc.Inlines(st))})) end
 local s=summary(p); if s~="" then table.insert(b,pandoc.Para(pandoc.Inlines(s))) end
 local tb=topics(p); if tb then table.insert(b,tb) end
 local u=website(p); if u then table.insert(b,pandoc.Para({pandoc.Link(pandoc.Inlines("Project website"),u)})) end
 return pandoc.Div(b,pandoc.Attr("",{cls}))
end
local function current_sets(ps)
 local programs,roots,children={},{},{}
 for _,p in ipairs(ps) do if text(p.status)=="current" then
  local par=text(p.parent)
  if par~="" then children[par]=children[par] or {}; table.insert(children[par],p)
  elseif text(p.scope)=="research-program" then table.insert(programs,p) else table.insert(roots,p) end
 end end
 sort_title(programs); sort_title(roots); for _,x in pairs(children) do sort_title(x) end
 return programs,roots,children
end
local function parent_card(p,children)
 local base=card(p,"project-parent-content",3); local b={}
 for _,x in ipairs(base.content) do table.insert(b,x) end
 local xs=children[text(p.id)]
 if xs and #xs>0 then
  table.insert(b,pandoc.Header(4,pandoc.Inlines("Related initiatives"))); local cb={}
  for _,c in ipairs(xs) do table.insert(cb,card(c,"project-child-card",4)) end
  table.insert(b,pandoc.Div(cb,pandoc.Attr("",{"project-children-grid"})))
 end
 return pandoc.Div(b,pandoc.Attr("",{"project-card","project-parent-card"}))
end
local function yn(v) return tonumber(text(v)) end
local function pkey(p) local y=yn(p.start); if not y then return "undated" elseif y>=2020 then return "2020-2026" elseif y>=2010 then return "2010-2019" elseif y>=2000 then return "2000-2009" else return "before-2000" end end
local order={"2020-2026","2010-2019","2000-2009","before-2000","undated"}
local pt={["2020-2026"]="2020–2026",["2010-2019"]="2010–2019",["2000-2009"]="2000–2009",["before-2000"]="Before 2000",["undated"]="Undated"}
local nl={["research"]="Research",["technological-development"]="Technological Development",["extension"]="Extension"}
local function archives(ps)
 local g={}; local n=0
 for _,p in ipairs(ps) do if text(p.status)=="completed" then n=n+1; local k=pkey(p); g[k]=g[k] or {}; table.insert(g[k],p) end end
 for _,xs in pairs(g) do table.sort(xs,function(a,b) local ay,by=yn(a.start) or 0,yn(b.start) or 0; if ay~=by then return ay>by end return title(a):lower()<title(b):lower() end) end
 return g,n
end
local function archive_item(p)
 local b={}; local a,e=text(p.start),text(p["end"]); local yrs=a
 if e~="" then yrs=a.."–"..e elseif a~="" then yrs=a.."–?" end
 local h=title(p); if yrs~="" then h=h.." · "..yrs end
 table.insert(b,pandoc.Header(4,pandoc.Inlines(h)))
 local n=nl[text(p.nature)] or text(p.nature); if n~="" then table.insert(b,pandoc.Para({pandoc.Strong(pandoc.Inlines(n))})) end
 local s=summary(p); if s~="" then table.insert(b,pandoc.Para(pandoc.Inlines(s))) end
 local l=text(p.legacy_note); if l~="" then table.insert(b,pandoc.Para({pandoc.Emph(pandoc.Inlines("Legacy: "..l))})) end
 return pandoc.Div(b,pandoc.Attr("",{"archive-project"}))
end
local function current(meta)
 local programs,roots,children=current_sets(meta.projects); local b={}
 table.insert(b,pandoc.Header(2,pandoc.Inlines("Current Research Programs ("..#programs..")"))); local pg={}
 for _,p in ipairs(programs) do table.insert(pg,card(p,"research-program-card",3)) end
 table.insert(b,pandoc.Div(pg,pandoc.Attr("",{"research-programs-grid"})))
 table.insert(b,pandoc.Header(2,pandoc.Inlines("Current Projects ("..#roots..")"))); local cg={}
 for _,p in ipairs(roots) do table.insert(cg,parent_card(p,children)) end
 table.insert(b,pandoc.Div(cg,pandoc.Attr("",{"projects-grid"})))
 return pandoc.Div(b,pandoc.Attr("",{"projects-generated"}))
end
local function archive(meta)
 local g,n=archives(meta.projects); local b={}
 table.insert(b,pandoc.Header(2,pandoc.Inlines("Project Archive")))
 table.insert(b,pandoc.Para({pandoc.Emph(pandoc.Inlines(tostring(n).." historical projects"))}))
 table.insert(b,pandoc.Para(pandoc.Inlines("Historical projects are grouped by starting year. An unknown closing year is shown as “?”.")))
 for _,k in ipairs(order) do local xs=g[k]; if xs and #xs>0 then
  table.insert(b,pandoc.RawBlock("html",'<details class="project-period"><summary>'..pt[k]..' ('..#xs..')</summary>'))
  for _,p in ipairs(xs) do table.insert(b,archive_item(p)) end
  table.insert(b,pandoc.RawBlock("html","</details>"))
 end end
 return pandoc.Div(b,pandoc.Attr("",{"project-archive-generated"}))
end
function Div(div)
 if not div.classes:includes("projects-current-generated") and not div.classes:includes("projects-archive-generated") then return nil end
 local m=read_yaml("data/projects.yml")
 if not m or not m.projects then return pandoc.Div({pandoc.Para({pandoc.Strong(pandoc.Inlines("Unable to load project data."))})}) end
 if div.classes:includes("projects-current-generated") then return current(m) end
 return archive(m)
end
