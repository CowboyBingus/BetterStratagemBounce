local bounce, hellpod, fixture = arg[1], arg[2], arg[3]
local resource_files = {
    ['boot'] = fixture .. '/f476df93691895fa.lua.main',
    ['mods/hd2_hud/frag_gauge'] = fixture .. '/8695397a5ee5b670.lua.main',
    ['mods/hd2_hud/frag_numbers'] = fixture .. '/d8c251eabb67f38b.lua.main',
    ['mods/hd2_hud/frag_icon'] = fixture .. '/b02f08943274cb87.lua.main',
    ['mods/hd2_hud/frag_idle'] = fixture .. '/c622e294f0394777.lua.main',
    ['core/wwise/lua/wwise_flow_callbacks'] = bounce .. '/callbacks.lua.main',
    ['mods/cowboybingus/better_stratagem_bounce'] = bounce .. '/mod.lua.main',
    ['mods/cowboybingus/hellpod_steering_unlocked'] = hellpod .. '/mod.lua.main',
}
for mask = 0, 3 do
    local env = {}
    for key, value in pairs(_G) do env[key] = value end
    env._G = env
    env.print = function() end
    env.os = {getenv = function() end, clock = os.clock}
    env.io = {open = function() return nil end}
    env.stingray = {Application = {build = function() return 'release' end}}
    local installed = {
        ['mods/cowboybingus/better_stratagem_bounce'] = mask % 2 == 1,
        ['mods/cowboybingus/hellpod_steering_unlocked'] = mask >= 2,
    }
    env.stingray.Application.can_get = function(kind, name)
        assert(kind == 'lua' and installed[name] ~= nil)
        return installed[name]
    end
    env.loadstring = function(bytes, name)
        local chunk, reason = loadstring(bytes, name)
        if chunk then setfenv(chunk, env) end
        return chunk, reason
    end
    local required, loaded = {}, {}
    env.require = function(name)
        if loaded[name] then return loaded[name] end
        if name == 'ffi' then return require('ffi') end
        if name == 'core/wwise/lua/wwise_visualization' or name == 'core/wwise/lua/wwise_bank_reference' then return {} end
        local file = assert(io.open(assert(resource_files[name], name), 'rb'))
        local bytes = file:read('*a'); file:close()
        required[name] = (required[name] or 0) + 1
        loaded[name] = assert(env.loadstring(bytes:sub(9), '@' .. name))() or true
        return loaded[name]
    end
    local result = env.require('boot')
    assert(result.installed == true, 'HUD+ failed to install its actual update callback')
    local hud = env.update
    local calls = 0
    env.update = function(...)
        calls = calls + 1
        return hud(...)
    end
    local shutdown = env.shutdown
    env.init()
    for _ = 1, 3 do env.update(0.1) end
    assert(calls == 3 and env.shutdown == shutdown)
    for name, present in pairs(installed) do
        assert((required[name] or 0) == (present and 1 or 0))
    end
    assert((rawget(env, 'BetterStratagemBounce') ~= nil) == installed['mods/cowboybingus/better_stratagem_bounce'])
    assert((rawget(env, 'HellpodSteeringUnlocked') ~= nil) == installed['mods/cowboybingus/hellpod_steering_unlocked'])
end
print('PASS: unmodified HUD+ boot and fragments install, load each shared-loader combination and retain the HUD update chain')
