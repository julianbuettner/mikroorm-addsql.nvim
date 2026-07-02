local M = {}

function M.check()
	vim.health.start("mikroorm-addsql.nvim")

	local ts_ok = pcall(vim.treesitter.get_string_parser, "", "typescript")
	if ts_ok then
		vim.health.ok("treesitter parser for 'typescript' is available")
	else
		vim.health.error("treesitter parser for 'typescript' is not installed", {
			"Run :TSInstall typescript",
		})
	end

	local sql_ok = pcall(vim.treesitter.language.add, "sql")
	if sql_ok then
		vim.health.ok("treesitter parser for 'sql' is available")
	else
		vim.health.error("treesitter parser for 'sql' is not installed", {
			"Run :TSInstall sql",
			"Required so the injected SQL region can be created, even though this plugin never parses the SQL itself",
		})
	end

	local conform_ok, conform = pcall(require, "conform")
	if conform_ok then
		vim.health.ok("conform.nvim is installed")
		local formatter_ok = pcall(function()
			return conform.formatters_by_ft
		end)
		if formatter_ok then
			vim.health.info(
				"Remember to add 'mikroorm_addsql' and 'injected' to formatters_by_ft.typescript (see README)"
			)
		end
	else
		vim.health.warn("conform.nvim not found — the formatter half of this plugin needs it", {
			"https://github.com/stevearc/conform.nvim",
			"Syntax highlighting from the treesitter injection query works without it",
		})
	end
end

return M
