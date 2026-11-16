-- Selected language, falls back to English for missing keys
Locale = setmetatable(Locales[Config.Language] or {}, { __index = Locales['en'] })
