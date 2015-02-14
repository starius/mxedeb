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

local function allPackages()
    local pkgs = {}
    local ls = io.popen('ls src/*.mk', 'r')
    for line in ls:lines() do
        local pkg = line:match("src/(.+).mk")
        table.insert(pkgs, pkg)
    end
    ls:close()
    return pkgs
end

-- return table which maps name of package to list of deps
local function allDeps(pkgs)
    -- create file deps.mk showing deps
    -- (make show-upstream-deps-% does not present in
    -- stable MXE)
    local deps_mk_content = [[
include Makefile
print-%-deps:
	@echo $($*_DEPS)]]
    local deps_mk_file = io.open('deps.mk', 'w')
    deps_mk_file:write(deps_mk_content)
    deps_mk_file:close()
    local pkg2deps = {}
    for _, pkg in ipairs(pkgs) do
        local cmd = 'make -f deps.mk print-%s-deps'
        local make = io.popen(cmd:format(pkg))
        local deps_str = make:read('*a')
        make:close()
        local deps = split(trim(deps_str))
        pkg2deps[pkg] = deps
    end
    os.remove('deps.mk')
    return pkg2deps
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

local pkgs = allPackages()
local pkg2deps = allDeps(pkgs)
local graph = dependencyGraph(pkgs, pkg2deps)

for pkg1, deps in pairs(graph) do
    for pkg2, _ in pairs(deps) do
        print(pkg1, pkg2)
    end
end
