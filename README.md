<div align="center">

<img src="assets/banner.svg" alt="nemory: a developer thinking behind a laptop, with a thought cloud that fills up with todos and a work log" width="820">

<br>

[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
![Markdown](https://img.shields.io/badge/notes-plain%20markdown-7aa2f7)
![Sync](https://img.shields.io/badge/sync-git%20(optional)-bb9af7)
![Dependencies](https://img.shields.io/badge/dependencies-none-1a1b26)

**Remember what you did. Keep track of what's next.**

A weekly work log and a todo list, one key away in Neovim.
Plain markdown files, synced between your computers with git if you want.

</div>

---

## Why

At the end of the week you forget what you did on Monday. And private todos end up on sticky
notes, in five different apps, or nowhere.

nemory keeps both in Neovim, where you already are.

- 📓 **Work log**: one file per week, with a heading per day. Great for standups and reviews.
- ✅ **Todos**: a clean overview table. Each todo saves when you created it and when you finished it.
- 🔄 **Sync**: point it at a private git repo and your notes follow you to every computer.
- 🪶 **Tiny**: a few hundred lines of Lua, zero dependencies.

## Quick start

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ibramsterdam/nemory.nvim",
  opts = {},
}
```

That's it. Your notes live in `~/notes`.

- Press `<leader>nw` and write down what you did today.
- Press `<leader>na` to add a todo.
- Press `<leader>nt` to see all your todos.

## The work log

`<leader>nw` opens this week's file and jumps to today. A new day gets its own heading.

```markdown
# Week 40, 2026 (Sep 28 to Oct 4)

## 2026-09-28 Monday

- Shipped the payments API
- Reviewed 3 PRs

## 2026-09-29 Tuesday

- Fixed the flaky checkout spec
```

Files are named by ISO week, like `worklog/2026-W40.md`. One week fits on one screen, so looking
back is quick.

## The todo list

`<leader>nt` opens an overview table in a floating window.

```
╭──────────────────────── Todo · 2 open ────────────────────────╮
│     Todo                     Created      Done         Age     │
│ ○   Fix bike tyre            2026-10-02                2d      │
│ ○   Renew passport           2026-10-04                0d      │
│ ✓   Call dentist             2026-09-28   2026-10-01   3d      │
╰─ x done  a add  e edit  dd delete  H hide done  o file  q close ─╯
```

Open todos come first, oldest at the top. Age shows how long a todo has been open, or how long
it took to finish.

Keys inside the table:

| Key | Action |
| --- | --- |
| `x` | Mark as done or not done |
| `a` | Add a todo |
| `e` | Edit the text |
| `dd` | Delete |
| `H` | Hide or show done todos |
| `o` | Open `todo.md` itself |
| `q` | Close |

Behind the table is a plain markdown file. You can edit it by hand at any time.

```markdown
# Todo

- [ ] Renew passport @created(2026-10-04)
- [x] Call dentist @created(2026-09-28) @done(2026-10-01)
```

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

- Before nemory opens your notes, it pulls the latest changes. At most once a minute.
- After you save a note or change a todo, it commits and pushes in the background.
- `:Nemory sync` pulls and pushes right away.

Everything runs async. Neovim never blocks. If you're offline, nemory warns you and pushes
on the next save.

## Commands & keys

| Mapping | Command | Action |
| --- | --- | --- |
| `<leader>nw` | `:Nemory worklog` | Open this week's work log |
| `<leader>nt` | `:Nemory todos` | Open the todo table |
| `<leader>na` | `:Nemory add` | Add a todo from anywhere |
| `<leader>ns` | `:Nemory search` | Search all notes (Telescope, if installed) |
| | `:Nemory sync` | Pull and push now |

## Configuration

These are the defaults. Pass only what you want to change:

```lua
require("nemory").setup({
  dir = "~/notes",
  worklog_dir = "worklog",
  todo_file = "todo.md",
  sync = {
    enabled = false,
    commit_message = "Update notes",
    pull_interval = 60,
  },
  keys = {
    worklog = "<leader>nw",
    todos = "<leader>nt",
    add_todo = "<leader>na",
    search = "<leader>ns",
  },
  view = {
    hide_completed = false,
    keys = {
      toggle = "x",
      add = "a",
      edit = "e",
      delete = "dd",
      toggle_completed = "H",
      open_file = "o",
      close = "q",
    },
  },
})
```

Set any key to `false` to turn it off.

## The name

**n**vim + m**emory**. A memory for your editor, so you don't need one.

## License

MIT
