--[[
  LÖVE2D Lockstep Multiplayer — Turn-Based Example
  
  Demonstrates additive integration for a turn-based game (e.g. Connect 4, chess).
  ORIGINAL GAME CODE IS NOT MODIFIED. The net module is injected around it.
  
  Architecture: P2P lockstep over ENet reliable channel.
  Each player sends their move; both simulate locally only after both moves are received.
  
  Usage:
    love . host    -- start as host (Player 1)
    love . client 192.168.1.x  -- start as client (Player 2)
]]

local enet = require("enet")

-- ─── NET CONFIG ───────────────────────────────────────────────────────────────
local NET = {
  PORT     = 6789,
  TIMEOUT  = 5000,  -- ms to wait for connection
}

-- ─── STATE ────────────────────────────────────────────────────────────────────
local net = {
  host        = nil,
  peer        = nil,
  mode        = "solo",   -- "host" | "client" | "solo"
  localId     = 1,        -- 1 = host, 2 = client
  remoteId    = 2,
  connected   = false,
  queue       = {},        -- incoming events
}

-- ─── SERIALIZATION ────────────────────────────────────────────────────────────
-- Minimal serializer: encode flat table as "k1=v1;k2=v2"
local function encode(t)
  local parts = {}
  for k, v in pairs(t) do
    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
  end
  return table.concat(parts, ";")
end

local function decode(s)
  local t = {}
  for pair in s:gmatch("[^;]+") do
    local k, v = pair:match("^(.-)=(.+)$")
    if k then
      -- Try to coerce to number
      t[k] = tonumber(v) or v
    end
  end
  return t
end

-- ─── PUBLIC API ───────────────────────────────────────────────────────────────

function net.init(mode, address)
  net.mode = mode
  if mode == "host" then
    net.host    = enet.host_create("*:" .. NET.PORT, 2)
    net.localId  = 1
    net.remoteId = 2
    print("[NET] Waiting for client on port " .. NET.PORT)
  elseif mode == "client" then
    net.host     = enet.host_create()
    net.peer     = net.host:connect((address or "localhost") .. ":" .. NET.PORT)
    net.localId  = 2
    net.remoteId = 1
    print("[NET] Connecting to " .. (address or "localhost") .. ":" .. NET.PORT)
  end
end

function net.update()
  if not net.host then return end
  local event = net.host:service(0)
  while event do
    if event.type == "connect" then
      net.connected = true
      net.peer      = event.peer
      print("[NET] Connected to peer")
    elseif event.type == "disconnect" then
      net.connected = false
      print("[NET] Peer disconnected")
    elseif event.type == "receive" then
      local data = decode(event.data)
      net.queue[#net.queue + 1] = data
    end
    event = net.host:service(0)
  end
end

-- Returns and clears the incoming event queue
function net.poll()
  local q = net.queue
  net.queue = {}
  return q
end

-- Send a move event to the remote peer (reliable)
function net.sendMove(col)
  if not net.peer or not net.connected then return end
  local msg = encode({ e = "move", col = col, from = net.localId })
  net.peer:send(msg, 0)  -- channel 0 = reliable
end

function net.shutdown()
  if net.host then net.host:destroy() end
  net.host, net.peer = nil, nil
  net.connected = false
  net.mode = "solo"
end

-- ─── INTEGRATION EXAMPLE ─────────────────────────────────────────────────────
--[[
  In your main.lua / game state, add ONLY these two patterns:

  1. In love.update(dt):
     net.update()
     for _, event in ipairs(net.poll()) do
       if event.e == "move" then
         game:applyMove(event.col, net.remoteId)  -- apply remote player's move
       end
     end

  2. When local player makes a move:
     game:applyMove(col, net.localId)    -- apply locally (original call)
     net.sendMove(col)                   -- broadcast to remote (additive)
]]

return net
