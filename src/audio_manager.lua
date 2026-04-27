-- Audio Manager
-- Procedural chiptune SFX synthesized at runtime (no external files needed)

local AudioManager = {}

local sources = {}

--- Generate a square wave beep
local function generateSquareWave(freq, duration, volume)
    local rate = 44100
    local samples = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)
    local period = math.floor(rate / freq)
    for i = 0, samples - 1 do
        local t = i / samples
        local envelope = 1 - t  -- linear fade out
        local sample = (i % period < period / 2) and 1 or -1
        soundData:setSample(i, sample * volume * envelope)
    end
    return love.audio.newSource(soundData)
end

--- Generate a sine wave tone
local function generateSineWave(freq, duration, volume)
    local rate = 44100
    local samples = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)
    local tau = math.pi * 2
    for i = 0, samples - 1 do
        local t = i / samples
        local envelope = 1 - t * t  -- quadratic fade out
        local sample = math.sin(tau * freq * i / rate)
        soundData:setSample(i, sample * volume * envelope)
    end
    return love.audio.newSource(soundData)
end

--- Generate a noise burst (for impact sounds)
local function generateNoise(duration, volume)
    local rate = 44100
    local samples = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / samples
        local envelope = (1 - t) * (1 - t)
        local sample = (love.math.random() * 2 - 1)
        soundData:setSample(i, sample * volume * envelope)
    end
    return love.audio.newSource(soundData)
end

--- Generate a sweep (rising or falling pitch)
local function generateSweep(freqStart, freqEnd, duration, volume)
    local rate = 44100
    local samples = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)
    local tau = math.pi * 2
    local phase = 0
    for i = 0, samples - 1 do
        local t = i / samples
        local envelope = 1 - t
        local freq = freqStart + (freqEnd - freqStart) * t
        phase = phase + tau * freq / rate
        local sample = math.sin(phase)
        soundData:setSample(i, sample * volume * envelope)
    end
    return love.audio.newSource(soundData)
end

--- Generate an arpeggio (quick sequence of notes)
local function generateArpeggio(baseFreq, intervals, noteDuration, volume)
    local rate = 44100
    local totalDuration = noteDuration * #intervals
    local samples = math.floor(rate * totalDuration)
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)
    local tau = math.pi * 2
    local phase = 0
    for i = 0, samples - 1 do
        local t = i / samples
        local noteIdx = math.min(math.floor(i / (rate * noteDuration)) + 1, #intervals)
        local freq = baseFreq * (2 ^ (intervals[noteIdx] / 12))
        local noteT = (i % math.floor(rate * noteDuration)) / (rate * noteDuration)
        local envelope = (1 - noteT * 0.5) * (1 - t * 0.3)
        phase = phase + tau * freq / rate
        local sample = (math.sin(phase) > 0) and 1 or -1  -- square wave
        soundData:setSample(i, sample * volume * envelope * 0.5)
    end
    return love.audio.newSource(soundData)
end

function AudioManager.init()
    -- Menu SFX
    sources.menuSelect = generateSquareWave(880, 0.06, 0.3)
    sources.menuConfirm = generateSweep(440, 880, 0.12, 0.35)
    sources.menuBack = generateSweep(660, 330, 0.1, 0.25)

    -- Gameplay SFX
    sources.drop = generateSweep(600, 200, 0.15, 0.3)
    sources.land = generateNoise(0.08, 0.4)
    sources.move = generateSquareWave(660, 0.03, 0.15)

    -- Win/Lose SFX
    sources.win = generateArpeggio(523.25, {0, 4, 7, 12, 16}, 0.1, 0.35)
    sources.draw = generateSweep(440, 220, 0.4, 0.2)

    -- Slider SFX
    sources.tick = generateSquareWave(1200, 0.02, 0.15)
end

--- Play a sound effect by name
function AudioManager.play(name)
    local source = sources[name]
    if source then
        source:stop()
        source:play()
    end
end

--- Play a cloned instance (for overlapping sounds)
function AudioManager.playClone(name)
    local source = sources[name]
    if source then
        local clone = source:clone()
        clone:play()
    end
end

--- Set master volume (0-1)
function AudioManager.setVolume(vol)
    love.audio.setVolume(vol or 1)
end

return AudioManager
