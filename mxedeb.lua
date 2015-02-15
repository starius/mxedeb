local target = os.getenv('MXE_TARGETS') or 'i686-pc-mingw32'
local mxever = os.getenv('MXE_VERSION') or '2.23'

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

-- return several table describing packages
-- * list of packages
-- * map from package to list of deps
-- * map from package to version of package
local function getPkgs()
    -- create file deps.mk showing deps
    -- (make show-upstream-deps-% does not present in
    -- stable MXE)
    local deps_mk_content = [[
include Makefile
NOTHING:=
SPACE:=$(NOTHING) $(NOTHING)
NAME_WITH_UNDERSCORES:=$(subst $(SPACE),_,$(NAME))
print-deps:
	@$(foreach pkg,$(PKGS),echo \
		$(pkg) \
		$(subst $(SPACE),-,$($(pkg)_VERSION)) \
		$($(pkg)_DEPS);)]]
    local deps_mk_file = io.open('deps.mk', 'w')
    deps_mk_file:write(deps_mk_content)
    deps_mk_file:close()
    local pkgs = {}
    local pkg2deps = {}
    local pkg2ver = {}
    local cmd = 'make -f deps.mk print-deps'
    local make = io.popen(cmd)
    for line in make:lines() do
        local deps = split(trim(line))
        -- first value is name of package which depends on
        local pkg = table.remove(deps, 1)
        -- second value is version of package
        local ver = table.remove(deps, 1)
        table.insert(pkgs, pkg)
        pkg2deps[pkg] = deps
        pkg2ver[pkg] = ver
    end
    make:close()
    os.remove('deps.mk')
    return pkgs, pkg2deps, pkg2ver
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

local function nameToDebian(pkg)
    pkg = pkg:gsub('_', '-')
    return ('mxe%s-%s-%s'):format(mxever, target, pkg)
end

local function protectVersion(ver)
    ver = ver:gsub('_', '-')
    if ver:sub(1, 1):match('%d') then
        return ver
    else
        -- version number does not start with digit
        return '0.' .. ver
    end
end

local CONTROL = [[Package: %s
Version: %s
Section: devel
Priority: optional
Architecture: all%s
Maintainer: Boris Nagaev <bnagaev@gmail.com>
Homepage: http://mxe.cc
Description: MXE %s package %s for %s
 MXE (M cross environment) is a Makefile that compiles
 a cross compiler and cross compiles many free libraries
 such as SDL and Qt for various target platforms (MinGW).
 .
 This package contains the files for MXE package %s.
]]

local function makeDeb(pkg, list_path, deps, ver)
    local deb_pkg = nameToDebian(pkg)
    local dirname = ('%s_%s'):format(deb_pkg,
        protectVersion(ver))
    local usr = ('%s/usr/lib/mxe/%s'):format(dirname, mxever)
    os.execute(('mkdir -p %s'):format(usr))
    -- use tar to copy files with paths
    local cmd = 'tar -T %s --owner=0 --group=0 -cf - | ' ..
        'fakeroot -s deb.fakeroot tar -C %s -xf -'
    os.execute(cmd:format(list_path, usr))
    -- prepare dependencies
    local deb_deps = {}
    for _, dep in ipairs(deps) do
        table.insert(deb_deps, nameToDebian(dep))
    end
    local deb_deps_str = ''
    if #deb_deps > 0 then
        local str = table.concat(deb_deps, ', ')
        deb_deps_str = '\nDepends: ' .. str
    end
    -- make DEBIAN/control file
    os.execute(('mkdir -p %s/DEBIAN'):format(dirname))
    local control_fname = dirname .. '/DEBIAN/control'
    local control = io.open(control_fname, 'w')
    control:write(CONTROL:format(deb_pkg, protectVersion(ver),
        deb_deps_str, mxever, pkg, target, pkg))
    control:close()
    -- make .deb file
    local cmd = 'fakeroot -i deb.fakeroot dpkg-deb -b %s'
    os.execute(cmd:format(dirname))
    -- cleanup
    os.execute(('rm -fr %s deb.fakeroot'):format(dirname))
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

local function makeDebs(pkgs, pkg2deps, pkg2ver)
    for _, pkg in ipairs(pkgs) do
        local deps = assert(pkg2deps[pkg], pkg)
        local ver = assert(pkg2ver[pkg], pkg)
        makeDeb(pkg, pkg .. '.list', deps, ver)
    end
end

local pkgs, pkg2deps, pkg2ver = getPkgs()
local build_list = sortForBuild(pkgs, pkg2deps)
os.execute('make clean')
buildPackages(build_list)
makeDebs(build_list, pkg2deps, pkg2ver)
