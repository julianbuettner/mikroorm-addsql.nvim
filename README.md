# mikroorm-addsql.nvim

> [!WARNING]
> **This plugin is LLM-generated. No guarantees.**
> It was written end-to-end by an AI coding assistant (Claude), based on a
> single user's Neovim config and tested only against a handful of
> hand-written examples in a headless Neovim session. It has not been used
> in a real MikroORM project, code-reviewed by a human expert, or hardened
> against edge cases. Treat it as a starting point / proof of concept,
> read the code before trusting it, and expect to fix things.
> Use at your own risk.

Syntax-highlights and auto-formats raw SQL embedded in [MikroORM](https://mikro-orm.io/)
migration files — the `this.addSql(\`...\`)` calls you write in `*.ts`
migrations.

```ts
// before
this.addSql(`select   *   from "user"    where id=1   ;`);

// after <leader>fo (or any conform.nvim format-on-save)
this.addSql(`
  SELECT
      *
  FROM
      "user"
  WHERE
      id = 1;
`);
```

Syntax highlighting for the SQL inside the backticks works as soon as the
plugin is loaded (no config needed, beyond having the `sql` treesitter
parser installed). Auto-formatting requires
[conform.nvim](https://github.com/stevearc/conform.nvim) and a couple of
lines of wiring — see below.

## How it works

1. A treesitter injection query (`queries/typescript/injections.scm`) tags
   the content of `this.addSql(\`...\`)` / `addSql(\`...\`)` template
   literals as the `sql` language. This is the same mechanism
   `nvim-treesitter` uses for things like `` gql`...` `` or
   styled-components — it's what gives you syntax highlighting for free,
   and it's also what lets conform.nvim's built-in `injected` formatter
   find the region and run your configured SQL formatter (`sqlfluff`,
   `pg_format`, etc.) on it.
2. A small custom conform.nvim formatter (`lua/mikroorm-addsql/init.lua`)
   normalizes the *shape* of the call before the SQL formatter runs: it
   makes sure the content starts on its own line after the opening
   backtick, and that the closing backtick lines up with the indentation
   of the `addSql(` call. Without this step, conform's `injected`
   formatter only *preserves* whatever shape is already there — it won't
   insert line breaks for you, so a query written on a single line stays
   ugly forever. This plugin's formatter fixes the shape once, every time,
   idempotently, so you can write raw SQL however you want and it
   converges to the same layout.

## Requirements

- Neovim ≥ 0.10 (uses `vim.treesitter.query.parse`, `Query:iter_matches`)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
  with the `typescript` and `sql` parsers installed (`:TSInstall typescript
  sql`)
- [conform.nvim](https://github.com/stevearc/conform.nvim), only if you
  want the auto-formatting half. Syntax highlighting works without it.

Run `:checkhealth mikroorm-addsql` after installing to verify all of the
above.

## Installation

Published at [julianbuettner/mikroorm-addsql.nvim](https://github.com/julianbuettner/mikroorm-addsql.nvim).
With [lazy.nvim](https://github.com/folke/lazy.nvim), add it as a
dependency of conform.nvim so it's loaded before conform's `opts` runs:

```lua
{
  "stevearc/conform.nvim",
  dependencies = {
    "julianbuettner/mikroorm-addsql.nvim",
  },
  opts = function()
    return {
      formatters = {
        mikroorm_addsql = require("mikroorm-addsql").formatter,
      },
      formatters_by_ft = {
        typescript = { "mikroorm_addsql", "injected", "prettierd", "prettier" },
      },
    }
  end,
}
```

`opts` must be a function (not a plain table) here — a plain table is
evaluated while lazy.nvim is still only collecting plugin specs, before
`mikroorm-addsql.nvim` has actually been loaded onto `'runtimepath'`, so
`require("mikroorm-addsql")` would fail. Wrapping it in a function defers
evaluation until after dependencies are loaded.

## Configuration

The treesitter query loads automatically once the plugin is on
`'runtimepath'` — nothing to do there.

For formatting, register the formatter with conform.nvim (see the install
snippet above) and add it — plus conform's built-in `injected` formatter
— to your `typescript` `formatters_by_ft` entry, before whatever else you
run (e.g. prettier). `injected` must come after `mikroorm_addsql` since it
relies on the shape `mikroorm_addsql` establishes; anything you list after
`injected` (like prettier) runs on the whole file afterward and won't
touch the template literal's contents.

Then formatting a `.ts` buffer (e.g. `require("conform").format()`, or
however you've bound it) will reshape and reformat every `addSql(\`...\`)`
call in the file.

### Options

```lua
require("mikroorm-addsql").setup({
  shiftwidth = 2, -- indent used for the SQL content, if conform doesn't supply one
})
```

conform.nvim normally passes the buffer's real `shiftwidth` through
automatically, so you usually don't need to set this.

## Limitations / things that were not verified

- Only matches template-literal arguments (`` addSql(`...`) ``), not plain
  quoted strings (`addSql('...')`) — SQL formatters tend to reformat onto
  multiple lines, which would break a non-template string. If your
  migrations use plain quotes, convert them to backticks first.
- Only tested against `typescript` filetype migrations, and only against
  small, hand-written example snippets — not against a real MikroORM
  project or a large migration file.
- Only matches a function/method literally named `addSql` (with or
  without a `this.`/object prefix). Other ORMs' raw-SQL calls (Knex
  `.raw()`, TypeORM `.query()`, Prisma `$queryRaw()`, ...) are not
  covered; copy `queries/typescript/injections.scm` and adjust the
  `#eq?` predicate if you need that.
- No test suite. Verification so far was manual, via headless Neovim
  scripts during development.

Again: **LLM-generated, use at your own risk.** Read `lua/mikroorm-addsql/init.lua`
(it's short) before relying on it.
