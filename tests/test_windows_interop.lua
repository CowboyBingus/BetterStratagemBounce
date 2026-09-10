local source, peer_source, order = assert(arg[1]), assert(arg[2]), assert(arg[3])
local ffi = require('ffi')
local factories = {
    ball = assert(loadfile(source .. '/windows_api.lua'))(),
    hellpod = assert(loadfile(peer_source .. '/windows_api.lua'))(),
}
local first, second = order:match('^(%a+)%-(%a+)$')
assert(factories[first] and factories[second] and first ~= second)
local apis = {[first] = factories[first]()}
apis[second] = factories[second]()
ffi.cdef [[
    void *VirtualAlloc(void *address, size_t size, uint32_t allocation, uint32_t protection);
    int VirtualFree(void *address, size_t size, uint32_t operation);
    int VirtualProtect(void *address, size_t size, uint32_t protection, uint32_t *previous);
]]
local kernel = ffi.load('kernel32')
local allocation = kernel.VirtualAlloc(nil, 8192, 0x3000, 4)
assert(allocation ~= nil)
local data = ffi.cast('uint8_t *', allocation)
local function verify()
    for _, name in ipairs({first, second}) do
        local api = apis[name]
        assert(api.writable_data(data, 8192), name .. ' rejected writable private data')
        assert(api.write(data + 4095, '\x12\x34'))
        assert(api.read(data + 4095, 2) == '\x12\x34')
        assert(not api.write(api.module(nil), '\0'))
    end
end
verify()
-- Repeated initialization must preserve the shared Windows declarations.
apis.ball = factories.ball()
verify()
local previous = ffi.new('uint32_t[1]')
for _, protection in ipairs({2, 0x20, 0x40}) do
    assert(kernel.VirtualProtect(data + 4096, 4096, protection, previous) ~= 0)
    for _, name in ipairs({first, second}) do
        local api = apis[name]
        assert(not api.writable_data(data, 8192))
        assert(not api.write(data + 4095, '\x56\x78'))
        assert(api.read(data + 4095, 2) == '\x12\x34')
    end
end
assert(kernel.VirtualFree(data, 0, 0x8000) ~= 0)
for _, name in ipairs({first, second}) do
    assert(not apis[name].writable_data(data, 1))
    assert(not apis[name].write(data, '\0'))
end
print('PASS: real Windows adapters share one Lua VM in ' .. order .. ' order; repeated ball initialization and write guards survive')
if arg[4] then
    arg = {source, arg[4], assert(arg[5])}
    assert(loadfile(source .. '/../tests/test_archive.lua'))()
end
