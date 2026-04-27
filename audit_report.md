# 🔍 Audit Complet — Connect 4 Pixel Art (LÖVE2D)

> **23 fichiers analysés** | 4 passes (statique, LÖVE, logique, tests)

---

## Fichier: `main.lua`

### 🔴 Bugs Critiques

**[main.lua:24] Variable globale intentionnelle mais risquée — `_G.stateMachine`**
L'utilisation de `_G.stateMachine` est explicitement commentée comme intentionnelle. Cependant, c'est le seul global du projet. **Accepté mais signalé.**

### 🟡 Avertissements & Optimisations

**[main.lua:81-84] `require` à chaque appel de `love.quit()`**
```lua
local ok, network = pcall(require, "src.network")
```
`require` met en cache, donc pas de coût réel. ✅ Correct — le `pcall` protège bien contre l'absence du module.

### ✅ Points Corrects
- `dt` cappé à `1/30` (L39) — empêche les explosions physiques
- Filtre `nearest` appliqué globalement (L13)
- Coordinate conversion correcte via `pixelCanvas:screenToPixel`
- `love.resize` propage bien au pixel canvas et à la state machine

---

## Fichier: `conf.lua`

### ✅ Points Corrects
- Modules inutilisés désactivés (joystick, physics, video, touch)
- VSync activé, MSAA désactivé (cohérent pixel art)
- `t.window.resizable = false` — empêche les problèmes de redimensionnement

### 🟡 Avertissements

**[conf.lua:9] Fenêtre non-resizable mais `love.resize` est implémenté**
`resizable = false` + F11 fullscreen fonctionne, mais le callback `love.resize` ne sera appelé qu'en fullscreen. Pas un bug, mais une incohérence mineure.

---

## Fichier: `src/state_machine.lua`

### ✅ Points Corrects
- Guard clauses (`if self.current and self.current.X`) sur toutes les méthodes
- `exit()` appelé avant `enter()` lors du switch — correct
- Tous les callbacks LÖVE sont bien relayés

### 🟡 Avertissements

**[state_machine.lua:19-28] Pas de validation du nom d'état**
```lua
function StateMachine:switch(name, params)
    -- Si name n'existe pas dans self.states, self.current sera nil
    -- Aucune erreur levée, le jeu se fige silencieusement
```
**Correction recommandée :**
```lua
function StateMachine:switch(name, params)
    assert(self.states[name], "Unknown state: " .. tostring(name))
    -- ...
end
```

---

## Fichier: `src/pixel_canvas.lua`

### ✅ Points Corrects
- Canvas créé une seule fois dans `new()` — pas recréé chaque frame
- Filtre `nearest` appliqué au canvas
- `math.floor` utilisé pour le scale et les offsets — pixel-perfect

### 🟡 Avertissements

**[pixel_canvas.lua:23-25] Scale peut être 0 si la fenêtre est très petite**
```lua
local scaleX = math.floor(ww / PixelCanvas.GAME_W)  -- peut être 0
self.scale = math.min(scaleX, scaleY)                -- self.scale = 0
```
Si `scale = 0`, `screenToPixel` fait une division par zéro (L43).
**Correction :**
```lua
self.scale = math.max(1, math.min(scaleX, scaleY))
```

---

## Fichier: `src/board.lua`

### ✅ Points Corrects
- Bounds checking dans `getCell` (retourne -1 hors bornes)
- `checkWin` vérifie les 4 directions (H, V, diag\, diag/) — correct
- `canDrop` vérifie les bornes avant l'accès au grid
- Aucune allocation dans les hot paths

### 🟡 Avertissements

**[board.lua:72] Allocation de table `directions` à chaque appel de `checkWin`**
```lua
local directions = {
    {dc = 1, dr = 0}, {dc = 0, dr = 1},
    {dc = 1, dr = 1}, {dc = 1, dr = -1},
}
```
Appelé à chaque vérification de victoire (y compris dans l'IA minimax). Crée une pression GC.
**Correction :** Promouvoir en variable de module.
```lua
local DIRECTIONS = {
    {dc = 1, dr = 0}, {dc = 0, dr = 1},
    {dc = 1, dr = 1}, {dc = 1, dr = -1},
}
-- Puis utiliser DIRECTIONS dans checkWin
```

**[board.lua:80] Allocation de table `cells` à chaque direction**
```lua
local cells = {{col = col, row = row}}
```
Dans le minimax, `checkWin` est appelé des milliers de fois → pression GC significative.
**Impact :** Modéré en gameplay normal, significatif dans l'IA à haute profondeur.

---

## Fichier: `src/ai.lua`

### 🔴 Bugs Critiques

**[ai.lua:119-134] `isTerminal` scanne TOUT le plateau à chaque nœud minimax**
```lua
local function isTerminal(board)
    for col = 1, Board.COLS do
        for row = 1, Board.ROWS do
            if board:getCell(col, row) ~= 0 then
                if board:checkWin(col, row) then -- O(42 × 4 directions)
```
Complexité : O(42 × 4) par appel × profondeur récursive. Combiné avec les allocations de `checkWin`, c'est le principal goulot.
**Impact :** Lag perceptible à difficulté 9-10 (profondeur 7-8).
**Correction :** Tracker le dernier coup joué et ne vérifier que celui-ci :
```lua
local function isTerminal(board, lastCol, lastRow)
    if lastCol and lastRow then
        local p = board:getCell(lastCol, lastRow)
        if p ~= 0 and board:checkWin(lastCol, lastRow) then
            return true, p
        end
    end
    return board:isFull(), 0
end
```

**[ai.lua:66] Allocation de table `window` dans la boucle de scoring**
```lua
local window = {
    board:getCell(col, row),
    board:getCell(col+1, row), ...
}
```
4 tables × (7×6 + 7×3 + 4×3 + 4×3) = ~140 tables par appel à `scorePosition`, à chaque nœud minimax.
**Correction :** Utiliser des variables locales au lieu d'une table :
```lua
local c1 = board:getCell(col, row)
local c2 = board:getCell(col+1, row)
-- Passer directement à evaluateWindow(c1,c2,c3,c4, player)
```

### 🟡 Avertissements

**[ai.lua:148-156] `simulateDrop` modifie le board en place — correct mais fragile**
Le pattern simulate/undo est correct. Tout chemin de retour appelle bien `undoDrop`.

---

## Fichier: `src/audio_manager.lua`

### ✅ Points Corrects
- Toutes les sources audio créées une seule fois dans `init()` — bien mises en cache
- `SoundData` générées procéduralement — pas de fichiers externes
- `stop()` avant `play()` (L114-115) — correct pour éviter les superpositions

### 🟡 Avertissements

**[audio_manager.lua:120-126] `playClone` crée un clone sans le tracker — fuite mémoire potentielle**
```lua
function AudioManager.playClone(name)
    local clone = source:clone()
    clone:play()  -- jamais nettoyé, LÖVE GC le collectera... éventuellement
end
```
Si appelé fréquemment, accumulation de sources. LÖVE finit par les GC mais ce n'est pas garanti immédiatement.
**Impact :** Faible — `playClone` n'est jamais appelé dans le code actuel. Code mort.

---

## Fichier: `src/animation.lua`

### 🟡 Avertissements

**[animation.lua:21-26] `table.remove` dans une boucle inverse — correct mais O(n²)**
```lua
for i = #activeAnimations, 1, -1 do
    if activeAnimations[i].done then
        table.remove(activeAnimations, i) -- O(n) shift
    end
end
```
Acceptable vu le faible nombre d'animations simultanées (< 10).

**[animation.lua:45] `looping` est assigné mais jamais lu dans `Tween:update`**
```lua
anim.looping = true  -- jamais utilisé par le système de tween
```
`createBlink` crée un tween avec `looping = true` mais `Tween:update` n'implémente pas de boucle. L'animation s'arrêtera à la fin.
**Impact :** Le clignotement des cellules gagnantes utilise `Renderer.drawWinHighlight` avec un timer, pas cette animation. Code mort.

---

## Fichier: `src/particles.lua`

### ✅ Points Corrects
- Itération inverse pour suppression (L43) — correct
- `math.floor` sur les positions de dessin — pixel-perfect
- Multiplicateurs `dt` sur vélocité et vie — correct

### 🟡 Avertissements

**[particles.lua:49-51] `table.remove` en boucle inverse — même remarque que animation.lua**
Acceptable vu que les particules restent < ~100 en pratique.

---

## Fichier: `src/renderer.lua`, `src/screenshake.lua`, `src/tween.lua`

### ✅ Points Corrects
- `renderer.lua` : Aucune allocation dans `draw`, constantes précalculées (L10-17)
- `screenshake.lua` : Mouvements multipliés par `dt`, décroissance temporelle correcte
- `tween.lua` : Easing functions pures, pas d'allocation, `getValue()` safe quand `done`
- Aucune ressource chargée dans les fonctions de dessin

---

## Fichier: `src/ui.lua`

### 🟡 Avertissements

**[ui.lua:15,37] Largeur de canvas hardcodée à 160**
```lua
local x = math.floor((160 - textW) / 2)
```
Devrait utiliser `PixelCanvas.GAME_W`. Pas un bug tant que la résolution ne change pas, mais fragile.

---

## Fichier: `src/colors.lua`

### ✅ Entièrement correct
- Tables de couleurs créées une seule fois au `require`
- `Colors.set` encapsule bien `love.graphics.setColor`

---

## Fichier: `src/shaders.lua` + GLSL

### ✅ Points Corrects
- Shaders compilés une seule fois dans `init()`
- Guards `hasUniform` avant chaque `send` — protège contre les optimisations du compilateur GLSL
- `reset()` restore le pipeline par défaut

### 🟡 Avertissements

**[shaders.lua] `init()` n'est jamais appelé dans le codebase**
`shaders.init()` n'apparaît nulle part dans `main.lua` ni dans aucun état. Les 4 shaders sont compilés mais jamais utilisés en runtime.
**Impact :** Code mort. Les shaders ne s'affichent pas.

---

## Fichier: `src/network.lua`

### ✅ Points Corrects
- Thread-safe via channels LÖVE
- Callbacks nettoyés après invocation (L116)
- Redémarrage automatique du thread en cas d'erreur (L99-102)
- `maxPerFrame = 10` empêche le flood de callbacks

### 🟡 Avertissements

**[network.lua:14] `callbacks` table grandit sans limite si les réponses n'arrivent jamais**
Si le serveur ne répond pas, les callbacks s'accumulent. Pas de TTL.
**Impact :** Faible — les fonctions Lua sont petites, mais peut causer des fuites lentes sur de très longues sessions.

**[network.lua:193] `now()` envoyé comme string au lieu d'être interprété par Supabase**
```lua
body[field] = "now()"
```
Supabase REST interprète `"now()"` comme une string littérale, PAS comme la fonction SQL `now()`. Le heartbeat stocke la string `"now()"` au lieu d'un timestamp.
**Impact :** 🔴 **C'est en fait un bug critique dans `online_game.lua:193` et `online_game_over.lua:196-197`** — la détection de forfait compare des timestamps. Si un des deux est `"now()"`, le parsing ISO échouera silencieusement (le `match` retourne nil), et le forfait ne sera jamais déclenché.

Cependant, `lobby.lua:92` utilise `os.date("!%Y-%m-%dT%H:%M:%SZ")` correctement. L'incohérence est entre les fichiers.

---

## Fichier: `src/net_thread.lua`

### 🟡 Avertissements

**[net_thread.lua:10] `loadstring` déprécié en Lua 5.2+**
```lua
local json = assert(loadstring(jsonCode))()
```
LÖVE 11.x utilise LuaJIT (Lua 5.1 compat), donc `loadstring` existe. Correct pour cette version.

**[net_thread.lua:39] `io.popen` — appel bloquant dans le thread**
Bloque le thread worker, pas le game loop. Architecture correcte.

**[net_thread.lua:23-28] Fichier temporaire partagé `_net_body.tmp`**
Si deux requêtes sont envoyées très rapidement, la seconde pourrait écraser le body de la première avant que curl ne le lise. Mais le thread traite séquentiellement, donc OK.

---

## Fichier: `src/json.lua`

### ✅ Points Corrects
- Gère NaN, Infinity → `null`
- Détection array/object robuste
- Décodage d'escape sequences unicode basique

### 🟡 Avertissements

**[json.lua:179] `null` JSON décodé en `nil` Lua — perte d'information**
```lua
elseif c == 'n' then return nil, pos + 4
```
`json.null` existe (L6) mais n'est pas utilisé en décodage. Un champ JSON `null` disparaît de la table Lua. Ce n'est pas critique pour ce projet car les champs null ne sont pas testés en décodage.

---

## Fichier: `src/states/menu.lua`

### ✅ Points Corrects
- Navigation wrap-around (L182, 186)
- État `menuPhase` bien réinitialisé dans `enter()` (L27)
- Particles nettoyées dans `enter` et `exit`

### 🟡 Avertissements

**[menu.lua:12] Variables de module (upvalues) — état persistant entre visites**
`timer`, `titleBounce`, `selectedOption`, etc. sont des upvalues de module. Elles sont correctement réinitialisées dans `enter()`. ✅

---

## Fichier: `src/states/game.lua`

### ✅ Points Corrects
- Drop animation avec `Tween` — pièce placée seulement quand l'anim est finie (L119)
- Input bloqué pendant le tour de l'AI (L309)
- AI scanning animation (L100-101) — bon feel
- `doDrop` vérifie `dropping` et `gameOver` (L267)
- `dt` correctement utilisé partout

### 🟡 Avertissements

**[game.lua:100] Scan animation non-déterministe**
```lua
local scanCol = math.floor(timer * 8) % Board.COLS + 1
```
Utilise `timer` (accumulé depuis `enter`) — peut montrer la même colonne au restart si timer est grand. Acceptable visuellement.

---

## Fichier: `src/states/game_over.lua`

### ✅ Entièrement correct
- Particles de célébration correctes
- Layout pixel-art crown bien calculé
- Options de rematch fonctionnelles
- Mode CPU/Human correctement propagé

---

## Fichier: `src/states/lobby.lua`

### 🟡 Avertissements

**[lobby.lua:61-63] `exit()` ne nettoie pas le réseau si on quitte le lobby**
```lua
function Lobby:exit()
    Particles.clear()
    -- Pas de cleanup du game créé sur Supabase
end
```
Si le joueur crée un game puis quitte (ESC), le game reste en état `"waiting"` sur Supabase indéfiniment. Le TODO L415 le confirme.

**[lobby.lua:10] `json` est `require` mais jamais utilisé**
```lua
local json = require("src.json")  -- inutilisé
```

---

## Fichier: `src/states/online_game.lua`

### 🔴 Bugs Critiques

**[online_game.lua:192-194] Heartbeat envoie `"now()"` comme string littérale**
```lua
body[field] = "now()"
body["updated_at"] = "now()"
```
Supabase REST stocke la string `"now()"`, pas un timestamp. Conséquence : `checkForfeit` (L285-286) ne pourra jamais parser ce timestamp, rendant la détection de forfait **non-fonctionnelle** pour le joueur qui envoie ces heartbeats.

**Correction :**
```lua
local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
body[field] = timestamp
body["updated_at"] = timestamp
```

### 🟡 Avertissements

**[online_game.lua:298] Comparaison de forfeit basée sur la différence entre MON heartbeat et celui de l'adversaire**
```lua
local elapsed = myHbTime - hbTime
```
Cela suppose que les deux timestamps sont dans le même fuseau horaire. Si Supabase stocke en UTC et `os.time()` retourne en local, l'offset peut fausser la comparaison.
**Impact :** Sur la plupart des systèmes, `os.date("!...")` produit de l'UTC, et la DB aussi. OK si cohérent.

**[online_game.lua:256] Détection de fin de partie côté serveur sans winCells**
Quand le serveur signale `status = "finished"`, le client ne récupère pas les cellules gagnantes. La mise en surbrillance des pièces gagnantes ne s'affichera pas pour l'observateur d'un forfait.

---

## Fichier: `src/states/online_game_over.lua`

### 🔴 Bugs Critiques

**[online_game_over.lua:50+124] Double déclaration de `transitioning`**
```lua
-- L50 (dans enter):
transitioning  = false   -- écrit dans la globale accidentelle !

-- L124 (module-level):
local transitioning = false  -- la vraie locale
```
La ligne 50 assigne une **variable globale** `transitioning` (pas de `local`, et elle est assignée AVANT la déclaration `local` à L124). La variable locale L124 est celle utilisée par `pollRematch`. La globale L50 est un no-op silencieux qui pollue `_G`.

**Correction :** Supprimer L50 ou le replacer après la déclaration locale, ou mieux :
```lua
-- Déplacer la déclaration local avant enter()
local transitioning = false

function OnlineGameOver:enter(params)
    -- ...
    transitioning = false  -- maintenant réfère la locale
```

**[online_game_over.lua:196-197] `"now()"` comme string — même bug que online_game.lua**
```lua
player1_heartbeat = "now()",
player2_heartbeat = "now()",
```

### 🟡 Avertissements

**[online_game_over.lua:184] `require("src.json")` re-require inutile**
```lua
local json = require("src.json")  -- déjà en cache, mais redondant
```
`json` n'est pas importé au niveau du module dans ce fichier (contrairement à `lobby.lua`). Fonctionne grâce au cache de `require`, mais devrait être au top du fichier.

---

## Fichier: `src/supabase_config.lua`

### 🔴 Bug Critique

**[supabase_config.lua:6] Clé API Supabase anon_key en dur dans le code source**
```lua
anon_key = "eyJhbGci..."
```
Si ce repo est public, la clé est exposée. Les clés `anon` de Supabase sont semi-publiques (RLS les protège), mais c'est une mauvaise pratique.
**Recommandation :** Charger depuis une variable d'environnement ou un fichier `.env` exclu du git.

---

# 🧪 Plan de Test Global

## Tests Manuels
1. **Forfait online** : Vérifier que le forfait se déclenche après 30s (⚠️ probablement cassé par le bug `"now()"`)
2. **Rematch online** : Vérifier que les deux joueurs reprennent le contrôle après un rematch
3. **AI difficulté 10** : Mesurer le temps de réponse (risque de lag)
4. **Fenêtre minimisée** : Vérifier que `scale` ne passe pas à 0
5. **État invalide** : Appeler `stateMachine:switch("nonexistent")` — devrait crash proprement

## Tests Automatisés (busted)

```lua
-- test_board.lua
describe("Board", function()
    local Board = require("src.board")
    
    it("should detect horizontal win", function()
        local b = Board:new()
        for col = 1, 4 do b.grid[col][6] = 1 end
        assert.truthy(b:checkWin(4, 6))
    end)
    
    it("should detect vertical win", function()
        local b = Board:new()
        for row = 3, 6 do b.grid[1][row] = 2 end
        assert.truthy(b:checkWin(1, 6))
    end)
    
    it("should return nil for no win", function()
        local b = Board:new()
        b.grid[1][6] = 1; b.grid[2][6] = 2; b.grid[3][6] = 1
        assert.falsy(b:checkWin(3, 6))
    end)
    
    it("should detect full board", function()
        local b = Board:new()
        for c = 1, 7 do for r = 1, 6 do b.grid[c][r] = (c+r) % 2 + 1 end end
        assert.truthy(b:isFull())
    end)
    
    it("should reject drop in full column", function()
        local b = Board:new()
        for r = 1, 6 do b.grid[1][r] = 1 end
        assert.falsy(b:canDrop(1))
        assert.is_nil(b:drop(1, 2))
    end)
    
    it("getCell should return -1 out of bounds", function()
        local b = Board:new()
        assert.equals(-1, b:getCell(0, 1))
        assert.equals(-1, b:getCell(8, 1))
    end)
end)
```

```lua
-- test_ai.lua
describe("AI", function()
    local Board = require("src.board")
    local AI = require("src.ai")
    
    it("should block opponent winning move", function()
        local b = Board:new()
        b.grid[1][6] = 2; b.grid[2][6] = 2; b.grid[3][6] = 2
        local ai = AI:new(5)
        local col = ai:chooseColumn(b, 1)
        assert.equals(4, col)  -- must block column 4
    end)
    
    it("should take immediate win", function()
        local b = Board:new()
        b.grid[1][6] = 1; b.grid[2][6] = 1; b.grid[3][6] = 1
        local ai = AI:new(5)
        local col = ai:chooseColumn(b, 1)
        assert.equals(4, col)
    end)
end)
```

## love.errorhandler

Le projet **n'implémente pas** `love.errorhandler`. Proposition :

```lua
-- Dans main.lua
function love.errorhandler(msg)
    local trace = debug.traceback(tostring(msg), 2)
    print("[CRASH] " .. trace)
    -- Sauvegarder le crashlog
    pcall(function()
        love.filesystem.write("crash.log", 
            os.date() .. "\n" .. trace)
    end)
    -- Cleanup réseau
    pcall(function()
        local net = require("src.network")
        if net.isReady() then net.shutdown() end
    end)
    return love.errorhandler_default and love.errorhandler_default(msg)
end
```

---

# 📊 Résumé Exécutif

| Métrique | Valeur |
|----------|--------|
| Fichiers analysés | **23** (17 Lua + 4 GLSL + conf.lua + main.lua) |
| 🔴 Bugs critiques | **5** |
| 🟡 Avertissements | **14** |
| Code mort détecté | 3 fonctions (`playClone`, `createBlink.looping`, `shaders.init` non-appelé) |

## 🚨 Top 3 — Priorité Maximale

### 1. 🔴 Heartbeat `"now()"` — Forfait online cassé
**Fichiers :** `online_game.lua:193`, `online_game_over.lua:196-197`
`"now()"` est stocké comme string, pas comme timestamp SQL. La détection de forfait par timeout ne fonctionne pas. **Corriger en utilisant `os.date("!%Y-%m-%dT%H:%M:%SZ")`.**

### 2. 🔴 Variable globale accidentelle `transitioning`
**Fichier :** `online_game_over.lua:50`
Assignation d'une globale avant la déclaration `local` à L124. Cause un état incohérent potentiel lors d'un rematch rapide — la locale `transitioning` ne serait jamais réinitialisée par `enter()`.

### 3. 🔴 Performance AI — `isTerminal` scanne tout le plateau
**Fichier :** `ai.lua:119-134`
O(42 × 4) par nœud minimax × milliers de nœuds. Combiné avec les allocations de tables dans `checkWin` et `scorePosition`, provoque des lags à haute difficulté. **Corriger en passant le dernier coup joué à `isTerminal`.**
