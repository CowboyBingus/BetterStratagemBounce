local patch = {
    buffer_rva = 0x2791F68,
    table_rva = 0x2ACD110,
    data_size = 79296,
    groups = 11,
    record_size = 400,
    flag_offset = 0x170,
    vanilla_flags = {
        2, 2, 0, 0, 2, 2, 0, 2, 2, 0, 2, 2, 2, 2, 2, 2, 0, 2, 3, 0, 2,
        2, 2, 2, 2, 0, 0, 2, 0, 2, 2, 2, 0, 1, 2, 1, 0, 2, 1, 0, 2, 2,
        2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 0, 2, 2, 0,
        2, 2, 2, 3, 2, 0, 0, 2, 0, 2, 2, 2, 2, 2, 2, 2, 3, 0, 2, 3, 2,
        2, 0, 2, 3, 0, 2, 1, 0, 2, 2, 2, 1, 2, 2, 2, 0, 2, 2, 2, 0, 0,
        2, 3, 2, 0, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 0, 0, 0, 0, 2, 0,
        2, 2, 2, 0, 0, 2, 2, 0, 2, 0, 2, 0, 2, 2, 3, 2, 0, 0, 2, 0, 2
    }
}

local function u32(bytes, offset)
    assert(offset >= 0 and offset + 4 <= #bytes, 'Settings field out of bounds')
    local a, b, c, d = bytes:byte(offset + 1, offset + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end

local function replace_byte(bytes, offset, value)
    return bytes:sub(1, offset) .. string.char(value) .. bytes:sub(offset + 2)
end

local function prepare(api, module)
    assert(module, 'Game module unavailable')
    local pointer_bytes = api.read(module + patch.buffer_rva, 8)
    local buffer = assert(api.pointer(pointer_bytes), 'Settings buffer unavailable')
    assert(api.writable_data(buffer, patch.data_size), 'Settings are not writable private data')
    local source = assert(api.read(buffer, patch.data_size), 'Cannot read settings')
    local table_bytes = assert(api.read(module + patch.table_rva, 148 * 8), 'Cannot read settings table')
    assert(u32(source, 0) == patch.groups, 'Unexpected settings group count')
    local offset, records, seen, changes = 4, 0, {}, {}
    for _ = 1, patch.groups do
        assert(u32(source, offset) == 0x444C444C and u32(source, offset + 4) == 1
            and u32(source, offset + 8) == 0x30EB6399
            and u32(source, offset + 16) == 1 and u32(source, offset + 20) == 0, 'Unexpected settings header')
        local root = offset + 24
        local finish = root + u32(source, offset + 12)
        assert(finish >= root + 16 and finish <= #source, 'Settings group out of bounds')
        local count = u32(source, root + 8)
        assert(count > 0 and count <= #patch.vanilla_flags, 'Invalid record count')
        local items = assert(api.pointer(source, root), 'Settings items unavailable')
        local start = api.distance(items, buffer)
        assert(start >= root + 16 and start + count * patch.record_size <= finish, 'Settings records out of bounds')
        for index = 0, count - 1 do
            local record = start + index * patch.record_size
            local kind = u32(source, record)
            assert(patch.vanilla_flags[kind] and not seen[kind], 'Unexpected or duplicate stratagem')
            assert(api.pointer(table_bytes, kind * 8) == buffer + record, 'Settings table identity mismatch')
            local flags = source:byte(record + patch.flag_offset + 1)
            assert(flags == patch.vanilla_flags[kind], 'Stratagem navigation flags differ from supported build')
            seen[kind], records = true, records + 1
            if bit.band(flags, 2) ~= 0 then
                changes[#changes + 1] = {record = record, offset = record + patch.flag_offset,
                    before = flags, after = bit.band(flags, 0xFD)}
            end
        end
        offset = finish
    end
    assert(offset == #source and records == 147 and #changes == 101, 'Incomplete stratagem settings')
    table.sort(changes, function(a, b) return a.offset < b.offset end)
    return {buffer = buffer, source = source, pointer_bytes = pointer_bytes, changes = changes}
end

function patch.apply(api, module)
    local valid, plan = pcall(prepare, api, module)
    if not valid then return false, tostring(plan) end
    local expected, applied = plan.source, {}
    local ok, reason = pcall(function()
        assert(api.read(module + patch.buffer_rva, 8) == plan.pointer_bytes, 'Settings buffer changed')
        assert(api.read(plan.buffer, patch.data_size) == plan.source, 'Settings changed during validation')
        for _, change in ipairs(plan.changes) do
            applied[#applied + 1] = change
            assert(api.write(plan.buffer + change.offset, string.char(change.after)), 'Settings write failed')
            expected = replace_byte(expected, change.offset, change.after)
        end
        assert(api.read(plan.buffer, patch.data_size) == expected, 'Settings verification failed')
    end)
    if ok then return true, 'navigation_settings_ready: 101 flags; executable code unchanged' end
    local restored = api.read(module + patch.buffer_rva, 8) == plan.pointer_bytes
    if restored then
        for index = #applied, 1, -1 do
            local change = applied[index]
            local before = plan.source:sub(change.record + 1, change.record + patch.record_size)
            local after = replace_byte(before, patch.flag_offset, change.after)
            local current = api.read(plan.buffer + change.record, patch.record_size)
            -- Restore only records that still match our edit; never overwrite another owner's change.
            if current == after then
                restored = api.write(plan.buffer + change.offset, string.char(change.before)) and restored
            elseif current ~= before then
                restored = false
            end
        end
    end
    return false, tostring(reason) .. '; partial-edit recovery=' .. tostring(restored)
end

return patch
