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

local pkgs = allPackages()
local pkg2deps = allDeps(pkgs)

for pkg, deps in pairs(pkg2deps) do
    for _, dep in ipairs(deps) do
        print(pkg, dep)
    end
end
