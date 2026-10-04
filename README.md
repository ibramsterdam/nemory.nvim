<div align="center">

<img src="assets/banner.svg" alt="nemory: a developer thinking behind a laptop, with a thought cloud that fills up with todos and a weekly log" width="820">

<br>

[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
![Markdown](https://img.shields.io/badge/notes-plain%20markdown-7aa2f7)
![Sync](https://img.shields.io/badge/sync-git%20(optional)-bb9af7)
![Dependencies](https://img.shields.io/badge/dependencies-none-1a1b26)

**Remember what you did. Keep track of what's next.**

Todos with notes, and a weekly log of everything you finished.
One key away in Neovim. Plain markdown, synced with git if you want.

</div>

---

## Why

During work you think of things to do all day. At the end of the week you forget what you
actually did.

nemory keeps both in one place. You write todos as you go. When you finish one, it shows up in
your week. Standups and reviews write themselves.

- ✅ **Todos**: a clean overview table. Each todo has a title, and notes when you need them.
- 📅 **Your week**: everything you finished, grouped per day. Copy it as markdown in one key.
- 🏷️ **Tags**: keep `#work` and `#private` apart, and filter on them.
- 🔄 **Sync**: point it at a private git repo and your todos follow you to every computer.
- 🪶 **Tiny**: plain Lua, zero dependencies.

## Quick start

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ibramsterdam/nemory.nvim",
  opts = {},
}
```

That's it. Your todos live in `~/notes/todos`.

- Press `<leader>na` and type `Fix the flaky spec #work`.
- Press `<leader>nt` to see all your todos.
- Press `<leader>nw` to see what you finished this week.

## Todos

`<leader>nt` opens the overview table.

```
╭──────────────────────────── Todo · 2 open ─────────────────────────────╮
│     Todo                      Tags      Created      Done         Age  │
│ ○   Write migration plan  ≡   #work     2026-10-03                1d   │
│ ○   Renew passport            #private  2026-10-02                2d   │
│ ✓   Ship payments API     ≡   #work     2026-09-25   2026-10-01   6d   │
╰─ x done  a add  ↵ open  r rename  dd delete  H hide done  t tag  w week ─╯
```

- Open todos come first, oldest at the top.
- `≡` means the todo has notes.
- Age is how long a todo has been open, or how long it took to finish.

Press `↵` to open a todo and write notes. Press `q` to save and go back to the table.

### Tags

Add tags with `#` when you create a todo:

```
Renew passport #private
Prep the demo #work #urgent
```

Only words that start with a letter become tags. So `Review PR #482` keeps `#482` in the title.

Press `t` in the table to filter by tag. Press it again for the next tag, until you are back
at all todos.

## Your week

`<leader>nw` shows everything you finished this week, grouped per day.

```
╭──────────── Week 40 · Sep 28 to Oct 4 ────────────╮
│ Tuesday · Sep 29                                  │
│   ✓   Fix flaky checkout spec          ≡   #work  │
│   ✓   Review PR #482                       #work  │
│                                                   │
│ Thursday · Oct 1                                  │
│   ✓   Ship payments API                ≡   #work  │
╰─ [ prev  ] next  y copy  ↵ open  t tag  w todos ──╯
```

- `[` and `]` go to the previous or next week.
- `t` filters by tag, so you can show only `#work`.
- `y` copies the week as markdown, ready for a standup or a review.

Did something without a todo? Press `<leader>nd` to log it as done right away.

## Files

Every todo is a markdown file, like `todos/2026-10-04-write-migration-plan.md`:

```markdown
---
title: Write migration plan
created: 2026-10-03
done:
tags: work
---

Steps:
- backup the database
- run the migration on staging first
```

You can edit these files by hand at any time. One file per todo also means git rarely runs into
merge conflicts when you sync.

## Sync between computers

Sync is off by default. To turn it on:

1. Create a **private** repo on GitHub, for example `notes`.
2. Clone it to your notes folder on every computer:

   ```sh
   git clone git@github.com:you/notes.git ~/notes
   ```

3. Enable sync:

   ```lua
   opts = {
     sync = { enabled = true },
   }
   ```

What happens then:

- Before nemory opens the table, it pulls the latest changes. At most once a minute.
- After you change a todo, it commits and pushes in the background.
- `:Nemory sync` pulls and pushes right away.

Everything runs async. Neovim never blocks. If you're offline, nemory warns you and pushes
on the next change.

## Commands & keys

| Mapping | Command | Action |
| --- | --- | --- |
| `<leader>nt` | `:Nemory todos` | Open the todo table |
| `<leader>na` | `:Nemory add` | Add a todo from anywhere |
| `<leader>nd` | `:Nemory done` | Log something you did, already done |
| `<leader>nw` | `:Nemory week` | Open this week |
| `<leader>ns` | `:Nemory search` | Search all notes (Telescope, if installed) |
| | `:Nemory sync` | Pull and push now |

Keys inside the window:

| Key | Todos | Week |
| --- | --- | --- |
| `x` | Mark as done or not done | |
| `a` | Add a todo | |
| `↵` | Open the todo and its notes | Open the todo and its notes |
| `r` | Rename | Rename |
| `dd` | Delete | |
| `H` | Hide or show done todos | |
| `t` | Filter by tag | Filter by tag |
| `w` | Go to the week | Go to the todos |
| `[` `]` | | Previous or next week |
| `y` | | Copy the week as markdown |
| `q` | Close | Close |

## Configuration

These are the defaults. Pass only what you want to change:

```lua
require("nemory").setup({
  dir = "~/notes",
  todo_dir = "todos",
  default_tags = {},
  sync = {
    enabled = false,
    commit_message = "Update notes",
    pull_interval = 60,
  },
  keys = {
    todos = "<leader>nt",
    add_todo = "<leader>na",
    log_done = "<leader>nd",
    week = "<leader>nw",
    search = "<leader>ns",
  },
  view = {
    hide_completed = false,
    keys = {
      toggle = "x",
      add = "a",
      open = "<CR>",
      rename = "r",
      delete = "dd",
      toggle_completed = "H",
      filter = "t",
      week = "w",
      prev_week = "[",
      next_week = "]",
      yank = "y",
      close = "q",
    },
  },
})
```

- Set any key to `false` to turn it off.
- `default_tags` are used when you add a todo without tags. For example `{ "work" }`.

## The name

**n**vim + m**emory**. A memory for your editor, so you don't need one.

## License

MIT
