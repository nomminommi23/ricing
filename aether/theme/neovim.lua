return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#1a1b26",
        dark_bg    = "#14141d",
        darker_bg  = "#0d0e13",
        lighter_bg = "#31323c",

        fg         = "#c0caf5",
        dark_fg    = "#9098b8",
        light_fg   = "#c9d2f7",
        bright_fg  = "#d0d7f8",
        muted      = "#565f89",

        red        = "#f7768e",
        yellow     = "#f9e2af",
        orange     = "#f88b9f",
        green      = "#a6e3a1",
        cyan       = "#89dceb",
        blue       = "#1793d1",
        purple     = "#cba6f7",
        brown      = "#95535f",

        bright_red    = "#f7768e",
        bright_yellow = "#f9e2af",
        bright_green  = "#a6e3a1",
        bright_cyan   = "#89dceb",
        bright_blue   = "#7aa2f7",
        bright_purple = "#cba6f7",

        accent               = "#1793d1",
        cursor               = "#c0caf5",
        foreground           = "#c0caf5",
        background           = "#1a1b26",
        selection             = "#31323c",
        selection_foreground = "#c0caf5",
        selection_background = "#31323c",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
