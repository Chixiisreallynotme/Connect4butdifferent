-- Minimal JSON encoder/decoder (pure Lua)
-- Handles strings, numbers, booleans, nil/null, arrays, objects

local json = {}

json.null = {}

----------------------------------------------------------------
-- ENCODE
----------------------------------------------------------------
local encode_value

local function encode_string(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function encode_table(t)
    local n = #t
    local isArray = (n > 0)
    if isArray then
        local count = 0
        for _ in pairs(t) do count = count + 1 end
        if count ~= n then isArray = false end
    end
    if isArray then
        local parts = {}
        for i = 1, n do
            parts[i] = encode_value(t[i])
        end
        return '[' .. table.concat(parts, ',') .. ']'
    else
        local parts = {}
        for k, v in pairs(t) do
            if type(k) == 'string' then
                parts[#parts + 1] = encode_string(k) .. ':' .. encode_value(v)
            end
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
end

encode_value = function(v)
    local t = type(v)
    if v == nil or v == json.null then return 'null'
    elseif t == 'string' then return encode_string(v)
    elseif t == 'number' then
        if v ~= v then return 'null' end
        if v == math.huge or v == -math.huge then return 'null' end
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return string.format('%d', v)
        end
        return tostring(v)
    elseif t == 'boolean' then return tostring(v)
    elseif t == 'table' then return encode_table(v)
    else return 'null'
    end
end

function json.encode(v)
    return encode_value(v)
end

----------------------------------------------------------------
-- DECODE
----------------------------------------------------------------
local decode_value

local function skip_ws(s, pos)
    while pos <= #s do
        local b = s:byte(pos)
        if b == 32 or b == 9 or b == 10 or b == 13 then
            pos = pos + 1
        else break end
    end
    return pos
end

local function decode_string(s, pos)
    pos = pos + 1 -- skip "
    local parts = {}
    while pos <= #s do
        local c = s:sub(pos, pos)
        if c == '"' then
            return table.concat(parts), pos + 1
        elseif c == '\\' then
            pos = pos + 1
            c = s:sub(pos, pos)
            if c == '"' then parts[#parts+1] = '"'
            elseif c == '\\' then parts[#parts+1] = '\\'
            elseif c == '/' then parts[#parts+1] = '/'
            elseif c == 'n' then parts[#parts+1] = '\n'
            elseif c == 'r' then parts[#parts+1] = '\r'
            elseif c == 't' then parts[#parts+1] = '\t'
            elseif c == 'u' then
                local hex = s:sub(pos+1, pos+4)
                local code = tonumber(hex, 16)
                if code and code < 128 then
                    parts[#parts+1] = string.char(code)
                else
                    parts[#parts+1] = '?'
                end
                pos = pos + 4
            end
        else
            parts[#parts+1] = c
        end
        pos = pos + 1
    end
    error('JSON: unterminated string')
end

local function decode_number(s, pos)
    local start = pos
    if s:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #s and s:byte(pos) >= 48 and s:byte(pos) <= 57 do pos = pos + 1 end
    if pos <= #s and s:sub(pos, pos) == '.' then
        pos = pos + 1
        while pos <= #s and s:byte(pos) >= 48 and s:byte(pos) <= 57 do pos = pos + 1 end
    end
    if pos <= #s and (s:sub(pos, pos) == 'e' or s:sub(pos, pos) == 'E') then
        pos = pos + 1
        if pos <= #s and (s:sub(pos, pos) == '+' or s:sub(pos, pos) == '-') then pos = pos + 1 end
        while pos <= #s and s:byte(pos) >= 48 and s:byte(pos) <= 57 do pos = pos + 1 end
    end
    return tonumber(s:sub(start, pos - 1)), pos
end

local function decode_array(s, pos)
    pos = skip_ws(s, pos + 1)
    local arr = {}
    if s:sub(pos, pos) == ']' then return arr, pos + 1 end
    while true do
        local val
        val, pos = decode_value(s, pos)
        arr[#arr + 1] = val
        pos = skip_ws(s, pos)
        local c = s:sub(pos, pos)
        if c == ']' then return arr, pos + 1 end
        if c ~= ',' then error('JSON: expected "," in array at pos ' .. pos) end
        pos = skip_ws(s, pos + 1)
    end
end

local function decode_object(s, pos)
    pos = skip_ws(s, pos + 1)
    local obj = {}
    if s:sub(pos, pos) == '}' then return obj, pos + 1 end
    while true do
        pos = skip_ws(s, pos)
        local key
        key, pos = decode_string(s, pos)
        pos = skip_ws(s, pos)
        if s:sub(pos, pos) ~= ':' then error('JSON: expected ":" at pos ' .. pos) end
        pos = skip_ws(s, pos + 1)
        local val
        val, pos = decode_value(s, pos)
        obj[key] = val
        pos = skip_ws(s, pos)
        local c = s:sub(pos, pos)
        if c == '}' then return obj, pos + 1 end
        if c ~= ',' then error('JSON: expected "," in object at pos ' .. pos) end
        pos = pos + 1
    end
end

decode_value = function(s, pos)
    pos = skip_ws(s, pos)
    local c = s:sub(pos, pos)
    if c == '"' then return decode_string(s, pos)
    elseif c == '{' then return decode_object(s, pos)
    elseif c == '[' then return decode_array(s, pos)
    elseif c == 't' then return true, pos + 4
    elseif c == 'f' then return false, pos + 5
    elseif c == 'n' then return nil, pos + 4
    else return decode_number(s, pos)
    end
end

function json.decode(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local val = decode_value(s, 1)
    return val
end

return json
