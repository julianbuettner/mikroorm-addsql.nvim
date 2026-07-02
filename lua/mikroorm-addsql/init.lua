-- Treesitter injection + conform.nvim formatter for MikroORM's
-- `this.addSql(\`...\`)` raw SQL migrations.
--
-- See ../../README.md for what this does and how it works.
local M = {}

local default_config = {
	shiftwidth = 2,
}

M.config = vim.deepcopy(default_config)

---@param opts? table
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

local query_text = [[
(call_expression
  function: [
    (identifier) @_name
    (member_expression property: (property_identifier) @_name)
  ]
  (#eq? @_name "addSql")
  arguments: (arguments
    . (template_string) @tmpl))
]]

---Reshape every `addSql(\`...\`)` call in `lines` so the SQL starts on its
---own line and the closing backtick lines up with the `addSql(` call.
---@param lines string[]
---@param shiftwidth? integer
---@return string[]
function M.shape(lines, shiftwidth)
	shiftwidth = shiftwidth or M.config.shiftwidth
	local text = table.concat(lines, "\n") .. "\n"
	local ok, parser = pcall(vim.treesitter.get_string_parser, text, "typescript")
	if not ok then
		return lines
	end
	local tree = parser:parse(true)[1]
	local root = tree:root()
	local query = vim.treesitter.query.parse("typescript", query_text)

	local edits = {}
	for _, captures in query:iter_matches(root, text, 0, -1) do
		local tmpl
		for id, nodes in pairs(captures) do
			if query.captures[id] == "tmpl" then
				tmpl = nodes[1]
			end
		end
		if tmpl then
			local call_start_row = tmpl:parent():parent():range()
			local sr, sc, er, ec = tmpl:range()
			local call_line = lines[call_start_row + 1] or ""
			local call_indent = call_line:match("^%s*") or ""
			local content_indent = call_indent .. string.rep(" ", shiftwidth)

			local raw = vim.treesitter.get_node_text(tmpl, text)
			local inner = raw:sub(2, -2) -- strip surrounding backticks
			local collapsed = inner:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

			local new_text
			if collapsed == "" then
				new_text = "``"
			else
				new_text = "`\n" .. content_indent .. collapsed .. "\n" .. call_indent .. "`"
			end

			table.insert(edits, { sr = sr, sc = sc, er = er, ec = ec, text = new_text })
		end
	end

	if #edits == 0 then
		return lines
	end

	-- Apply edits bottom-to-top so earlier positions stay valid
	table.sort(edits, function(a, b)
		if a.sr ~= b.sr then
			return a.sr > b.sr
		end
		return a.sc > b.sc
	end)

	for _, e in ipairs(edits) do
		local start_line = lines[e.sr + 1]
		local end_line = lines[e.er + 1]
		local prefix = start_line:sub(1, e.sc)
		local suffix = end_line:sub(e.ec + 1)

		local new_lines = vim.split(e.text, "\n", { plain = true })
		new_lines[1] = prefix .. new_lines[1]
		new_lines[#new_lines] = new_lines[#new_lines] .. suffix

		local before = {}
		for i = 1, e.sr do
			before[i] = lines[i]
		end
		local after = {}
		for i = e.er + 2, #lines do
			after[#after + 1] = lines[i]
		end

		lines = vim.list_extend(vim.list_extend(before, new_lines), after)
	end

	return lines
end

---conform.nvim-compatible formatter. Wire it in with:
---  opts.formatters.mikroorm_addsql = require("mikroorm-addsql").formatter
---@type conform.LuaFormatterConfig
M.formatter = {
	meta = {
		description = "Normalize this.addSql(`...`) template shape for MikroORM migrations",
	},
	format = function(_, ctx, lines, callback)
		callback(nil, M.shape(lines, ctx.shiftwidth))
	end,
}

return M
