# Game Feel Snippets by Engine

All snippets use **named constants** at the top for easy tuning. Adapt values to your genre using [game-feel-pillars.md](game-feel-pillars.md).

---

## 1. Screenshake

### Unity (C#)

```csharp
using UnityEngine;
using System.Collections;

public class ScreenShake : MonoBehaviour
{
    // --- Tunable Constants ---
    const float SCREENSHAKE_DURATION = 0.15f;      // seconds
    const float SCREENSHAKE_INTENSITY = 8f;         // pixels (world units)
    const float SCREENSHAKE_DECAY_RATE = 5f;        // exponential decay speed

    private Vector3 _originalPos;
    private float _currentDuration;
    private float _currentIntensity;

    public void Shake(float duration = SCREENSHAKE_DURATION, float intensity = SCREENSHAKE_INTENSITY)
    {
        _originalPos = transform.localPosition;
        _currentDuration = duration;
        _currentIntensity = intensity;
        StopAllCoroutines();
        StartCoroutine(ShakeRoutine());
    }

    private IEnumerator ShakeRoutine()
    {
        float elapsed = 0f;
        while (elapsed < _currentDuration)
        {
            float decay = 1f - Mathf.Pow(elapsed / _currentDuration, SCREENSHAKE_DECAY_RATE);
            float offsetX = Random.Range(-1f, 1f) * _currentIntensity * decay;
            float offsetY = Random.Range(-1f, 1f) * _currentIntensity * decay;
            transform.localPosition = _originalPos + new Vector3(offsetX, offsetY, 0f);
            elapsed += Time.unscaledDeltaTime;
            yield return null;
        }
        transform.localPosition = _originalPos;
    }
}
```

### Godot (GDScript)

```gdscript
extends Camera2D

# --- Tunable Constants ---
const SCREENSHAKE_DURATION := 0.15    # seconds
const SCREENSHAKE_INTENSITY := 8.0    # pixels
const SCREENSHAKE_DECAY_RATE := 5.0   # exponential decay speed

var _shake_timer := 0.0
var _shake_intensity := 0.0

func shake(duration := SCREENSHAKE_DURATION, intensity := SCREENSHAKE_INTENSITY) -> void:
    _shake_timer = duration
    _shake_intensity = intensity

func _process(delta: float) -> void:
    if _shake_timer > 0:
        _shake_timer -= delta
        var decay := pow(_shake_timer / SCREENSHAKE_DURATION, SCREENSHAKE_DECAY_RATE)
        offset = Vector2(
            randf_range(-1.0, 1.0) * _shake_intensity * decay,
            randf_range(-1.0, 1.0) * _shake_intensity * decay
        )
    else:
        offset = Vector2.ZERO
```

### Unreal (Blueprint Pseudocode)

```
// Node: Custom Event "Shake"
// Inputs: Duration (float, default 0.15), Intensity (float, default 8.0)
//
// CONSTANTS (exposed as variables with Category "Screenshake"):
//   SCREENSHAKE_DECAY_RATE = 5.0
//
// 1. Set Timer "ShakeElapsed" = 0
// 2. Set "ShakeDuration" = Duration, "ShakeIntensity" = Intensity
// 3. On Tick (while ShakeElapsed < ShakeDuration):
//    a. Decay = Power(1 - ShakeElapsed / ShakeDuration, SCREENSHAKE_DECAY_RATE)
//    b. OffsetX = RandomFloatInRange(-1, 1) * ShakeIntensity * Decay
//    c. OffsetY = RandomFloatInRange(-1, 1) * ShakeIntensity * Decay
//    d. SetActorRelativeLocation(OriginalPos + (OffsetX, OffsetY, 0))
//    e. ShakeElapsed += DeltaTime (unscaled)
// 4. When done: ResetActorLocation to OriginalPos
//
// Alternative: Use "Client Play Camera Shake" with UCameraShakeBase subclass
```

---

## 2. Hitstop (Freeze Frames)

### Unity (C#)

```csharp
using UnityEngine;
using System.Collections;

public class HitstopManager : MonoBehaviour
{
    // --- Tunable Constants ---
    const int HITSTOP_FRAMES = 4;                           // frames at 60 FPS
    const float HITSTOP_DURATION = HITSTOP_FRAMES / 60f;    // auto-calculated
    const float HITSTOP_TIMESCALE = 0.0f;                   // full freeze

    public static HitstopManager Instance;

    private void Awake() => Instance = this;

    public void Freeze(int frames = HITSTOP_FRAMES)
    {
        StopAllCoroutines();
        StartCoroutine(FreezeRoutine(frames / 60f));
    }

    private IEnumerator FreezeRoutine(float duration)
    {
        Time.timeScale = HITSTOP_TIMESCALE;
        yield return new WaitForSecondsRealtime(duration);
        Time.timeScale = 1f;
    }
}

// Usage: HitstopManager.Instance.Freeze();
```

### Godot (GDScript)

```gdscript
# Autoload singleton: HitstopManager
extends Node

# --- Tunable Constants ---
const HITSTOP_FRAMES := 4          # frames at 60 FPS
const HITSTOP_TIMESCALE := 0.0     # full freeze (0.05 for near-freeze)

func freeze(frames := HITSTOP_FRAMES) -> void:
    Engine.time_scale = HITSTOP_TIMESCALE
    await get_tree().create_timer(frames / 60.0, true, false, true).timeout
    Engine.time_scale = 1.0

# Usage: HitstopManager.freeze()
```

### Unreal (Blueprint Pseudocode)

```
// Node: Custom Event "Hitstop"
// Input: Frames (int, default 4)
//
// CONSTANTS:
//   HITSTOP_TIMESCALE = 0.01  (Unreal doesn't support 0.0 timeDilation)
//
// 1. Set Global Time Dilation = HITSTOP_TIMESCALE
// 2. Delay (Frames / 60.0) seconds (use Set Timer by Event, NOT Delay node)
// 3. Set Global Time Dilation = 1.0
```

---

## 3. Squash & Stretch

### Unity (C#)

```csharp
using UnityEngine;
using System.Collections;

public class SquashStretch : MonoBehaviour
{
    // --- Tunable Constants ---
    const float SQUASH_SCALE_X = 1.3f;      // wider on landing
    const float SQUASH_SCALE_Y = 0.7f;      // shorter on landing
    const float STRETCH_SCALE_X = 0.8f;     // narrower when jumping/falling
    const float STRETCH_SCALE_Y = 1.2f;     // taller when jumping/falling
    const float RETURN_SPEED = 10f;          // lerp speed back to normal

    private Vector3 _targetScale = Vector3.one;

    public void ApplySquash()
    {
        _targetScale = new Vector3(SQUASH_SCALE_X, SQUASH_SCALE_Y, 1f);
    }

    public void ApplyStretch()
    {
        _targetScale = new Vector3(STRETCH_SCALE_X, STRETCH_SCALE_Y, 1f);
    }

    private void Update()
    {
        transform.localScale = Vector3.Lerp(transform.localScale, Vector3.one, RETURN_SPEED * Time.deltaTime);
        if (_targetScale != Vector3.one)
        {
            transform.localScale = _targetScale;
            _targetScale = Vector3.one;
        }
    }
}

// Usage: On landing → ApplySquash(). On jump → ApplyStretch().
```

### Godot (GDScript)

```gdscript
extends Node2D

# --- Tunable Constants ---
const SQUASH_SCALE := Vector2(1.3, 0.7)
const STRETCH_SCALE := Vector2(0.8, 1.2)
const RETURN_SPEED := 10.0

@onready var sprite: Sprite2D = $Sprite2D

func squash() -> void:
    sprite.scale = SQUASH_SCALE

func stretch() -> void:
    sprite.scale = STRETCH_SCALE

func _process(delta: float) -> void:
    sprite.scale = sprite.scale.lerp(Vector2.ONE, RETURN_SPEED * delta)

# Usage: On landing → squash(). On jump → stretch().
```

### Unreal (Blueprint Pseudocode)

```
// On Character sprite/mesh component:
//
// CONSTANTS (exposed variables):
//   SQUASH_SCALE = (1.3, 0.7, 1.0)
//   STRETCH_SCALE = (0.8, 1.2, 1.0)
//   RETURN_SPEED = 10.0
//
// Custom Event "Squash": Set MeshScale = SQUASH_SCALE
// Custom Event "Stretch": Set MeshScale = STRETCH_SCALE
//
// On Tick:
//   MeshScale = VLerp(MeshScale, (1,1,1), DeltaTime * RETURN_SPEED)
//   SetActorScale3D(MeshScale)
```

---

## 4. Particle Trail (Impact Burst)

### Unity (C#)

```csharp
using UnityEngine;

public class ImpactParticles : MonoBehaviour
{
    // --- Tunable Constants ---
    const int PARTICLE_BURST_COUNT = 12;
    const float PARTICLE_SPEED_MIN = 50f;
    const float PARTICLE_SPEED_MAX = 150f;
    const float PARTICLE_LIFETIME = 0.4f;
    const float PARTICLE_SIZE = 3f;

    [SerializeField] private ParticleSystem _impactPS;

    public void Burst(Vector3 position, Vector3 direction)
    {
        _impactPS.transform.position = position;

        var main = _impactPS.main;
        main.startLifetime = PARTICLE_LIFETIME;
        main.startSize = PARTICLE_SIZE;
        main.startSpeed = new ParticleSystem.MinMaxCurve(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX);

        var shape = _impactPS.shape;
        shape.rotation = Quaternion.LookRotation(direction).eulerAngles;

        _impactPS.Emit(PARTICLE_BURST_COUNT);
    }
}
```

### Godot (GDScript)

```gdscript
extends GPUParticles2D

# --- Tunable Constants ---
const PARTICLE_BURST_COUNT := 12
const PARTICLE_LIFETIME := 0.4       # seconds
const PARTICLE_SPEED_MIN := 50.0
const PARTICLE_SPEED_MAX := 150.0

func burst(pos: Vector2, dir: Vector2 = Vector2.UP) -> void:
    global_position = pos
    rotation = dir.angle()
    amount = PARTICLE_BURST_COUNT
    lifetime = PARTICLE_LIFETIME
    # Set initial_velocity in the ParticleProcessMaterial:
    # min = PARTICLE_SPEED_MIN, max = PARTICLE_SPEED_MAX
    emitting = true
    one_shot = true

# Usage: impact_particles.burst(hit_position, hit_normal)
```

### Unreal (Blueprint Pseudocode)

```
// Niagara System "NS_ImpactBurst"
//
// CONSTANTS (User Parameters on the system):
//   PARTICLE_BURST_COUNT = 12
//   PARTICLE_SPEED_MIN = 50.0
//   PARTICLE_SPEED_MAX = 150.0
//   PARTICLE_LIFETIME = 0.4
//   PARTICLE_SIZE = 3.0
//
// Emitter settings:
//   Spawn: Burst mode, Count = PARTICLE_BURST_COUNT
//   Lifetime: PARTICLE_LIFETIME
//   Initial Velocity: RandomRange(SPEED_MIN, SPEED_MAX) in cone direction
//   Sprite Size: PARTICLE_SIZE
//
// Blueprint usage:
//   Spawn System at Location(HitPosition)
//   Set Niagara Variable "Direction" = HitNormal
```

---

## Usage Notes

- **Always profile after adding effects** — particles and coroutines can impact performance on mobile
- **Layer effects for maximum impact**: hit = hitstop + screenshake + flash + particles + SFX (all in the same frame)
- **Expose all constants** in inspector/editor — designers need to iterate without recompiling
- **Use unscaled time** for screenshake and hitstop to avoid conflicts with timescale manipulation
