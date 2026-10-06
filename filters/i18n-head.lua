-- filters/i18n-head.lua
-- Multilingual SEO metadata: canonical and hreflang links.

local stringify = pandoc.utils.stringify

local function meta_raw_html(html)
  return pandoc.MetaBlocks({
    pandoc.RawBlock("html", html)
  })
end

function Meta(meta)
  if not meta["canonical-path"] then
    return meta
  end

  local path = stringify(meta["canonical-path"])
  local base = "https://ricardocustodio.com.br"

  -- Remove the language prefix (/en, /pt, /es) while preserving
  -- the equivalent page path.
  local suffix = path:gsub("^/[^/]+", "")

  if suffix == "" then
    suffix = "/"
  end

  local function url_for(lang)
    if suffix == "/" then
      return base .. "/" .. lang .. "/"
    end

    return base .. "/" .. lang .. suffix
  end

  local html = table.concat({
    '<link rel="canonical" href="' .. base .. path .. '">',
    '<link rel="alternate" hreflang="en" href="' .. url_for("en") .. '">',
    '<link rel="alternate" hreflang="pt-BR" href="' .. url_for("pt") .. '">',
    '<link rel="alternate" hreflang="es" href="' .. url_for("es") .. '">',
    '<link rel="alternate" hreflang="x-default" href="' .. (suffix == "/" and (base .. "/") or url_for("pt")) .. '">'
  }, "\n")

  local seo = meta_raw_html(html)

  if meta["header-includes"] == nil then
    meta["header-includes"] = seo
  else
    -- Do not reinterpret the existing metadata as Pandoc Blocks.
    -- Keep both metadata values as separate entries.
    meta["header-includes"] = pandoc.MetaList({
      meta["header-includes"],
      seo
    })
  end

  return meta
end
