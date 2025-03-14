-- Ensure packer is installed
local ensure_packer = function()
	local fn = vim.fn
	local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
	if fn.empty(fn.glob(install_path)) > 0 then
		fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
		vim.cmd [[packadd packer.nvim]]
		return true
	end
	return false
end

local packer_bootstrap = ensure_packer()

require('packer').startup(function(use)
	use 'wbthomason/packer.nvim' -- Packer can manage itself
	use 'numToStr/Comment.nvim' -- Comment toggler plugin
	use 'nvim-lua/plenary.nvim'
	use 'nvim-telescope/telescope.nvim'

	if packer_bootstrap then
		require('packer').sync()
	end
end)

-- Theme setup
-- vim.cmd 'colorscheme sorbet'
vim.cmd 'colorscheme lunaperche'
vim.cmd 'syntax on'

vim.o.number = true      -- Enable line numbers
vim.o.relativenumber = true

-- Clear search highlights
vim.api.nvim_set_keymap('n', '<leader>h', ':noh<CR>', { noremap = true, silent = true })

require('Comment').setup()

-- Telescope 
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', function()
	builtin.find_files({
		hidden = true,
		no_ignore = true,
		file_ignore_patterns = { "^%.git/" } -- Hide .git directory
	})
end, { desc = 'Telescope find files (with hidden and ignored except .git)' })
vim.keymap.set('n', '<leader>fg', function()
	builtin.live_grep({
		additional_args = function()
			return { "--hidden", "--no-ignore", "--glob", "!**/.git/*" }
		end
	})
end, { desc = 'Telescope live grep (with hidden and ignored except .git)'})
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

vim.keymap.set("n", "<leader>ee", "oif err != nil {<CR>}<Esc>Oreturn err<Esc>")
vim.keymap.set("n", "<leader>ep", "oif err != nil {<CR>}<Esc>Opanic(err)<Esc>")
-- Define a macro for copying the current line and wrapping it in fmt.Println
vim.api.nvim_set_keymap('n', '<leader>fp', [[:t.<CR>0i fmt.Println(<Esc>A)<Esc>]], { noremap = true, silent = true })
vim.keymap.set('n', '<leader>gf', ':!gofmt -w .<CR>', { noremap = true, silent = true, desc = "Go Format Current Directory"})


-- RipGrep AutoComplete

function _G.rg_complete(findstart, base)
	-- Get the directory Neovim was launched in
	local directory = vim.fn.getcwd()

	if findstart == 1 then
		-- Find the start of the word to complete
		local line = vim.fn.getline(".")  -- Current line
		local col = vim.fn.col(".") - 1  -- Cursor position
		return vim.fn.match(line:sub(1, col), "\\k*$")
	else
		-- Return empty if base is empty
		if base == "" then
			return {}
		end

		-- Transform the base into a regex
		local regex = "\\b" .. base:gsub(".", function(c) return c .. ".*?" end) .. "\\b"

		-- Construct the ripgrep command
		local rg_command = string.format(
		"rg --only-matching --no-filename --no-line-number --no-heading '%s' %s",
		regex,
		directory
		)

		-- Debug: Print the command and base
		print("Ripgrep Command: " .. rg_command)
		print("Base: " .. base)

		-- Run the ripgrep command and collect matches
		local handle = io.popen(rg_command)
		if not handle then
			print("Error: Failed to run ripgrep")
			return {}
		end

		local result = {}
		for line in handle:lines() do
			table.insert(result, line)
		end
		handle:close()

		-- Debug: Print the results
		print("Results: " .. vim.inspect(result))

		-- Deduplicate results, sort by shortest, and return them
		local seen = {}
		local unique_results = {}

		-- First deduplicate
		for _, match in ipairs(result) do
			if not seen[match] then
				seen[match] = true
				table.insert(unique_results, match)
			end
		end

		-- Then sort by length (shortest first)
		table.sort(unique_results, function(a, b)
			return #a < #b
		end)

		-- Limit to top 10 if needed
		if #unique_results > 10 then
			local top_ten = {}
			for i = 1, 10 do
				top_ten[i] = unique_results[i]
			end
			unique_results = top_ten
		end

		return unique_results
	end
end

-- rg --only-matching --no-filename --no-line-number --no-heading "$(echo 'nPrId' | sed 's/./&.*?/g' | sed 's/^/\\b/; s/$/\\b/')" ../ | awk '{ if (length < min || NR == 1) { min = length; shortest = $0 } } END { print shortest }'

-- Set the custom completion function
vim.o.completefunc = "v:lua.rg_complete"
vim.api.nvim_set_keymap('i', '<C-Space>', '<C-x><C-u>', { noremap = true, silent = true })

-- Add this after your colorscheme is set
vim.cmd([[
" Define custom highlight groups for different statusline sections
highlight StatusLineSection1 guibg=#3a3a3a guifg=#ffffff
" Middle section with black background
highlight StatusLineMiddle guibg=#000000 guifg=#000000
" Right section for line numbers
highlight StatusLineSection2 guibg=#3a3a3a guifg=#ffffff

" Set the statusline with different sections
set statusline=
set statusline+=%#StatusLineSection1#\ %m\ %f\ %r\ 
" Empty middle section with black background
set statusline+=%#StatusLineMiddle#%=
" Right section with line numbers on gray background
set statusline+=%#StatusLineSection2#\ %l:%c\ %P\ 
]])


-- General enhanced syntax highlighting for LunaPerche theme
vim.api.nvim_create_autocmd("FileType", {
	pattern = {"c", "cpp", "java", "javascript", "typescript", "python", "ruby", "go", "rust", "php", "lua", "swift", "kotlin", "csharp", "sh", "bash", "zsh", "perl"},
	callback = function()
		vim.cmd([[

		" Special comments with keywords
		syntax keyword TodoComment TODO ISSUE NOTE BUG HACK WARNING XXX contained
		highlight TodoComment guifg=#d787af gui=bold

		" Make special comments stand out in comments
		syntax match Comment /\/\/.*/ contains=TodoComment
		syntax match Comment /--.*/ contains=TodoComment
		syntax match Comment /#.*/ contains=TodoComment
		syntax region Comment start=/\/\*/ end=/\*\// contains=TodoComment

		" Function definitions (works in many languages)
		syntax match FunctionDefinition /\<\(\(function\|func\|def\|fn\|method\|sub\)\s\+\)\?\w\+\s*\ze(/
		highlight FunctionDefinition guifg=#af87af gui=bold

		" Function calls (generic pattern)
		syntax match FunctionCall /\<\w\+\>\ze\s*(/
		highlight FunctionCall guifg=#d7afff

		" Strings - more vibrant
		highlight String guifg=#af8787 gui=italic

		" Numbers - make them stand out
		highlight Number guifg=#d7afd7

		" Constants and special values
		syntax keyword SpecialConstant null nil none undefined true false NULL NIL None
		highlight SpecialConstant guifg=#af87d7 gui=bold

		" Brackets and parentheses
		syntax match Brackets /[[\](){}]/
		highlight Brackets guifg=#87afaf

		" Operators
		syntax match Operators /[+\-*/%=<>!&|^~:;.,?]/
		highlight Operators guifg=#d7d7af

		" Class/type definitions (works in many OO languages)
		syntax match ClassDefinition /\<\(class\|interface\|struct\|type\|enum\)\s\+\w\+/
		highlight ClassDefinition guifg=#afafd7 gui=bold

		" Important keywords across languages
		syntax keyword ImportantKeyword if else for while do switch case default return break continue
		syntax keyword ImportantKeyword try catch finally throw exception import export from as
		syntax keyword ImportantKeyword public private protected static final const let var void
		highlight ImportantKeyword guifg=#8787af gui=bold

		" Self references in various languages
		syntax keyword SelfReference self this super Me
		highlight SelfReference guifg=#d787af gui=italic

		" URLs in comments
		syntax match UrlInComment /https\?:\/\/\(\w\+\(:\w\+\)\?@\)\?\([A-Za-z][-_0-9A-Za-z]*\.\)\{1,}\(\w\{2,}\.\?\)\{1,}\(:[0-9]\{1,5}\)\?\S*/ contained
		highlight UrlInComment guifg=#afd7d7 gui=underline

		" Simple property access (some.Thing with nothing after)
		syntax match PropertyAccess /\<\w\+\(\.\w\+\)\+\>/ contains=PropertyPart
		highlight PropertyAccess guifg=#afaf87 gui=italic

		" Property part after dot in simple property access
		syntax match PropertyPart /\(\.\)\@<=\w\+/ contained
		highlight PropertyPart guifg=#d7afaf gui=italic

		" Array/index access after property (some.Thing[]) - without highlighting brackets
		syntax match ArrayAccess /\<\w\+\(\.\w\+\)\+\ze\s*\[/
		highlight ArrayAccess guifg=#d7d7af gui=bold

		" Method calls after property (some.Thing() - without highlighting parentheses
		syntax match MethodCall /\<\w\+\(\.\w\+\)\+\ze\s*(/
		highlight MethodCall guifg=#af87d7 gui=bold


		" Add proper string highlighting that won't break with single quotes in comments
		" Single quoted strings
		syntax region String start=/'/ skip=/\\'/ end=/'/ 
		" Double quoted strings
		syntax region String start=/"/ skip=/\\"/ end=/"/ 

		" Make sure comments are processed first (higher priority)
		syntax match Comment /\/\/.*/ contains=TodoComment,UrlInComment
		syntax match Comment /--.*/ contains=TodoComment,UrlInComment
		syntax match Comment /#.*/ contains=TodoComment,UrlInComment
		syntax region Comment start=/\/\*/ end=/\*\// contains=TodoComment,UrlInComment
		]])
	end
})
