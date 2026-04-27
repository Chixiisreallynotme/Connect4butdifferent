-- [NET] Worker thread for async HTTP requests via curl.exe
-- Runs in a separate LÖVE thread, communicates via Channels
-- Never require game modules here — only standard libs + json

local requestChannel  = love.thread.getChannel("net_request")
local responseChannel = love.thread.getChannel("net_response")

-- Load JSON module via love.filesystem (safe in thread context)
local jsonCode = love.filesystem.read("src/json.lua")
local json = assert(loadstring(jsonCode))()

local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        uint32_t cb; char* lpReserved; char* lpDesktop; char* lpTitle;
        uint32_t dwX; uint32_t dwY; uint32_t dwXSize; uint32_t dwYSize;
        uint32_t dwXCountChars; uint32_t dwYCountChars; uint32_t dwFillAttribute;
        uint32_t dwFlags; uint16_t wShowWindow; uint16_t cbReserved2;
        uint8_t* lpReserved2; void* hStdInput; void* hStdOutput; void* hStdError;
    } STARTUPINFOA;

    typedef struct {
        void* hProcess; void* hThread; uint32_t dwProcessId; uint32_t dwThreadId;
    } PROCESS_INFORMATION;

    int CreateProcessA(
        const char* lpApplicationName, char* lpCommandLine, void* lpProcessAttributes,
        void* lpThreadAttributes, int bInheritHandles, uint32_t dwCreationFlags,
        void* lpEnvironment, const char* lpCurrentDirectory,
        STARTUPINFOA* lpStartupInfo, PROCESS_INFORMATION* lpProcessInformation
    );
    uint32_t WaitForSingleObject(void* hHandle, uint32_t dwMilliseconds);
    int CloseHandle(void* hObject);
]]

local kernel32 = ffi.load("kernel32")

-- Executes a command completely silently using Windows API
local function execute_hidden(cmd)
    local si = ffi.new("STARTUPINFOA")
    si.cb = ffi.sizeof("STARTUPINFOA")
    local pi = ffi.new("PROCESS_INFORMATION")
    
    local success = kernel32.CreateProcessA(
        nil, ffi.cast("char*", cmd), nil, nil, 0,
        0x08000000, -- CREATE_NO_WINDOW
        nil, nil, si, pi
    )
    
    if success ~= 0 then
        kernel32.WaitForSingleObject(pi.hProcess, 0xFFFFFFFF)
        kernel32.CloseHandle(pi.hProcess)
        kernel32.CloseHandle(pi.hThread)
        return true
    end
    return false
end

--- Build and execute a curl.exe command via FFI
local function doCurl(req_id, method, url, body, headers)
    local headerArgs = ""
    for k, v in pairs(headers) do
        headerArgs = headerArgs .. string.format(' -H "%s: %s"', k, v)
    end

    local bodyArg = ""
    local tmpBodyFile = "_net_body_" .. tostring(req_id) .. ".tmp"
    local tmpBodyPath = love.filesystem.getSaveDirectory() .. "/" .. tmpBodyFile
    if body and body ~= "" then
        love.filesystem.write(tmpBodyFile, body)
        tmpBodyPath = tmpBodyPath:gsub("/", "\\")
        bodyArg = string.format(' --data-binary "@%s"', tmpBodyPath)
    end

    local tmpOutFile = "_net_out_" .. tostring(req_id) .. ".tmp"
    local tmpOutPath = (love.filesystem.getSaveDirectory() .. "/" .. tmpOutFile):gsub("/", "\\")

    local cmd = string.format(
        'cmd.exe /c curl.exe -s --connect-timeout 5 -m 10 -X %s%s%s -w "_HTTP_%%{http_code}" "%s" > "%s"',
        method, headerArgs, bodyArg, url, tmpOutPath
    )

    local success = execute_hidden(cmd)
    
    local result = ""
    if success and love.filesystem.getInfo(tmpOutFile) then
        result = love.filesystem.read(tmpOutFile)
    end

    -- Cleanup temp files
    if body and body ~= "" then
        love.filesystem.remove(tmpBodyFile)
    end
    love.filesystem.remove(tmpOutFile)

    if not success or not result or result == "" then
        return 0, "Failed to execute curl.exe or read response"
    end

    local responseBody, statusCode = result:match("^(.-)_HTTP_(%d+)%s*$")
    statusCode = tonumber(statusCode) or 0
    responseBody = responseBody or ""
    responseBody = responseBody:match("^(.-)%s*$") or ""

    return statusCode, responseBody
end

-- Main loop: process requests forever
while true do
    -- Wait up to 1 second for a request
    local rawRequest = requestChannel:demand(1)

    if rawRequest then
        if rawRequest == "__SHUTDOWN__" then
            break
        end

        local ok, errMsg = pcall(function()
            local req = json.decode(rawRequest)
            if not req then return end

            local status, body = doCurl(
                req.id,
                req.method,
                req.url,
                req.body,
                req.headers or {}
            )

            local response = json.encode({
                id     = req.id,
                status = status,
                body   = body,
            })

            responseChannel:push(response)
        end)

        if not ok then
            -- Push error response
            local reqId = "unknown"
            pcall(function()
                reqId = json.decode(rawRequest).id or "unknown"
            end)
            responseChannel:push(json.encode({
                id     = reqId,
                status = 0,
                body   = tostring(errMsg),
            }))
        end
    end
end
