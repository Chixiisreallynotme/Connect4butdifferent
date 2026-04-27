# Godot 4 — Additive Multiplayer Integration Example
# Turn-based board game (Connect 4, chess, etc.)
#
# Files created (no existing files modified):
#   multiplayer/NetManager.gd  (Autoload)
#   multiplayer/Lobby.tscn + Lobby.gd
#
# Extension points used:
#   - GameBoard._ready() → calls _try_add_net_sync() (one new line)
#   - GameBoard._on_local_move() → calls net.send_move() if enabled (one new line)

# ─── multiplayer/NetManager.gd (add as Autoload: Project > Autoload > NetManager) ───
extends Node

const PORT       := 7777
const MAX_PEERS  := 2

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal move_received(col: int, from_id: int)

var enabled   := false
var is_server := false
var local_id  := 1

func host_game() -> void:
    var peer := ENetMultiplayerPeer.new()
    var err  := peer.create_server(PORT, MAX_PEERS)
    if err != OK:
        push_error("[NET] Failed to create server: %s" % err)
        return
    multiplayer.multiplayer_peer = peer
    enabled   = true
    is_server = true
    local_id  = 1
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("[NET] Hosting on port %d" % PORT)

func join_game(address: String) -> void:
    var peer := ENetMultiplayerPeer.new()
    var err  := peer.create_client(address, PORT)
    if err != OK:
        push_error("[NET] Failed to connect: %s" % err)
        return
    multiplayer.multiplayer_peer = peer
    enabled   = true
    is_server = false
    local_id  = 2
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    print("[NET] Joining %s:%d" % [address, PORT])

func shutdown() -> void:
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer = null
    enabled   = false
    is_server = false
    print("[NET] Disconnected")

# ─── RPC: send a move from any peer to all peers ─────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func receive_move(col: int, from_id: int) -> void:
    move_received.emit(col, from_id)

func send_move(col: int) -> void:
    if not enabled:
        return
    receive_move.rpc(col, local_id)

# ─── Internal callbacks ───────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
    print("[NET] Peer connected: %d" % id)
    peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
    print("[NET] Peer disconnected: %d" % id)
    peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
    print("[NET] Connected to server")
    peer_connected.emit(multiplayer.get_unique_id())

# ─── How to wire into existing GameBoard.gd (additive only) ──────────────────
#
# In GameBoard.gd, add exactly TWO lines:
#
#   func _ready():
#       # ... all existing _ready code untouched ...
#       NetManager.move_received.connect(_on_net_move)   # ← ADD THIS LINE
#
#   func _on_local_move(col: int) -> void:
#       apply_move(col, NetManager.local_id)             # ← original
#       NetManager.send_move(col)                        # ← ADD THIS LINE
#
#   # New method — does NOT modify existing methods:
#   func _on_net_move(col: int, from_id: int) -> void:
#       if from_id != NetManager.local_id:
#           apply_move(col, from_id)                     # reuse original logic
