--- @since 25.12.29

local M = {}

-- Helper: URL decode percent-encoded sequences (%20 -> space)
local function url_decode(str)
	if not str then
		return ""
	end
	return (string.gsub(str, "%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

-- Helper: Get default Trash files directory fallback
local function get_default_trash_files_dir()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
	local xdg_data = os.getenv("XDG_DATA_HOME")
	if xdg_data and xdg_data ~= "" then
		return xdg_data .. "/Trash/files"
	elseif home ~= "" then
		return home .. "/.local/share/Trash/files"
	end
	return ""
end

-- Pure Function: Resolve file/virtual URIs (e.g. Yazi Nightly trash://) to POSIX paths for eza CLI
local function resolve_url(url_str)
	if type(url_str) ~= "string" or url_str == "" then
		return ""
	end

	-- Handle Yazi Nightly trash:// URIs (matching Yazi PR #4144 spec)
	if string.match(url_str, "^trash:") then
		-- 1. Extract the encoded trashinfo file path
		local info_encoded = string.match(url_str, "([^/@,]+%.trashinfo)")
		if info_encoded then
			-- URL decode trashinfo path
			local info_path = url_decode(info_encoded)

			-- Extract exact trashed item stem
			local trash_stem = string.match(info_path, "([^/]+)%.trashinfo$")
			if trash_stem then
				-- Derive files directory from info path (parent/parent/files) to support external drive Trash
				local trash_dir = string.match(info_path, "^(.*)/info/[^/]+%.trashinfo$")
				local files_base = trash_dir and (trash_dir .. "/files") or ""

				if files_base == "" then
					files_base = get_default_trash_files_dir()
				end

				local target = files_base .. "/" .. trash_stem

				-- 2. Extract subfolder relative path after ,// (handles any depth N)
				local sub_rel = string.match(url_str, ",//+(.*)") or ""
				if sub_rel ~= "" then
					local decoded_sub = url_decode(sub_rel)

					local sub_parts = {}
					for p in string.gmatch(decoded_sub, "[^/]+") do
						if p ~= "." and p ~= ".." then
							table.insert(sub_parts, p)
						end
					end

					-- Skip root component if it matches the trash item stem or collision prefix (.2, -1)
					local start_idx = 1
					if #sub_parts > 0 then
						local p1 = sub_parts[1]
						local escaped_p1 = string.gsub(p1, "(%W)", "%%%1")
						if p1 == trash_stem or string.find(trash_stem, "^" .. escaped_p1 .. "[%.%-]") then
							start_idx = 2
						end
					end

					if start_idx <= #sub_parts then
						local rel_path = table.concat(sub_parts, "/", start_idx, #sub_parts)
						if rel_path ~= "" then
							target = target .. "/" .. rel_path
						end
					end
				end

				return target
			end
		end

		-- Fallback to default Trash files directory
		return get_default_trash_files_dir()
	end

	-- Strip file:// scheme if present
	return (string.gsub(url_str, "^file://", ""))
end

-- Pure Function: Construct command-line arguments array for eza CLI
local function build_eza_args(target_path, raw_url, opts)
	opts = opts or {}
	local is_trash = string.match(raw_url or "", "^trash:") ~= nil

	local args = {
		"--color=always",
		"--group-directories-first",
		"--no-quotes",
		target_path or "",
	}

	if opts.is_tree then
		table.insert(args, "--tree")
		table.insert(args, string.format("--level=%d", opts.level or 3))
	end
	if opts.icons then
		table.insert(args, "--icons=always")
	end
	if opts.follow_symlinks and not is_trash then
		table.insert(args, "--follow-symlinks")
	end
	if opts.all then
		table.insert(args, "--all")
	end
	if opts.dereference then
		table.insert(args, "--dereference")
	end
	if opts.git_status then
		table.insert(args, "--long")
		table.insert(args, "--no-permissions")
		table.insert(args, "--no-user")
		table.insert(args, "--no-time")
		table.insert(args, "--no-filesize")
		table.insert(args, "--git")
		table.insert(args, "--git-repos")
	end
	if opts.git_ignore and not is_trash then
		table.insert(args, "--git-ignore")
	end
	if opts.ignore_glob and opts.ignore_glob ~= "" then
		table.insert(args, "-I")
		table.insert(args, opts.ignore_glob)
	end

	return args
end

-- Batch getter - returns multiple simple values
local get_all_opts = ya
	and ya.sync(function(st)
		return st.tree ~= false,
			st.level or 3,
			st.follow_symlinks ~= false,
			st.dereference == true,
			st.all ~= false,
			st.git_ignore ~= false,
			st.git_status == true,
			st.icons ~= false,
			st.ignore_glob or ""
	end)

-- Individual getters
local get_tree = ya and ya.sync(function(st)
	return st.tree ~= false
end)
local get_level = ya and ya.sync(function(st)
	return st.level or 3
end)
local get_follow_symlinks = ya and ya.sync(function(st)
	return st.follow_symlinks ~= false
end)
local get_all = ya and ya.sync(function(st)
	return st.all ~= false
end)
local get_git_ignore = ya and ya.sync(function(st)
	return st.git_ignore ~= false
end)
local get_git_status = ya and ya.sync(function(st)
	return st.git_status == true
end)

-- Helper: Create sync state setter with peek refresh event
local function create_option_setter(key)
	return ya and ya.sync(function(st, val)
		st[key] = val
		local h = cx.active.current.hovered
		if h then
			ya.emit("peek", { 0, only_if = h.url, force = true })
		end
	end)
end

-- Sync setters
local set_tree = create_option_setter("tree")
local set_level = create_option_setter("level")
local set_follow_symlinks = create_option_setter("follow_symlinks")
local set_all = create_option_setter("all")
local set_git_ignore = create_option_setter("git_ignore")
local set_git_status = create_option_setter("git_status")

-- Setup from user config
local apply_config = ya
	and ya.sync(function(st, cfg)
		cfg = cfg or {}
		if cfg.default_tree ~= nil then
			st.tree = cfg.default_tree
		end
		if cfg.level ~= nil then
			st.level = cfg.level
		end
		if cfg.follow_symlinks ~= nil then
			st.follow_symlinks = cfg.follow_symlinks
		end
		if cfg.dereference ~= nil then
			st.dereference = cfg.dereference
		end
		if cfg.all ~= nil then
			st.all = cfg.all
		end
		if cfg.git_ignore ~= nil then
			st.git_ignore = cfg.git_ignore
		end
		if cfg.git_status ~= nil then
			st.git_status = cfg.git_status
		end
		if cfg.icons ~= nil then
			st.icons = cfg.icons
		end
		if cfg.ignore_glob ~= nil then
			if type(cfg.ignore_glob) == "table" then
				st.ignore_glob = table.concat(cfg.ignore_glob, "|")
			else
				st.ignore_glob = cfg.ignore_glob
			end
		end
	end)

function M:setup(cfg)
	if apply_config then
		apply_config(cfg)
	end
end

function M:entry(job)
	local args = string.gsub(job.args[1] or "", "^%s*(.-)%s*$", "%1")
	if args == "inc-level" then
		set_level(get_level() + 1)
	elseif args == "dec-level" then
		local lvl = get_level()
		if lvl > 1 then
			set_level(lvl - 1)
		end
	elseif args == "toggle-follow-symlinks" then
		set_follow_symlinks(not get_follow_symlinks())
	elseif args == "toggle-hidden" then
		set_all(not get_all())
	elseif args == "toggle-git-ignore" then
		set_git_ignore(not get_git_ignore())
	elseif args == "toggle-git-status" then
		set_git_status(not get_git_status())
	else
		set_tree(not get_tree())
	end
end

function M:peek(job)
	local is_tree, level, follow_symlinks, dereference, all, git_ignore, git_status, icons, ignore_glob = get_all_opts()

	local raw_url = tostring(job.file.url)
	local target_path = resolve_url(raw_url)

	local opts = {
		is_tree = is_tree,
		level = level,
		follow_symlinks = follow_symlinks,
		dereference = dereference,
		all = all,
		git_ignore = git_ignore,
		git_status = git_status,
		icons = icons,
		ignore_glob = ignore_glob,
	}

	local args = build_eza_args(target_path, raw_url, opts)

	local child, err = Command("eza"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		return ya.preview_widget(job, ui.Text("eza: " .. (err or "spawn failed")):area(job.area))
	end

	local limit = job.area.h
	local lines = ""
	local line_count = 0
	local skipped = 0
	local stderr_lines = ""

	repeat
		local line, event = child:read_line()
		if event == 1 then
			stderr_lines = stderr_lines .. line
		elseif event ~= 0 then
			break
		elseif skipped < job.skip then
			skipped = skipped + 1
		else
			lines = lines .. line
			line_count = line_count + 1
		end
	until line_count >= limit

	child:start_kill()

	if lines ~= "" and stderr_lines == "" then
		ya.preview_widget(job, {
			ui.Text.parse(lines):area(job.area),
		})
	elseif job.skip > 0 and line_count < limit then
		ya.emit("peek", {
			math.max(0, job.skip - (limit - line_count)),
			only_if = job.file.url,
			upper_bound = true,
		})
	else
		ya.preview_widget(job, {
			ui.Text({ ui.Line(stderr_lines ~= "" and ("eza: " .. stderr_lines) or "No items") })
				:area(job.area)
				:align(ui.Align.CENTER),
		})
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = job.file.url,
			force = true,
		})
	end
end

-- Embedded Zero-Dependency Test Suite (run via: lua main.lua --test)
if arg and arg[1] == "--test" then
	print("=== Running eza-preview Embedded TDD Test Suite ===")
	local passed, failed = 0, 0

	local function assert_eq(test_name, actual, expected)
		if actual == expected then
			passed = passed + 1
			print(string.format("  ✔ PASS: %s", test_name))
		else
			failed = failed + 1
			print(
				string.format(
					"  ✘ FAIL: %s\n     Expected: %s\n     Actual:   %s",
					test_name,
					tostring(expected),
					tostring(actual)
				)
			)
		end
	end

	-- Test resolve_url
	assert_eq("POSIX file:// URL", resolve_url("file:///home/user/code"), "/home/user/code")
	assert_eq("Plain POSIX Path", resolve_url("/var/log"), "/var/log")
	assert_eq("Trash Root", resolve_url("trash:///@//"), (os.getenv("HOME") or "") .. "/.local/share/Trash/files")
	assert_eq(
		"Trash Top Item",
		resolve_url("trash://%2Fhome%2Fuser%2F.local%2Fshare%2FTrash%2Finfo%2Fdocs.trashinfo/@//docs"),
		"/home/user/.local/share/Trash/files/docs"
	)
	assert_eq(
		"Trash Timestamp Collision Item",
		resolve_url("trash://%2Fhome%2Fuser%2F.local%2Fshare%2FTrash%2Finfo%2Fdata-12345.trashinfo/@//data"),
		"/home/user/.local/share/Trash/files/data-12345"
	)
	assert_eq(
		"Trash Subfolder Level 2 (Image 2 URL)",
		resolve_url("trash://Media/@%2Fhome%2Fuser%2F.local%2Fshare%2FTrash%2Finfo%2FWhatsApp.trashinfo,//WhatsApp/Media"),
		"/home/user/.local/share/Trash/files/WhatsApp/Media"
	)
	assert_eq(
		"Trash Subfolder Level 3 (Screenshot 2 exact URL)",
		resolve_url(
			"trash://WhatsApp Profile Photos/@%2Fhome%2Fuser%2F.local%2Fshare%2FTrash%2Finfo%2FWhatsApp.trashinfo,//WhatsApp/Media/WhatsApp Profile Photos"
		),
		"/home/user/.local/share/Trash/files/WhatsApp/Media/WhatsApp Profile Photos"
	)
	assert_eq(
		"Trash Dot Collision Subfolder (AppData.2/Local)",
		resolve_url(
			"trash://Local/@%2Fhome%2Fuser%2F.local%2Fshare%2FTrash%2Finfo%2FAppData.2.trashinfo,//AppData/Local"
		),
		"/home/user/.local/share/Trash/files/AppData.2/Local"
	)

	-- Test build_eza_args
	local args =
		build_eza_args("/tmp", "trash:///@//", { is_tree = true, level = 2, git_ignore = true, follow_symlinks = true })
	local args_str = table.concat(args, " ")
	assert_eq("Trash flags disable git-ignore", string.find(args_str, "--git-ignore") == nil, true)
	assert_eq("Trash flags disable follow-symlinks", string.find(args_str, "--follow-symlinks") == nil, true)
	assert_eq("Tree flag included", string.find(args_str, "--tree") ~= nil, true)

	print(string.format("\n=== Test Results: %d Passed, %d Failed ===", passed, failed))
	os.exit(failed > 0 and 1 or 0)
end

return M
