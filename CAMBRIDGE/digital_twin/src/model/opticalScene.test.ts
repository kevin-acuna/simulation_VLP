import { describe, expect, it } from 'vitest'
import { createOpticalParameters } from '../science'
import type { NoiseParameters, OpticalScene } from '../science/types'
import { createDefaultConfig, getFixtures, normalizeConfig, STORAGE_KEY } from './config'
import { opticalScenarioKey, toOpticalScene } from './opticalScene'
import { getPhotodiodePosition } from './receiver'
import type { LedLayout, ReceiverPlatform, TwinConfig, WorldPosition } from './types'

const platforms: ReceiverPlatform[] = ['cylinder', 'drone']
const layouts: LedLayout[] = ['grid', 'ring', 'line']
const visualChanges: [string, (config: TwinConfig) => void][] = [
  ['palette', (config) => { config.appearance.theme = 'rose' }],
  ['grid', (config) => { config.display.grid = !config.display.grid }],
  ['labels', (config) => { config.display.labels = !config.display.labels }],
  ['dimensions', (config) => { config.display.dimensions = !config.display.dimensions }],
  ['beams', (config) => { config.display.beams = !config.display.beams }],
  ['ceiling', (config) => { config.display.ceiling = !config.display.ceiling }],
  ['fixture shape', (config) => { config.lighting.shape = 'square' }],
  ['color temperature', (config) => { config.lighting.temperature = 6500 }],
  ['receiver yaw', (config) => { config.receiver.yaw = 137 }],
  ['rotor animation', (config) => { config.receiver.rotorsSpinning = false }],
]

function scenarioKey(config: TwinConfig): string {
  return opticalScenarioKey(toOpticalScene(config), config.optical.noise)
}

describe('toOpticalScene', () => {
  it('uses ceiling optical reference anchors in Z-up world coordinates without render offsets', () => {
    const config = normalizeConfig({
      room: { width: 7, depth: 5, height: 3.1 },
      positions: { 'LED-02': [1.25, -0.5] },
      optical: { halfPowerAngleDeg: 60, detectorAreaM2: 0.00005, fovHalfAngleDeg: 65 },
    })
    const scene = toOpticalScene(config)
    expect(scene.emitters).toEqual(getFixtures(config).map((fixture) => ({
      id: fixture.id,
      position: fixture.position,
      normal: [0, 0, -1],
      powerW: fixture.power,
      halfPowerAngleDeg: 60,
    })))
    expect(scene.emitters[1].position).toEqual([1.25, -0.5, 3.1])
    expect(scene.detector).toEqual({
      position: getPhotodiodePosition(config.receiver),
      normal: [0, 0, 1],
      areaM2: 0.00005,
      fovHalfAngleDeg: 65,
    })
    expect(scene.detector.position[2]).toBeCloseTo(0.341, 12)
    expect(scene.detector.position).not.toEqual(config.receiver.position)
  })

  describe.each(platforms)('%s detector', (platform) => {
    it.each<WorldPosition>([[0.7, 0, 0.3], [0, -0.6, 0.3], [0, 0, 1.2], [0.7, -0.6, 1.2]])(
      'tracks the physical PD centre at body position (%f, %f, %f)',
      (x, y, z) => {
        const baseline = normalizeConfig({ receiver: { platform } })
        const changed = normalizeConfig({ ...baseline, receiver: { ...baseline.receiver, position: [x, y, z] } })
        const before = toOpticalScene(baseline)
        const after = toOpticalScene(changed)
        expect(after.detector.position).toEqual(getPhotodiodePosition(changed.receiver))
        expect(after.detector.position[0]).toBe(x)
        expect(after.detector.position[1]).toBe(y)
        expect(after.detector.position[2]).toBeCloseTo(z + (platform === 'drone' ? 0.031 : 0.041), 12)
        expect(after.detector.position).not.toEqual(before.detector.position)
        expect(after.detector.normal).toEqual([0, 0, 1])
        expect(after.emitters).toEqual(before.emitters)
        expect(scenarioKey(changed)).toBe(scenarioKey(baseline))
      },
    )

    it.each(visualChanges)('keeps all scientific inputs and the history key unchanged by %s', (_, change) => {
      const config = normalizeConfig({ receiver: { platform, position: [0.3, -0.2, 0.8] } })
      const before = toOpticalScene(config)
      const key = scenarioKey(config)
      change(config)
      expect(toOpticalScene(config)).toEqual(before)
      expect(scenarioKey(config)).toBe(key)
    })
  })

  it('changes the PD height, not the body pose, when switching platform', () => {
    const cylinder = normalizeConfig({ receiver: { position: [0.2, -0.4, 0.8], yaw: 87 } })
    const drone = normalizeConfig({ ...cylinder, receiver: { ...cylinder.receiver, platform: 'drone' } })
    const cylinderScene = toOpticalScene(cylinder)
    const droneScene = toOpticalScene(drone)
    expect(drone.receiver.position).toEqual(cylinder.receiver.position)
    expect(cylinderScene.detector.position).toEqual(getPhotodiodePosition(cylinder.receiver))
    expect(droneScene.detector.position).toEqual(getPhotodiodePosition(drone.receiver))
    expect(cylinderScene.detector.position[2]).toBeCloseTo(0.841, 12)
    expect(droneScene.detector.position[2]).toBeCloseTo(0.831, 12)
    expect(droneScene.detector.normal).toEqual(cylinderScene.detector.normal)
    expect(droneScene.emitters).toEqual(cylinderScene.emitters)
    expect(scenarioKey(drone)).toBe(scenarioKey(cylinder))
  })

  describe.each(layouts)('%s emitter layout', (layout) => {
    it.each([1, 4, 9])('propagates %i emitters, powers, and downward normals', (count) => {
      for (const power of [0, 0.127, 2]) {
        const config = normalizeConfig({
          room: { width: 7, depth: 5, height: 3.2 },
          lighting: { count, layout, power, spacing: 0.375 },
          optical: { halfPowerAngleDeg: 50 },
        })
        const scene = toOpticalScene(config)
        const fixtures = getFixtures(config)
        expect(scene.emitters).toHaveLength(count)
        scene.emitters.forEach((emitter, index) => {
          expect(emitter).toEqual({
            id: `LED-${String(index + 1).padStart(2, '0')}`,
            position: fixtures[index].position,
            normal: [0, 0, -1],
            powerW: power,
            halfPowerAngleDeg: 50,
          })
          expect(emitter.position[2]).toBe(3.2)
        })
        expect(scene.detector.normal).toEqual([0, 0, 1])
      }
    })
  })

  it('ignores transient camera data without changing the scene or history key', () => {
    const config = createDefaultConfig()
    const withCamera = { ...config, view: 'perspective', cameraReset: 12, framing: 'fit' }
    expect(toOpticalScene(withCamera)).toEqual(toOpticalScene(config))
    expect(scenarioKey(withCamera)).toBe(scenarioKey(config))
  })

  it('preserves legacy physical settings, adds optical defaults, and adapts the migrated PD pose', () => {
    const legacy: Omit<TwinConfig, 'optical'> = {
      room: { width: 7, depth: 5, height: 3.1 },
      receiver: { position: [1.2, -0.6, 1.1], yaw: 73.25, platform: 'drone', rotorsSpinning: false },
      lighting: { count: 7, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-03': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      appearance: { theme: 'mist' },
    }
    const serialized = JSON.stringify(legacy)
    const stored = { [STORAGE_KEY]: serialized }
    const migrated = normalizeConfig(JSON.parse(stored[STORAGE_KEY]))
    const expected = { ...legacy, optical: createOpticalParameters() }
    expect(migrated).toEqual(expected)
    const scene = toOpticalScene(migrated)
    expect(scene).toEqual(toOpticalScene(expected))
    expect(scene.emitters).toHaveLength(7)
    expect(scene.emitters[2].position).toEqual([0.2, -0.4, 3.1])
    expect(scene.emitters.every(({ powerW }) => powerW === 0.127)).toBe(true)
    expect(scene.detector.position).toEqual(getPhotodiodePosition(legacy.receiver))
    expect(scene.detector.position[2]).toBeCloseTo(1.131, 12)
    expect(scenarioKey(migrated)).toBe(scenarioKey(expected))
    expect(stored[STORAGE_KEY]).toBe(serialized)
    expect(JSON.stringify(legacy)).toBe(serialized)
  })

  it('returns independent scene data without mutating the input configuration', () => {
    const config = createDefaultConfig()
    Object.freeze(config.receiver.position)
    Object.freeze(config.receiver)
    Object.freeze(config.optical.noise)
    Object.freeze(config.optical)
    Object.freeze(config)
    const before = JSON.stringify(config)
    const first = toOpticalScene(config)
    const second = toOpticalScene(config)
    expect(first).toEqual(second)
    expect(first.emitters[0].position).not.toBe(second.emitters[0].position)
    expect(first.detector.position).not.toBe(config.receiver.position)
    expect(first.detector.position).not.toBe(second.detector.position)
    first.emitters[0].powerW = 0
    first.emitters[0].position = [0, 0, 0]
    first.detector.position = [1, 1, 1]
    expect(toOpticalScene(config)).toEqual(second)
    expect(JSON.stringify(config)).toBe(before)
  })
})

describe('opticalScenarioKey', () => {
  it('is deterministic for equal values regardless of object property insertion order', () => {
    const config = createDefaultConfig()
    const scene = toOpticalScene(config)
    const noise = config.optical.noise
    const reorderedScene: OpticalScene = {
      detector: {
        fovHalfAngleDeg: scene.detector.fovHalfAngleDeg,
        areaM2: scene.detector.areaM2,
        normal: scene.detector.normal,
        position: scene.detector.position,
      },
      emitters: scene.emitters.map((emitter) => ({
        halfPowerAngleDeg: emitter.halfPowerAngleDeg,
        powerW: emitter.powerW,
        normal: emitter.normal,
        position: emitter.position,
        id: emitter.id,
      })),
    }
    const reorderedNoise: NoiseParameters = {
      seed: noise.seed,
      averagingSamples: noise.averagingSamples,
      varianceW2: noise.varianceW2,
      enabled: noise.enabled,
    }
    const before = JSON.stringify({ scene, noise })
    const key = opticalScenarioKey(scene, noise)
    expect(opticalScenarioKey(reorderedScene, reorderedNoise)).toBe(key)
    expect(opticalScenarioKey(JSON.parse(JSON.stringify(scene)), JSON.parse(JSON.stringify(noise)))).toBe(key)
    expect(JSON.parse(key).detector).toEqual({
      normal: scene.detector.normal,
      areaM2: scene.detector.areaM2,
      fovHalfAngleDeg: scene.detector.fovHalfAngleDeg,
    })
    expect(JSON.parse(key).noise).toEqual(noise)
    expect(JSON.stringify({ scene, noise })).toBe(before)
  })

  it.each<[string, (scene: OpticalScene) => void]>([
    ['emitter ID', (scene) => { scene.emitters[0].id = 'replacement' }],
    ['emitter position', (scene) => { scene.emitters[0].position = [0.2, -0.3, 2] }],
    ['emitter normal', (scene) => { scene.emitters[0].normal = [1, 0, 0] }],
    ['emitter power', (scene) => { scene.emitters[0].powerW = 0 }],
    ['emitter half-power angle', (scene) => { scene.emitters[0].halfPowerAngleDeg += 1 }],
    ['emitter count', (scene) => { scene.emitters = scene.emitters.slice(1) }],
    ['detector normal', (scene) => { scene.detector.normal = [1, 0, 0] }],
    ['detector area', (scene) => { scene.detector.areaM2 *= 2 }],
    ['detector FOV', (scene) => { scene.detector.fovHalfAngleDeg -= 1 }],
  ])('changes when %s changes', (_, change) => {
    const config = createDefaultConfig()
    const scene = toOpticalScene(config)
    const before = opticalScenarioKey(scene, config.optical.noise)
    change(scene)
    expect(opticalScenarioKey(scene, config.optical.noise)).not.toBe(before)
  })

  it.each<[string, (noise: NoiseParameters) => void]>([
    ['enabled', (noise) => { noise.enabled = !noise.enabled }],
    ['variance', (noise) => { noise.varianceW2 += 1e-16 }],
    ['averaging samples', (noise) => { noise.averagingSamples += 1 }],
    ['seed', (noise) => { noise.seed += 1 }],
  ])('changes when the noise %s changes', (_, change) => {
    const config = createDefaultConfig()
    const scene = toOpticalScene(config)
    const before = opticalScenarioKey(scene, config.optical.noise)
    change(config.optical.noise)
    expect(opticalScenarioKey(scene, config.optical.noise)).not.toBe(before)
  })

  it.each<[string, (config: TwinConfig) => void]>([
    ['power', (config) => { config.lighting.power = 0 }],
    ['count', (config) => { config.lighting.count = 7 }],
    ['ring layout', (config) => { config.lighting.layout = 'ring' }],
    ['line layout', (config) => { config.lighting.layout = 'line' }],
    ['spacing', (config) => { config.lighting.spacing = 0.375 }],
    ['room width', (config) => { config.room.width = 4 }],
    ['room depth', (config) => { config.room.depth = 4 }],
    ['ceiling height', (config) => { config.room.height = 3 }],
    ['fixture override', (config) => { config.positions['LED-02'] = [0.2, -0.4] }],
    ['half-power angle', (config) => { config.optical.halfPowerAngleDeg += 1 }],
    ['detector area', (config) => { config.optical.detectorAreaM2 *= 2 }],
    ['detector FOV', (config) => { config.optical.fovHalfAngleDeg -= 1 }],
  ])('includes configured %s in the scenario identity', (_, change) => {
    const config = createDefaultConfig()
    const before = scenarioKey(config)
    change(config)
    expect(scenarioKey(config)).not.toBe(before)
  })

  it('excludes every detector position coordinate so dragging preserves history', () => {
    const config = createDefaultConfig()
    const scene = toOpticalScene(config)
    const before = opticalScenarioKey(scene, config.optical.noise)
    for (const position of [[1, 0, 0.341], [0, -1, 0.341], [0, 0, 1.341]] as const) {
      scene.detector.position = position
      expect(opticalScenarioKey(scene, config.optical.noise)).toBe(before)
    }
  })
})
