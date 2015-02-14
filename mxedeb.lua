-- based on http://lua-users.org/wiki/SplitJoin
local function split(self, sep, nMax, plain)
    if not sep then
        sep = '%s+'
    end
    assert(sep ~= '')
    assert(nMax == nil or nMax >= 1)
    local aRecord = {}
    if self:len() > 0 then
        nMax = nMax or -1
        local nField = 1
        local nStart = 1
        local nFirst, nLast = self:find(sep, nStart, plain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst - 1)
            nField = nField + 1
            nStart = nLast + 1
            nFirst, nLast = self:find(sep, nStart, plain)
            nMax = nMax - 1
        end
        aRecord[nField] = self:sub(nStart)
    end
    return aRecord
end

local function trim(str)
    local text = str:gsub("%s+$", "")
    text = text:gsub("^%s+", "")
    return text
end

-- return list of table and map from package to list of deps
local function pkgsAndDeps()
    -- create file deps.mk showing deps
    -- (make show-upstream-deps-% does not present in
    -- stable MXE)
    local deps_mk_content = [[
include Makefile
print-deps:
	@$(foreach pkg,$(PKGS),echo $(pkg) $($(pkg)_DEPS);)]]
    local deps_mk_file = io.open('deps.mk', 'w')
    deps_mk_file:write(deps_mk_content)
    deps_mk_file:close()
    local pkg2deps = {}
    local pkgs = {}
    local cmd = 'make -f deps.mk print-deps'
    local make = io.popen(cmd)
    for line in make:lines() do
        local deps = split(trim(line))
        -- first value is name of package which depends on
        local pkg = table.remove(deps, 1)
        pkg2deps[pkg] = deps
        table.insert(pkgs, pkg)
    end
    make:close()
    os.remove('deps.mk')
    return pkgs, pkg2deps
end

-- return packages ordered in build order
-- this means, if pkg1 depends on pkg2, then
-- pkg2 preceeds pkg1 in the list
local function sortForBuild(pkgs, pkg2deps)
    -- use sommand tsort
    local tsort_input_fname = os.tmpname()
    local tsort_input = io.open(tsort_input_fname, 'w')
    for _, pkg1 in ipairs(pkgs) do
        for _, pkg2 in ipairs(pkg2deps[pkg1]) do
            tsort_input:write(pkg2 .. ' ' .. pkg1 .. '\n')
        end
    end
    tsort_input:close()
    --
    local build_list = {}
    local tsort = io.popen('tsort ' .. tsort_input_fname, 'r')
    for line in tsort:lines() do
        local pkg = trim(line)
        table.insert(build_list, pkg)
    end
    tsort:close()
    os.remove(tsort_input_fname)
    return build_list
end

-- return set of all filepaths under ./usr/
local function findFiles()
    local files = {}
    local find = io.popen('find usr -type f', 'r')
    for line in find:lines() do
        local file = trim(line)
        files[file] = true
    end
    find:close()
    return files
end

-- builds package, returns list of new files
local function buildPackage(pkg)
    local files_before = findFiles()
    os.execute('make ' .. pkg)
    local files_after = findFiles()
    local new_files = {}
    for file in pairs(files_after) do
        if not files_before[file] then
            table.insert(new_files, file)
        end
    end
    assert(#new_files > 0)
    return new_files
end

local function saveFileList(pkg, list)
    local list_file = pkg .. '.list'
    local file = io.open(list_file, 'w')
    for _, installed_file in ipairs(list) do
        file:write(installed_file .. '\n')
    end
    file:close()
end

-- build all packages, save filelist to file #pkg.list
local function buildPackages(pkgs)
    for _, pkg in ipairs(pkgs) do
        local files = buildPackage(pkg)
        saveFileList(pkg, files)
    end
end

local pkgs, pkg2deps = pkgsAndDeps()
local build_list = sortForBuild(pkgs, pkg2deps)
os.execute('make clean')
buildPackages(build_list)
