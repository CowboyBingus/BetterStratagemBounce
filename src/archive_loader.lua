return function(create_api, patch, build)
    local original_update = update
    local attempted = false
    local callback
    local function report(message)
        print('[BetterStratagemBounce] ' .. build.revision .. ': ' .. message)
        pcall(function()
            local directory = os.getenv('LOCALAPPDATA')
            if not directory then return end
            local file = io.open(directory .. '/BetterStratagemBounce.log', 'w')
            if file then file:write(build.revision .. '\n' .. message .. '\n'); file:close() end
        end)
    end
    callback = function(dt, ...)
        if original_update then original_update(dt, ...) end
        if attempted then return end
        attempted = true
        local ok, result = pcall(function()
            local api = create_api()
            local exe, game = api.module(nil), api.module('game.dll')
            assert(exe and game, 'Required game modules unavailable')
            assert(api.module_hash(exe) == build.exe_sha256, 'Unsupported executable; no change applied')
            assert(api.module_hash(game) == build.game_sha256, 'Unsupported game module; no change applied')
            local applied, reason = patch.apply(api, game)
            assert(applied, reason)
            return reason
        end)
        _G.BetterStratagemBounce = {revision = build.revision, active = ok, status = tostring(result)}
        report(tostring(result))
        -- No continuing update or shutdown hook is needed once the instruction is patched.
        if update == callback then update = original_update or function() end end
    end
    update = callback
end
