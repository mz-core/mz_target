-- MZ global locale switch.
-- Reuses the canonical ox_lib locale loader already used by mz_radialmenu:
-- server.cfg sets `setr ox:locale pt-br` (or en / en-us); files live in
-- locales/<code>.json. pt-br is the default when the convar is absent.
local configuredLocale = tostring(GetConvar('ox:locale', '')):lower()
if configuredLocale == '' or configuredLocale == 'pt' then
  configuredLocale = 'pt-br'
end

if type(lib) == 'table' and type(lib.locale) == 'function' then
  local ok, err = pcall(lib.locale, configuredLocale)
  if not ok then
    print(('[mz_target] locale load failed (%s): %s'):format(configuredLocale, tostring(err)))
  end
end

function MZTargetText(key, ...)
  if type(locale) == 'function' then
    local value = locale(key, ...)
    if type(value) == 'string' and value ~= key then
      return value
    end
  end

  return key
end
