# Audit Sample — Unity Platformer Jump

This example demonstrates the full game-feel-optimizer pipeline applied to a basic Unity jump.

---

## Input — User Submission

> "My platformer jump feels floaty and unresponsive. Here's my code."

**Genre**: 2D Platformer  
**Engine**: Unity (C#)  
**Platform**: PC

```csharp
// PlayerController.cs — BEFORE audit
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    public float speed = 5f;
    public float jumpForce = 10f;
    private Rigidbody2D rb;
    private bool isGrounded;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
    }

    void Update()
    {
        float moveX = Input.GetAxis("Horizontal");
        rb.velocity = new Vector2(moveX * speed, rb.velocity.y);

        if (Input.GetKeyDown(KeyCode.Space) && isGrounded)
        {
            rb.velocity = new Vector2(rb.velocity.x, jumpForce);
            isGrounded = false;
        }
    }

    void OnCollisionEnter2D(Collision2D col)
    {
        isGrounded = true;
    }
}
```

---

## Step 2 — Diagnosis

| Issue | Pillar | Detail |
|---|---|---|
| Symmetric gravity | Kinematics | Same gravity up and down → floaty apex and descent |
| No coyote time | Input Response | Missed jumps when walking off edges |
| No input buffer | Input Response | Jump fails if pressed 1 frame too early |
| `GetAxis` smoothing | Input Response | Horizontal input has built-in acceleration lag |
| No squash/stretch | Sensory Feedback | Jump and landing have zero visual feedback |
| No landing SFX | Reactive Audio | Landing is silent |
| No variable jump height | Kinematics | Tap and hold produce same arc |

---

## Step 3 — Scoring

| Pillar                  | Score /10 | Status | Priority |
|-------------------------|-----------|--------|----------|
| Input Response          | 3         | ❌     | Critique |
| Kinematics              | 3         | ❌     | Critique |
| Sensory Feedback        | 1         | ❌     | Haute    |
| Reactive Audio          | 2         | ❌     | Haute    |
| Visual Readability      | 5         | ⚠️     | Basse    |
| Psychological Reward    | 4         | ⚠️     | Basse    |
| Tonal Coherence         | 5         | ⚠️     | Basse    |

**Overall game feel score: 3.3 / 10**

---

## Step 4 — Recommendations

### 1. [CRITIQUE] Fix gravity asymmetry — Fall faster than rise

**Reference**: *Celeste* uses a fall gravity multiplier of ~2.5× to make descent feel snappy.

```csharp
// --- Tunable Constants ---
const float FALL_GRAVITY_MULTIPLIER = 2.5f;
const float LOW_JUMP_GRAVITY_MULTIPLIER = 3.5f;  // for variable jump height
const float BASE_GRAVITY_SCALE = 3f;

// In Update(), after jump:
if (rb.velocity.y < 0)
{
    // Falling — apply heavier gravity
    rb.gravityScale = BASE_GRAVITY_SCALE * FALL_GRAVITY_MULTIPLIER;
}
else if (rb.velocity.y > 0 && !Input.GetKey(KeyCode.Space))
{
    // Rising but jump button released — cut jump short
    rb.gravityScale = BASE_GRAVITY_SCALE * LOW_JUMP_GRAVITY_MULTIPLIER;
}
else
{
    rb.gravityScale = BASE_GRAVITY_SCALE;
}
```

### 2. [CRITIQUE] Add coyote time and input buffering

**Reference**: *Celeste* — 6 frames coyote time, 6 frames jump buffer.

```csharp
// --- Tunable Constants ---
const float COYOTE_TIME_DURATION = 0.1f;    // ~6 frames at 60 FPS
const float JUMP_BUFFER_DURATION = 0.1f;    // ~6 frames at 60 FPS

private float _coyoteTimer;
private float _jumpBufferTimer;

void Update()
{
    // Coyote time
    if (isGrounded)
        _coyoteTimer = COYOTE_TIME_DURATION;
    else
        _coyoteTimer -= Time.deltaTime;

    // Jump buffer
    if (Input.GetKeyDown(KeyCode.Space))
        _jumpBufferTimer = JUMP_BUFFER_DURATION;
    else
        _jumpBufferTimer -= Time.deltaTime;

    // Execute jump if either timer is valid
    if (_jumpBufferTimer > 0f && _coyoteTimer > 0f)
    {
        rb.velocity = new Vector2(rb.velocity.x, JUMP_FORCE);
        _jumpBufferTimer = 0f;
        _coyoteTimer = 0f;
    }
}
```

### 3. [CRITIQUE] Replace GetAxis with GetAxisRaw

**Reference**: *Super Meat Boy* — instant directional response, zero input smoothing.

```csharp
// BEFORE (smoothed, adds ~6 frames of perceived lag):
float moveX = Input.GetAxis("Horizontal");

// AFTER (instant response):
const float MOVE_SPEED = 8f;
float moveX = Input.GetAxisRaw("Horizontal");
rb.velocity = new Vector2(moveX * MOVE_SPEED, rb.velocity.y);
```

### 4. [HAUTE] Add squash & stretch on jump and landing

**Reference**: *Hollow Knight* — subtle squash on landing (1.2×, 0.8y), stretch on jump (0.85×, 1.15y).

```csharp
// See references/snippets-by-engine.md for full SquashStretch component.
// Call on jump:
const float JUMP_STRETCH_X = 0.85f;
const float JUMP_STRETCH_Y = 1.15f;
// Call on landing:
const float LAND_SQUASH_X = 1.2f;
const float LAND_SQUASH_Y = 0.8f;
```

### 5. [HAUTE] Add landing dust particles and SFX

**Reference**: *Celeste* — small dust puff (6–8 particles), soft thud SFX with ±8% pitch variation.

```csharp
// --- Tunable Constants ---
const int LANDING_PARTICLE_COUNT = 8;
const float LANDING_SFX_PITCH_MIN = 0.92f;
const float LANDING_SFX_PITCH_MAX = 1.08f;

void OnLanding()
{
    // Particles
    landingPS.Emit(LANDING_PARTICLE_COUNT);

    // SFX with pitch variation
    landingSFX.pitch = Random.Range(LANDING_SFX_PITCH_MIN, LANDING_SFX_PITCH_MAX);
    landingSFX.Play();
}
```

---

## Step 5 — Validation Plan

| Recommendation | Validation Target | Method |
|---|---|---|
| Gravity asymmetry | Fall time from apex ≤ 60% of rise time | Measure with Time.time logs |
| Coyote time | Player can jump up to 6 frames after leaving ground | Frame-step in editor |
| Input buffer | Jump queued within 100ms window is executed | Log buffer hits in console |
| GetAxisRaw | Input-to-movement ≤ 1 frame | Frame-by-frame replay |
| Squash & stretch | Visual deformation visible on jump/land | Screen recording review |
| Landing particles + SFX | Particles and sound trigger on every landing | Playtester confirmation (3 testers, rate impact 1–5) |

**Target overall score after fixes: 7+ / 10**

---

## Full Corrected Code

```csharp
// PlayerController.cs — AFTER audit
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    // --- Movement Constants ---
    const float MOVE_SPEED = 8f;
    const float JUMP_FORCE = 14f;

    // --- Gravity Constants ---
    const float BASE_GRAVITY_SCALE = 3f;
    const float FALL_GRAVITY_MULTIPLIER = 2.5f;
    const float LOW_JUMP_GRAVITY_MULTIPLIER = 3.5f;

    // --- Input Forgiveness Constants ---
    const float COYOTE_TIME_DURATION = 0.1f;
    const float JUMP_BUFFER_DURATION = 0.1f;

    // --- Feedback Constants ---
    const float JUMP_STRETCH_X = 0.85f;
    const float JUMP_STRETCH_Y = 1.15f;
    const float LAND_SQUASH_X = 1.2f;
    const float LAND_SQUASH_Y = 0.8f;
    const int LANDING_PARTICLE_COUNT = 8;
    const float LANDING_SFX_PITCH_MIN = 0.92f;
    const float LANDING_SFX_PITCH_MAX = 1.08f;

    [SerializeField] private ParticleSystem landingPS;
    [SerializeField] private AudioSource landingSFX;
    [SerializeField] private SquashStretch squashStretch;

    private Rigidbody2D rb;
    private bool isGrounded;
    private bool wasGrounded;
    private float coyoteTimer;
    private float jumpBufferTimer;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
        rb.gravityScale = BASE_GRAVITY_SCALE;
    }

    void Update()
    {
        // --- Horizontal movement (instant response) ---
        float moveX = Input.GetAxisRaw("Horizontal");
        rb.velocity = new Vector2(moveX * MOVE_SPEED, rb.velocity.y);

        // --- Coyote time ---
        if (isGrounded)
            coyoteTimer = COYOTE_TIME_DURATION;
        else
            coyoteTimer -= Time.deltaTime;

        // --- Jump buffer ---
        if (Input.GetKeyDown(KeyCode.Space))
            jumpBufferTimer = JUMP_BUFFER_DURATION;
        else
            jumpBufferTimer -= Time.deltaTime;

        // --- Jump execution ---
        if (jumpBufferTimer > 0f && coyoteTimer > 0f)
        {
            rb.velocity = new Vector2(rb.velocity.x, JUMP_FORCE);
            jumpBufferTimer = 0f;
            coyoteTimer = 0f;
            squashStretch?.ApplyStretch();
        }

        // --- Variable jump height + fast fall ---
        if (rb.velocity.y < 0)
        {
            rb.gravityScale = BASE_GRAVITY_SCALE * FALL_GRAVITY_MULTIPLIER;
        }
        else if (rb.velocity.y > 0 && !Input.GetKey(KeyCode.Space))
        {
            rb.gravityScale = BASE_GRAVITY_SCALE * LOW_JUMP_GRAVITY_MULTIPLIER;
        }
        else
        {
            rb.gravityScale = BASE_GRAVITY_SCALE;
        }

        // --- Landing detection ---
        if (isGrounded && !wasGrounded)
        {
            OnLanding();
        }
        wasGrounded = isGrounded;
    }

    void OnLanding()
    {
        squashStretch?.ApplySquash();
        landingPS?.Emit(LANDING_PARTICLE_COUNT);
        if (landingSFX != null)
        {
            landingSFX.pitch = Random.Range(LANDING_SFX_PITCH_MIN, LANDING_SFX_PITCH_MAX);
            landingSFX.Play();
        }
    }

    void OnCollisionEnter2D(Collision2D col)
    {
        isGrounded = true;
    }

    void OnCollisionExit2D(Collision2D col)
    {
        isGrounded = false;
    }
}
```
