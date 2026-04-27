# Netcode Theory Reference

## The Three Synchronization Models

### 1. Lockstep (Deterministic)
All peers simulate the same inputs at the same time. No one advances until all inputs for tick N are confirmed.

```
Peer A: [Input A1] ──────────────────────► Simulate Tick N (all inputs confirmed)
Peer B: [Input B1] ──────────────────────► Simulate Tick N (all inputs confirmed)
```

**Pros:** Simple, bandwidth-minimal (only inputs travel the wire), provably consistent  
**Cons:** Slowest peer throttles everyone; requires determinism  
**Use for:** Board games, card games, strategy games, turn-based puzzles

### 2. Rollback (Speculative Execution)
Peers simulate immediately using *predicted* inputs. When real inputs arrive, rollback and re-simulate if prediction was wrong.

```
Peer A: Simulate N with predicted B input ──► [B input arrives] ──► Rollback ──► Re-simulate N with real B input
```

**Pros:** No input delay; player feels immediate response  
**Cons:** Requires serializable game state; CPU-intensive re-simulation; requires determinism  
**Use for:** Fighting games, arcade action, real-time 1v1

### 3. Snapshot Interpolation (Server-Authoritative)
Server ticks at a fixed rate and broadcasts state snapshots. Clients render interpolated *past* state (100–200ms behind). No determinism required.

```
Server: Tick ──► Snapshot ──► Clients interpolate between snapshot[N-1] and snapshot[N]
```

**Pros:** Forgiving; works with non-deterministic physics; easier to anti-cheat  
**Cons:** Latency to view is always ≥ interpolation window; requires server  
**Use for:** Co-op RPG, shooters, physics-heavy games

---

## Determinism Requirements

If you choose lockstep or rollback, your simulation MUST be deterministic:

| Source of Non-determinism | Fix |
|---|---|
| `math.random()` / `Random.Range()` | Seed all RNGs identically; network-sync seeds |
| `deltaTime` / `Time.deltaTime` | Use a fixed timestep (e.g. 1/60 s) |
| `Dictionary` / `HashMap` iteration order | Use sorted lists or arrays |
| Floating-point physics (Box2D, Bullet) | Use integer/fixed-point math; or switch to snapshot interpolation |
| Platform-dependent `math.sin/cos` | Use lookup tables or verified cross-platform libraries |
| Entity spawn order | Use deterministic IDs, not OS-assigned handles |

---

## Packet Design

### Reliable vs Unreliable

| Data | Channel | Why |
|---|---|---|
| Game events (move, shoot, die) | **Reliable** | Must arrive; order matters |
| Position updates (real-time) | **Unreliable** | Stale if late; newer supersedes |
| Chat messages | **Reliable** | |
| Score updates | **Reliable** | |
| Animation hints | **Unreliable** | |

### Input Redundancy (Anti-loss for Lockstep)
Send the last N inputs in every packet. If packet K is lost, packet K+1 carries inputs for both ticks K and K+1.

```lua
-- Send current + last 2 inputs per packet
local payload = {
  tick = currentTick,
  inputs = {
    [currentTick]   = localInput,
    [currentTick-1] = inputHistory[currentTick-1],
    [currentTick-2] = inputHistory[currentTick-2],
  }
}
```

### Delta Compression
Only send properties that changed since last ack'd state:
```lua
local delta = {}
for k, v in pairs(currentState) do
  if v ~= lastSentState[k] then delta[k] = v end
end
```

---

## Desync Prevention Checklist

- [ ] All peers run at the same fixed timestep
- [ ] RNG seeded identically on session start
- [ ] No `os.clock()`, wall time, or frame-count used in game logic
- [ ] No platform-specific math functions in simulation
- [ ] State hash computed and exchanged every N ticks
- [ ] Desync handler: log + graceful disconnect (never silently diverge)

---

## Latency Budget (Reference)

| Ping | Technique | Feel |
|---|---|---|
| 0–50ms | Input delay alone (0–3 frames) | Imperceptible |
| 50–100ms | Input delay + rollback | Smooth |
| 100–150ms | Rollback + max prediction window | Acceptable |
| 150–250ms | Snapshot interpolation | Playable |
| >250ms | Add input delay; consider region lock | Degraded |

---

## Authoritative Server vs P2P

### Server-Authoritative
```
Client ──── input ────► Server (simulates, validates) ──► state ──► All Clients
```
- Cheating is hard
- Server costs money
- Best for: shooters, MMOs, competitive games

### P2P (with relay for NAT traversal)
```
Peer A ◄──── inputs ────► Peer B (both simulate identically)
```
- No server costs
- Each peer must be trusted (or use hash verification)
- Best for: fighting games, cooperative games, 1v1
- NAT traversal: use STUN/TURN server or a relay service (e.g. Steam Networking, EOS P2P, Photon)
