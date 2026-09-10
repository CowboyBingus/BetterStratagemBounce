local directory, compiled, executable_hash = assert(arg[1]), assert(arg[2]), assert(arg[3])
local create_api = assert(loadfile(directory .. '/windows_api.lua'))()
local patch = assert(loadfile(directory .. '/navigation_patch.lua'))()
local ffi = require('ffi')
ffi.cdef [[
    void *VirtualAlloc(void *address, size_t size, uint32_t allocation, uint32_t protection);
    int VirtualFree(void *address, size_t size, uint32_t operation);
    int VirtualProtect(void *address, size_t size, uint32_t protection, uint32_t *previous);
]]
local kernel, api = ffi.load('kernel32'), create_api()
local cases = 0
local function pass(name) cases = cases + 1; print('PASS: ' .. name) end
local function allocate(size)
    local result = kernel.VirtualAlloc(nil, size, 0x3000, 4)
    assert(result ~= nil)
    return ffi.cast('uint8_t *', result)
end
local function protect(address, size, protection)
    assert(kernel.VirtualProtect(address, size, protection, ffi.new('uint32_t[1]')) ~= 0)
end
local function integer(address, value) ffi.cast('uint32_t *', address)[0] = value end
local function pointer(address, value) ffi.cast('uintptr_t *', address)[0] = ffi.cast('uintptr_t', value) end

assert(api.module_hash(api.module(nil)) == executable_hash)
assert(api.read(ffi.cast('void *', 1), 14) == nil)
pass('native SHA256 matches independent hash; invalid memory reads are contained')

local code = allocate(4096)
ffi.copy(code, '\x41\xF6\x87\x70\1\0\0\2\x0F\x84\x88\0\0\0', 14)
local code_before = api.read(code, 4096)
for _, protection in ipairs({2, 0x20, 0x40}) do
    protect(code, 4096, protection)
    assert(not api.writable_data(code, 1) and not api.write(code, '\0'))
    assert(api.read(code, 4096) == code_before)
end
assert(not api.write(api.module(nil), '\0'))
assert(not api.writable_data(ffi.cast('void *', 1), 1))
pass('adapter refuses executable, read-only, image and unmapped write targets')

local module = allocate(patch.table_rva + 148 * 8)
local data = allocate(patch.data_size)
ffi.fill(data, patch.data_size, 0xA5)
pointer(module + patch.buffer_rva, data)
integer(data, 11)
local group_sizes = {7204,1184,5860,5228,19152,7040,3832,17840,4884,1104,5964}
local group_counts = {13,2,11,9,36,13,7,33,9,2,12}
local offset, record_count, locations = 4, 0, {}
for group, size in ipairs(group_sizes) do
    integer(data + offset, 0x444C444C)
    integer(data + offset + 4, 1)
    integer(data + offset + 8, 0x30EB6399)
    integer(data + offset + 12, size - 24)
    integer(data + offset + 16, 1)
    integer(data + offset + 20, 0)
    pointer(data + offset + 24, data + offset + 40)
    integer(data + offset + 32, group_counts[group])
    for index = 0, group_counts[group] - 1 do
        local record = offset + 40 + index * 400
        local kind = (record_count * 5) % 147 + 1
        record_count = record_count + 1
        integer(data + record, kind)
        pointer(module + patch.table_rva + kind * 8, data + record)
        data[record + patch.flag_offset] = patch.vanilla_flags[kind]
        locations[kind] = record
    end
    offset = offset + size
end
assert(offset == patch.data_size and record_count == 147 and #patch.vanilla_flags == 147)
local original = api.read(data, patch.data_size)
local module_table = api.read(module + patch.table_rva, 148 * 8)
assert(patch.apply(api, module))
local expected = original
local changed = 0
for kind, record in ipairs(locations) do
    local before = patch.vanilla_flags[kind]
    local after = bit.band(before, 0xFD)
    local position = record + patch.flag_offset
    assert(data[position] == after)
    expected = expected:sub(1, position) .. string.char(after) .. expected:sub(position + 2)
    if before ~= after then changed = changed + 1 end
end
assert(changed == 101 and api.read(data, patch.data_size) == expected)
assert(api.read(module + patch.table_rva, 148 * 8) == module_table)
assert(api.read(code, 4096) == code_before)
pass('101 navigation bits change across 147 shuffled records; every other data and code byte survives')

local function reset()
    protect(data, patch.data_size, 4)
    ffi.copy(data, original, #original)
    ffi.copy(module + patch.table_rva, module_table, #module_table)
    pointer(module + patch.buffer_rva, data)
end
local corruptions = {
    function() integer(data, 12) end,
    function() integer(data + 4, 0) end,
    function() integer(data + 16, patch.data_size * 2) end,
    function() pointer(data + 28, data + patch.data_size) end,
    function() integer(data + locations[2], 1) end,
    function() pointer(module + patch.table_rva + 8, data + locations[2]) end,
    function() data[locations[1] + patch.flag_offset] = 0 end,
    function() pointer(module + patch.buffer_rva, nil) end,
}
for _, corrupt in ipairs(corruptions) do
    reset(); corrupt()
    local before = api.read(data, patch.data_size)
    assert(not patch.apply(api, module))
    assert(api.read(data, patch.data_size) == before)
end
reset(); protect(data, patch.data_size, 2)
assert(not patch.apply(api, module))
assert(api.read(data, patch.data_size) == original)
reset()
pass('malformed groups, counts, pointers, identities, changed flags and read-only data fail before writes')

for _, failure in ipairs({'write', 'verify'}) do
    reset()
    local faulty = setmetatable({}, {__index = api})
    local writes = 0
    faulty.write = function(address, bytes)
        writes = writes + 1
        if failure == 'write' and writes == 50 then return false end
        return api.write(address, bytes)
    end
    local rejected = false
    faulty.read = function(address, size)
        if failure == 'verify' and writes == 101 and address == data and size == patch.data_size and not rejected then
            rejected = true; return nil
        end
        return api.read(address, size)
    end
    assert(not patch.apply(faulty, module))
    assert(api.read(data, patch.data_size) == original)
end
pass('partial-write and verification failures recover the original settings')
assert(kernel.VirtualFree(module, 0, 0x8000) ~= 0)
assert(kernel.VirtualFree(data, 0, 0x8000) ~= 0)
assert(kernel.VirtualFree(code, 0, 0x8000) ~= 0)

for _, mode in ipairs({'success', 'ffi', 'exe', 'game', 'missing', 'patch'}) do
    local updates, attempts, applied = 0, 0, 0
    local env = setmetatable({print = function() end, os = {getenv = function() end}}, {__index = _G})
    env._G = env
    env.update = function(dt, marker) assert(dt == 0.016 and marker == 123); updates = updates + 1 end
    local previous = env.update
    local loader = assert(loadfile(directory .. '/archive_loader.lua'))
    setfenv(loader, env)
    setfenv(loader(), env)(function()
        attempts = attempts + 1
        if mode == 'ffi' then error('No ffi') end
        return {
            module = function(name) if mode == 'missing' then return nil end; return name or 'exe' end,
            module_hash = function(name)
                if (mode == 'exe' and name == 'exe') or (mode == 'game' and name == 'game.dll') then return 'wrong' end
                return name
            end
        }
    end, {apply = function() applied = applied + 1; return mode ~= 'patch', 'test result' end},
    {revision = 'test', exe_sha256 = 'exe', game_sha256 = 'game.dll'})
    for _ = 1, 5 do env.update(0.016, 123) end
    assert(updates == 5 and attempts == 1 and env.update == previous)
    assert(applied == ((mode == 'success' or mode == 'patch') and 1 or 0))
    assert(env.BetterStratagemBounce.active == (mode == 'success'))
end
pass('loader preserves updates, verifies both modules, contains failures and removes its update hook')

local env = setmetatable({stingray = {Application = {build = function() return 'release' end}},
    require = function(name) assert(name == 'core/wwise/lua/wwise_flow_callbacks') end}, {__index = _G})
env._G = env
env.loadstring = function(bytes, name)
    local func, message = loadstring(bytes, name)
    if func then setfenv(func, env) end
    return func, message
end
setfenv(assert(loadfile(compiled)), env)()
assert(type(env.update) == 'function' and type(env.init) == 'function')
pass('compiled archive embeds and executes the unchanged vanilla boot bytecode')
print(cases .. ' runtime checks passed; no game process was accessed.')
