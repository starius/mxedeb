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

-- return list of direct and indirect dependencies
local function recursiveDeps(pkg, pkg2deps)
    local deps = {}
    local direct_deps = assert(pkg2deps[pkg])
    for _, pkg1 in ipairs(direct_deps) do
        table.insert(deps, pkg1)
        for _, pkg2 in ipairs(recursiveDeps(pkg1, pkg2deps)) do
            table.insert(deps, pkg2)
        end
    end
    return deps
end

-- return two-dimensional table
-- local graph = recursiveDeps(pkgs, pkg2deps)
-- graph[pkg1][pkg2] -- if pkg2 is needed for pkg1
-- (e.g., if pkg1 depends on pkg2, which depends on pkg3,
-- then graph[pkg1][pkg3] is true)
local function dependencyGraph(pkgs, pkg2deps)
    local graph = {}
    for _, pkg in ipairs(pkgs) do
        graph[pkg] = {}
        for _, pkg1 in ipairs(recursiveDeps(pkg, pkg2deps)) do
            graph[pkg][pkg1] = true
        end
    end
    return graph
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

local pkgs, pkg2deps = pkgsAndDeps()
local graph = dependencyGraph(pkgs, pkg2deps)
local build_list = sortForBuild(pkgs, pkg2deps)

print("Dependency graph:")
for pkg1, deps in pairs(graph) do
    for pkg2, _ in pairs(deps) do
        print(pkg1, pkg2)
    end
end

print("Build list:")
for _, pkg in ipairs(build_list) do
    print(pkg)
end
