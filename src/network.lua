-- [NET] Network Module
-- Async HTTP REST client for Supabase via love.thread + curl
-- Never blocks the game loop — all I/O happens in a worker thread

local json = require("src.json")
local config = require("src.supabase_config")

local network = {}

-- Internal state
local thread
local requestChannel
local responseChannel
local callbacks = {}   -- requestId -> callback function
local nextId = 1
local initialized = false

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--- Initialize the network module (start worker thread)
function network.init()
    if initialized then return end
    requestChannel  = love.thread.getChannel("net_request")
    responseChannel = love.thread.getChannel("net_response")

    -- Clear any stale data from previous session
    requestChannel:clear()
    responseChannel:clear()

    thread = love.thread.newThread("src/net_thread.lua")
    thread:start()
    initialized = true
    print("[NET] Worker thread started")
end

--- Send an async HTTP request to Supabase
--- @param method string "GET", "POST", "PATCH", "DELETE"
--- @param path string REST path, e.g. "/rest/v1/games?code=eq.ABC123"
--- @param body table|nil Request body (will be JSON-encoded)
--- @param callback function(status, data, rawBody) Called when response arrives
--- @param extraHeaders table|nil Additional headers
function network.request(method, path, body, callback, extraHeaders)
    if not initialized then
        network.init()
    end

    local id = "req_" .. nextId
    nextId = nextId + 1

    -- Build full URL
    local url = config.url .. path

    -- Build headers
    local headers = {
        ["apikey"]        = config.anon_key,
        ["Authorization"] = "Bearer " .. config.anon_key,
        ["Content-Type"]  = "application/json",
        ["Prefer"]        = "return=representation",
    }
    if extraHeaders then
        for k, v in pairs(extraHeaders) do
            headers[k] = v
        end
    end

    -- Encode body
    local bodyStr = nil
    if body then
        bodyStr = json.encode(body)
    end

    -- Register callback
    if callback then
        callbacks[id] = callback
    end

    -- Push request to worker thread
    local request = json.encode({
        id      = id,
        method  = method,
        url     = url,
        body    = bodyStr,
        headers = headers,
    })

    requestChannel:push(request)
end

--- Poll for responses — call this every frame from love.update
function network.poll()
    if not initialized then return end

    -- Check for thread errors
    local err = thread:getError()
    if err then
        print("[NET] Thread error: " .. tostring(err))
        -- Restart thread
        initialized = false
        network.init()
        return
    end

    -- Process all available responses
    local maxPerFrame = 10
    for _ = 1, maxPerFrame do
        local rawResponse = responseChannel:pop()
        if not rawResponse then break end

        local ok, response = pcall(json.decode, rawResponse)
        if ok and response then
            local id = response.id
            local cb = callbacks[id]
            if cb then
                callbacks[id] = nil

                -- Parse the response body as JSON
                local bodyData = nil
                if response.body and response.body ~= "" then
                    local parseOk, parsed = pcall(json.decode, response.body)
                    if parseOk then
                        bodyData = parsed
                    end
                end

                -- Call the callback
                local callOk, callErr = pcall(cb, response.status, bodyData, response.body)
                if not callOk then
                    print("[NET] Callback error: " .. tostring(callErr))
                end
            end
        end
    end
end

--- Shutdown the network module
function network.shutdown()
    if not initialized then return end
    requestChannel:push("__SHUTDOWN__")
    -- Give thread a moment to exit
    if thread and thread:isRunning() then
        thread:wait()
    end
    callbacks = {}
    nextId = 1
    initialized = false
    print("[NET] Shutdown complete")
end

--- Check if network is initialized
function network.isReady()
    return initialized
end

--- Generate a unique player ID (ephemeral, per-session)
function network.generatePlayerId()
    local chars = "abcdef0123456789"
    local id = ""
    for i = 1, 8 do
        local idx = love.math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
        if i == 4 then id = id .. "-" end
    end
    -- Add timestamp component for extra uniqueness
    id = id .. "-" .. string.format("%x", os.time() % 0xFFFF)
    return id
end

--- Generate a 6-character game code
function network.generateGameCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no I,O,0,1
    local code = ""
    for _ = 1, 6 do
        local idx = love.math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    return code
end

return network
