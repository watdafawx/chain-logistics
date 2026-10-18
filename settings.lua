data:extend({
  {
    -- (a startup setting: the posts' and packages' sprites are prototypes, the same for every player)
    type = "string-setting",
    name = "chl-skin",
    setting_type = "startup",
    default_value = "magenta",
    allowed_values = { "magenta", "toxic", "orange", "red" },
    order = "a",
  },
  {
    type = "int-setting",
    name = "chl-package-size",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 20,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "chl-share-with-bots",
    setting_type = "runtime-global",
    default_value = false,
    order = "c",
  },
  {
    type = "int-setting",
    name = "chl-chests-per-tick",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 100,
    order = "d",
  },
})
