---
name: integrating-multiplayer-layer
description: Analyzes the architecture of an existing game project and integrates an optional cooperative or 1v1 multiplayer layer without altering original game logic or player experience. Use when the user mentions multiplayer, netcode, co-op, online play, network synchronization, adding multiplayer to an existing game, peer-to-peer, dedicated server, rollback netcode, lockstep, state sync, or wants to add a network layer to a solo game in LÖVE2D, Lua, Godot, Unity, or Unreal Engine.
---

# Integrating a Multiplayer Layer

## When to use this skill

- User wants to add online co-op or 1v1 to an existing solo game
- User mentions netcode, state synchronization, rollback, lockstep, or peer-to-peer
- User says "add multiplayer without breaking my game"
- User wants a network layer that can be disabled and fall back to solo play
- Game is built in: **LÖVE2D/Lua**, **Godot 4**, **Unity**, or **Unreal Engine 5**

---

## Core Philosophy: Additive, Never Refactor

> The solo mode must remain 100% intact. Multiplayer is a **feature flag**, not a rewrite.

Three non-destructive rules:
1. **No existing function may be modified** — extend via composition, signals, or wrappers
2. **A `MULTIPLAYER_ENABLED` guard** wraps every net call — disabling it restores solo
3. **Every new file is namespaced** under `net/` or `multiplayer/` — zero collision risk

---

## Workflow

### Step 1 — Audit the Project
- [ ] Identify the engine/framework (see [Engine Detection](#engine-detection))
- [ ] Map the **game loop entry points**: update, draw, input callbacks
- [ ] Identify **authoritative game state** (positions, health, score, turn data, board state)
- [ ] Find **random number generators** — mark them as desync risks
- [ ] Note **physics engine** — deterministic? Floating-point consistent?
- [ ] Detect existing save/load system (needed for state snapshots)

### Step 2 — Choose Protocol & Architecture
Use [Protocol Selection Matrix](#protocol-selection-matrix) to decide:
- **Rollback** (fast-paced, real-time) vs **Lockstep** (turn-based, strategy)
- **P2P** vs **Client-Server** based on game type

### Step 3 — Identify Safe Extension Points
- [ ] State machine transitions (inject network sync here)
- [ ] Input handler (intercept inputs before they reach game logic)
- [ ] End-of-frame / post-update hook (broadcast state delta here)
- [ ] Game event bus or signal system (subscribe net layer without touching emitters)

### Step 4 — Generate the Network Module
Use the template for the detected engine from [Implementation Templates](#implementation-templates).
Every template follows the same interface:
```
net.init(mode)   -- "host" | "client" | "solo"
net.update(dt)   -- called from existing love.update / _process / Update
net.send(event, data)
net.poll()       -- returns queued remote events
net.shutdown()
```

### Step 5 — Wire Into Existing Code (Additive Only)
```
-- BEFORE (original, untouched):
function love.update(dt)
  game:update(dt)
end

-- AFTER (additive wrapper):
function love.update(dt)
  game:update(dt)
  if MULTIPLAYER_ENABLED then net.update(dt) end  -- ← only addition
end
```

### Step 6 — Document Every Change
- [ ] Create `MULTIPLAYER.md` at project root (see [Documentation Template](#documentation-template))
- [ ] Add `-- [NET]` comment on every line that touches the net module
- [ ] List all added files in `MULTIPLAYER.md`

### Step 7 — Validate Solo Integrity
- [ ] Set `MULTIPLAYER_ENABLED = false` — game must run identically to pre-integration
- [ ] Run a local 2-player session (`host` + `client` on same machine)
- [ ] Confirm game state converges after 30 seconds of play

---

## Engine Detection

| Signal | Engine |
|---|---|
| `main.lua`, `conf.lua`, `require`, `love.*` | **LÖVE2D / Lua** |
| `.gd`, `.tscn`, `@export`, `multiplayer.` | **Godot 4** |
| `.cs`, `MonoBehaviour`, `NetworkBehaviour`, `[ServerRpc]` | **Unity** |
| `.uproject`, `UPROPERTY`, `AGameMode`, `GetWorld()` | **Unreal Engine 5** |

---

## Protocol Selection Matrix

| Game Type | Pace | Best Protocol | Architecture |
|---|---|---|---|
| Fighting / Action | Real-time, <16ms frames | **UDP + Rollback** | P2P |
| Platformer / Shooter | Real-time | **UDP + Client-Side Prediction** | Client-Server |
| Turn-based / Puzzle | Slow, deterministic | **TCP / Reliable UDP + Lockstep** | P2P or Client-Server |
| Co-op / RPG | Mixed | **UDP + Snapshot Interpolation** | Client-Server |
| Board game (e.g. Connect 4) | Turn-based | **TCP or Reliable UDP + Lockstep** | P2P |

**Key rules:**
- Use **UDP** for anything real-time; add your own reliability for critical packets
- Use **rollback** only if the game is fully deterministic (fixed timestep, seeded RNG, no floating-point physics across platforms)
- Use **lockstep** for turn-based games — simpler, lower bandwidth, easier to verify
- Use **snapshot interpolation** when rollback is impractical (physics-heavy, non-deterministic)

---

## Implementation Templates

### LÖVE2D / Lua — ENet (built-in)

> ENet is bundled with LÖVE. No install needed. Provides reliable/unreliable UDP channels.

**File layout:**
```
net/
  init.lua        -- module entry, exports net table
  host.lua        -- server-side peer management
  client.lua      -- client connection logic
  serializer.lua  -- msgpack or simple string encoding
  events.lua      -- event queue (incoming remote events)
```

**`net/init.lua`** template:
```lua
-- [NET] Multiplayer layer - additive only. Set MULTIPLAYER_ENABLED=false to disable.
local enet = require("enet")
local net = {}

local DEFAULT_PORT = 6789
local CHANNEL_RELIABLE   = 0
local CHANNEL_UNRELIABLE = 1

local host, serverPeer
local mode = "solo"
local incomingQueue = {}

function net.init(m, address)
  mode = m or "solo"
  if mode == "host" then
    host = enet.host_create("*:" .. DEFAULT_PORT, 4)
    print("[NET] Hosting on port " .. DEFAULT_PORT)
  elseif mode == "client" then
    host = enet.host_create()
    serverPeer = host:connect((address or "localhost") .. ":" .. DEFAULT_PORT)
    print("[NET] Connecting to " .. (address or "localhost"))
  end
end

function net.update(dt)
  if not host then return end
  local event = host:service(0)
  while event do
    if event.type == "receive" then
      local ok, data = pcall(net.deserialize, event.data)
      if ok then incomingQueue[#incomingQueue + 1] = data end
    elseif event.type == "connect" then
      print("[NET] Peer connected:", event.peer)
    elseif event.type == "disconnect" then
      print("[NET] Peer disconnected:", event.peer)
    end
    event = host:service(0)
  end
end

-- Send to all peers (host) or to server (client)
function net.send(eventName, payload, reliable)
  if not host then return end
  local msg = net.serialize({ e = eventName, d = payload })
  local channel = reliable ~= false and CHANNEL_RELIABLE or CHANNEL_UNRELIABLE
  if mode == "host" then
    host:broadcast(msg, channel)
  elseif mode == "client" and serverPeer then
    serverPeer:send(msg, channel)
  end
end

function net.poll()
  local q = incomingQueue
  incomingQueue = {}
  return q
end

function net.shutdown()
  if host then host:destroy() end
  host, serverPeer = nil, nil
  mode = "solo"
end

-- Minimal serializer (replace with bitser for production)
function net.serialize(t)
  -- Simple: encode as "key=val|key=val" for flat tables
  -- For nested data, use: https://github.com/gvx/bitser
  return require("json").encode(t)  -- swap json lib as needed
end

function net.deserialize(s)
  return require("json").decode(s)
end

return net
```

**Wiring into `main.lua` (additive):**
```lua
local MULTIPLAYER_ENABLED = false  -- flip to true to activate

local net
if MULTIPLAYER_ENABLED then
  net = require("net.init")
  net.init("host")  -- or "client", "solo"
end

function love.update(dt)
  game:update(dt)  -- ← untouched
  if MULTIPLAYER_ENABLED then
    net.update(dt)
    for _, event in ipairs(net.poll()) do
      game:onNetEvent(event)  -- ← injected handler (see below)
    end
  end
end

function love.quit()
  if MULTIPLAYER_ENABLED and net then net.shutdown() end
end
```

**Lockstep pattern for turn-based LÖVE2D games:**
```lua
-- In game state, add an onNetEvent handler without changing other methods:
function GameState:onNetEvent(event)
  if event.e == "opponent_move" then
    -- Apply remote player's move as if it were local input
    self:applyMove(event.d.col, REMOTE_PLAYER_ID)
  end
end

-- When local player makes a move, broadcast it:
function GameState:onLocalMove(col)
  self:applyMove(col, LOCAL_PLAYER_ID)        -- ← original call
  if MULTIPLAYER_ENABLED then
    net.send("opponent_move", { col = col })  -- ← additive
  end
end
```

---

### Godot 4 — High-Level MultiplayerAPI

> Use `MultiplayerSpawner` + `MultiplayerSynchronizer` nodes. Zero code changes to existing scenes.

**File layout:**
```
multiplayer/
  lobby.gd              -- connection management
  net_manager.gd        -- autoload singleton
  player_sync.tscn      -- MultiplayerSynchronizer sub-scene
```

**`net_manager.gd`** (add as Autoload, never modify existing nodes):
```gdscript
# [NET] Autoload singleton — additive only. Remove from Project > Autoload to disable.
extends Node

const PORT = 7777
const MAX_PEERS = 2

var multiplayer_enabled := false

func host_game():
  var peer = ENetMultiplayerPeer.new()
  peer.create_server(PORT, MAX_PEERS)
  multiplayer.multiplayer_peer = peer
  multiplayer_enabled = true

func join_game(address: String):
  var peer = ENetMultiplayerPeer.new()
  peer.create_client(address, PORT)
  multiplayer.multiplayer_peer = peer
  multiplayer_enabled = true

func shutdown():
  multiplayer.multiplayer_peer = null
  multiplayer_enabled = false
```

**Inject sync non-destructively via a child scene:**
```gdscript
# In player.gd — ADD this function, touch nothing else:
func _add_net_sync():
  if not NetManager.multiplayer_enabled:
    return
  var sync = preload("res://multiplayer/player_sync.tscn").instantiate()
  add_child(sync)  # MultiplayerSynchronizer auto-configures from scene

# Call from _ready():
func _ready():
  _add_net_sync()  # ← only addition; rest of _ready() untouched
```

**For turn-based Godot games — RPC lockstep:**
```gdscript
# [NET] Add to existing game controller without modifying its other methods:
@rpc("any_peer", "call_local", "reliable")
func receive_opponent_move(col: int):
  game_board.apply_move(col, REMOTE_PLAYER)

func _on_local_move(col: int):
  game_board.apply_move(col, LOCAL_PLAYER)  # ← original
  if NetManager.multiplayer_enabled:       # ← additive guard
    receive_opponent_move.rpc(col)
```

---

### Unity — Netcode for GameObjects (NGO)

> Recommended: Unity NGO 2.x + Unity Transport. Mirror is a valid alternative for simpler projects.

**File layout:**
```
Assets/Multiplayer/
  NetworkBootstrap.cs     -- NetworkManager setup, no MonoBehaviour edits elsewhere
  PlayerNetworkSync.cs    -- NetworkBehaviour component added at runtime
  NetEvents.cs            -- static event bus bridging net ↔ game
```

**`NetworkBootstrap.cs`** — runtime injection, no scene modifications:
```csharp
// [NET] Attach to a new empty GameObject "NetworkBootstrap".
// Existing scenes and MonoBehaviours are untouched.
using Unity.Netcode;
using UnityEngine;

public class NetworkBootstrap : MonoBehaviour
{
    public static bool MultiplayerEnabled = false;

    void Awake()
    {
        if (!MultiplayerEnabled) { Destroy(gameObject); return; }
        DontDestroyOnLoad(gameObject);
    }

    public void StartHost() => NetworkManager.Singleton.StartHost();
    public void StartClient() => NetworkManager.Singleton.StartClient();
    public void Shutdown()    => NetworkManager.Singleton.Shutdown();
}
```

**`PlayerNetworkSync.cs`** — attached to Player prefab additively:
```csharp
// [NET] Add this component via code or prefab variant — do NOT modify original Player.cs
using Unity.Netcode;
using UnityEngine;

public class PlayerNetworkSync : NetworkBehaviour
{
    private NetworkVariable<Vector3> _netPosition =
        new NetworkVariable<Vector3>(writePerm: NetworkVariableWritePermission.Owner);

    public override void OnNetworkSpawn()
    {
        if (!IsOwner)
            _netPosition.OnValueChanged += (_, newVal) => transform.position = newVal;
    }

    void LateUpdate()  // LateUpdate so original Update() runs first
    {
        if (IsOwner && NetworkBootstrap.MultiplayerEnabled)
            _netPosition.Value = transform.position;
    }
}
```

**Lockstep for turn-based Unity games:**
```csharp
// [NET] Partial class extension OR component added to GameController GameObject
public class GameNetBridge : NetworkBehaviour
{
    [ServerRpc(RequireOwnership = false)]
    public void SubmitMoveServerRpc(int col, ulong senderId)
    {
        ApplyMoveClientRpc(col, senderId);
    }

    [ClientRpc]
    void ApplyMoveClientRpc(int col, ulong senderId)
    {
        // Calls the ORIGINAL game method — no modification needed
        FindObjectOfType<GameController>().ApplyMove(col, (int)senderId);
    }
}
```

---

### Unreal Engine 5 — Replication + GameFramework

> UE5 replication is baked into the framework. The safest additive path is:
> 1. Create a **Multiplayer GameMode** (child of existing GameMode)
> 2. Mark variables `UPROPERTY(Replicated)` in a **new subclass**
> 3. Use **Server RPCs** called only when `HasAuthority()`

**File layout:**
```
Source/YourGame/Multiplayer/
  MultiplayerGameMode.h/.cpp   -- extends existing AGameMode, adds net logic
  NetComponent.h/.cpp          -- ActorComponent added to Player at runtime
  MultiplayerSubsystem.h/.cpp  -- UGameInstanceSubsystem (safe singleton)
```

**`MultiplayerSubsystem.h`** — zero-touch singleton:
```cpp
// [NET] UGameInstanceSubsystem — auto-created by UE, never conflicts with game code
UCLASS()
class YOURGAME_API UMultiplayerSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadOnly) bool bMultiplayerEnabled = false;
    UFUNCTION(BlueprintCallable) void HostGame(int32 Port = 7777);
    UFUNCTION(BlueprintCallable) void JoinGame(const FString& Address);
    UFUNCTION(BlueprintCallable) void Shutdown();
};
```

**Additive replication pattern:**
```cpp
// In NetComponent.cpp — component added to BP_Player without modifying it:
void UNetComponent::TickComponent(float DeltaTime, ...)
{
    Super::TickComponent(DeltaTime, ELevelTick, ThisTickFunction);
    if (!bMultiplayerEnabled || !GetOwner()->HasAuthority()) return;
    // Replicate owner state — original Tick() untouched
    Server_SendState(GetOwner()->GetActorTransform());
}
```

---

## Netcode Decision Guide

### Rollback (real-time, latency-tolerant)
- **Requires**: fixed timestep, deterministic simulation, serializable full game state
- **Implement if**: fighting game, action platformer, real-time arcade
- **Key steps**: snapshot entire game state each tick, restore on mismatch, re-simulate
- **Avoid**: physics engines with floating-point variance across OS/hardware

### Lockstep (turn-based, reliable)
- **Requires**: players take turns (or send inputs simultaneously); can tolerate input delay
- **Implement if**: board games, card games, strategy, puzzle
- **Key steps**: buffer all inputs for tick N before simulating tick N; send input + hash; compare hashes to detect desync
- **Bandwidth**: minimal — only inputs travel the wire

### Snapshot Interpolation (forgiving, server-authoritative)
- **Requires**: dedicated or listen server; clients render interpolated past state
- **Implement if**: co-op RPG, shooter, anything with non-deterministic physics
- **Key steps**: server ticks at fixed rate, sends snapshots; clients interpolate between last two snapshots

---

## Documentation Template

Generate `MULTIPLAYER.md` at project root after integration:

```markdown
# Multiplayer Layer

> Added: [DATE] | Mode: [co-op / 1v1] | Protocol: [ENet / NGO / RPC]

## Feature Flag
Set `MULTIPLAYER_ENABLED = false` (or remove NetManager autoload) to restore solo mode.

## Files Added (none modified)
- `net/init.lua` — network module entry point
- `net/host.lua` — host peer management
- `MULTIPLAYER.md` — this file

## Extension Points Used
| Original File | Hook Used | What Was Added |
|---|---|---|
| `main.lua` | After `game:update(dt)` | `net.update(dt)` call |
| `game_state.lua` | New method | `onNetEvent(event)` handler |

## Solo Mode Verification
- [ ] `MULTIPLAYER_ENABLED = false` tested — game behaves identically
- [ ] No new globals introduced
- [ ] No existing functions modified
```

---

## Common Pitfalls

| Pitfall | Prevention |
|---|---|
| RNG desync | Seed RNG with same value on all peers; never use `math.random()` without seeding |
| Float desync | Use fixed-point integers for physics in lockstep; snapshot interpolation otherwise |
| Input ownership | Always gate input reads: `if isLocalPlayer then ...` |
| Scene change desync | On Godot: use `MultiplayerSpawner` instead of `change_scene_to_file()` |
| Physics conflicts | Disable physics on remote-owned entities; let authority simulate |
| Late joiners | Implement state snapshot transfer on connect, not just incremental updates |
| Forgetting to reset | Call `net.shutdown()` on game over / scene unload |

---

## Resources

- [Engine-specific examples](examples/)
- [Netcode theory reference](resources/netcode-theory.md)
- [Desync debugging checklist](resources/desync-debug.md)
