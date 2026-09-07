import { describe, expect, it } from 'vitest'
import { createOpticalParameters, normalizeOpticalParameters } from '../science'
import {
  STORAGE_KEY,
  createDefaultConfig,
  getFixtures,
  getTotalPower,
  normalizeConfig,
  toScenePosition,
} from './config'
import { createMotionConfig, normalizeMotionConfig } from './motion'
import { getReceiverBounds } from './receiver'
import type { LedLayout, MotionPattern, ReceiverPlatform, ThemeId, TwinConfig, WorldPosition } from './types'

const themes: ThemeId[] = ['chalk', 'white', 'sage', 'sand', 'mist', 'rose']
const layouts: LedLayout[] = ['grid', 'ring', 'line']
const platforms: ReceiverPlatform[] = ['cylinder', 'drone']
const counts = Array.from({ length: 9 }, (_, index) => index + 1)
const spacings = [0.2, 0.5, 0.8]

function deepFreeze(config: TwinConfig): TwinConfig {
  Object.freeze(config.room)
  Object.freeze(config.receiver.position)
  Object.freeze(config.receiver)
  Object.freeze(config.motion)
  Object.freeze(config.lighting)
  Object.freeze(config.optical.noise)
  Object.freeze(config.optical)
  Object.freeze(config.display)
  Object.freeze(config.appearance)
  Object.values(config.positions).forEach(Object.freeze)
  Object.freeze(config.positions)
  return Object.freeze(config)
}

describe('default configuration', () => {
  it('uses the exact room, receiver, motion, lighting, optical, display, appearance, and storage defaults', () => {
    expect(createDefaultConfig()).toEqual({
      optical: createOpticalParameters(),
      motion: createMotionConfig(),
      room: { width: 3, depth: 3, height: 2 },
      receiver: { position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true },
      lighting: {
        count: 4,
        shape: 'circular',
        layout: 'grid',
        power: 0.405,
        temperature: 4500,
        spacing: 0.5,
      },
      positions: {},
      display: { grid: false, dimensions: true, labels: true, beams: false, ceiling: false },
      appearance: { theme: 'chalk' },
    })
    expect(STORAGE_KEY).toBe('cambridge-digital-twin:v1')
  })

  it('places exactly four fixtures at the expected centered ceiling coordinates', () => {
    expect(getFixtures(createDefaultConfig())).toEqual([
      { id: 'LED-01', position: [-0.75, -0.75, 2], shape: 'circular', power: 0.405, temperature: 4500 },
      { id: 'LED-02', position: [0.75, -0.75, 2], shape: 'circular', power: 0.405, temperature: 4500 },
      { id: 'LED-03', position: [-0.75, 0.75, 2], shape: 'circular', power: 0.405, temperature: 4500 },
      { id: 'LED-04', position: [0.75, 0.75, 2], shape: 'circular', power: 0.405, temperature: 4500 },
    ])
  })
})

describe.each(layouts)('%s layout', (layout) => {
  it.each(counts)('centers %i unique fixtures with stable IDs and propagated metadata', (count) => {
    const config = normalizeConfig({
      room: { width: 7, depth: 4, height: 3.2 },
      lighting: { count, layout, shape: 'square', power: 1.2, temperature: 5300 },
    })
    const fixtures = getFixtures(config)
    expect(fixtures).toHaveLength(count)
    expect(new Set(fixtures.map(({ position }) => position.join(','))).size).toBe(count)
    expect(fixtures.reduce((sum, fixture) => sum + fixture.position[0], 0)).toBeCloseTo(0, 12)
    expect(fixtures.reduce((sum, fixture) => sum + fixture.position[1], 0)).toBeCloseTo(0, 12)
    fixtures.forEach((fixture, index) => {
      expect(fixture.id).toBe(`LED-${String(index + 1).padStart(2, '0')}`)
      expect(fixture.position[2]).toBe(3.2)
      expect(fixture.shape).toBe('square')
      expect(fixture.power).toBe(1.2)
      expect(fixture.temperature).toBe(5300)
    })
    expect(getFixtures(config)).toEqual(fixtures)
    if (count === 1) expect(fixtures[0].position).toEqual([0, 0, 3.2])
  })

  it.each(spacings)('preserves 0.22 m clearance in the smallest room at spacing %f', (spacing) => {
    for (const count of counts) {
      const config = normalizeConfig({
        room: { width: 2, depth: 2, height: 1.8 },
        lighting: { layout, count, spacing },
      })
      for (const { position: [x, y, z] } of getFixtures(config)) {
        expect(Number.isFinite(x) && Number.isFinite(y)).toBe(true)
        expect(Math.abs(x)).toBeLessThanOrEqual(0.78 + 1e-12)
        expect(Math.abs(y)).toBeLessThanOrEqual(0.78 + 1e-12)
        expect(z).toBe(1.8)
      }
    }
  })

  it('expands around the same center as spacing increases', () => {
    const extents = spacings.map((spacing) => {
      const fixtures = getFixtures(normalizeConfig({ lighting: { layout, count: 4, spacing } }))
      return Math.max(...fixtures.map(({ position: [x, y] }) => Math.hypot(x, y)))
    })
    expect(extents[0]).toBeLessThan(extents[1])
    expect(extents[1]).toBeLessThan(extents[2])
  })
})

describe('layout symmetry', () => {
  it.each(counts)('reflects every %i-fixture grid across both room axes', (count) => {
    const positions = getFixtures(normalizeConfig({ lighting: { count, layout: 'grid' } }))
      .map(({ position }) => position)
    for (const [x, y] of positions) {
      expect(positions.some(([otherX, otherY]) => Math.abs(otherX + x) < 1e-12 && Math.abs(otherY - y) < 1e-12)).toBe(true)
      expect(positions.some(([otherX, otherY]) => Math.abs(otherX - x) < 1e-12 && Math.abs(otherY + y) < 1e-12)).toBe(true)
    }
  })

  it.each(counts)('uses a regular, evenly spaced %i-fixture ring', (count) => {
    const positions = getFixtures(normalizeConfig({ lighting: { count, layout: 'ring' } }))
      .map(({ position }) => position)
    if (count === 1) {
      expect(positions[0]).toEqual([0, 0, 2])
      return
    }
    const radii = positions.map(([x, y]) => Math.hypot(x, y))
    const distances = positions.map(([x, y], index) => {
      const next = positions[(index + 1) % positions.length]
      return Math.hypot(x - next[0], y - next[1])
    })
    radii.forEach((radius) => expect(radius).toBeCloseTo(radii[0], 12))
    distances.forEach((distance) => expect(distance).toBeCloseTo(distances[0], 12))
  })

  it.each(counts)('uses an evenly spaced, centered %i-fixture line on the x axis', (count) => {
    const positions = getFixtures(normalizeConfig({ lighting: { count, layout: 'line' } }))
      .map(({ position }) => position)
    positions.forEach(([, y]) => expect(y).toBe(0))
    if (count < 2) return
    const interval = positions[1][0] - positions[0][0]
    for (let index = 1; index < positions.length; index += 1) {
      expect(positions[index][0] - positions[index - 1][0]).toBeCloseTo(interval, 12)
    }
    expect(positions[0][0]).toBeCloseTo(-positions[count - 1][0], 12)
  })
})

describe('normalization', () => {
  it.each([undefined, null, false, true, 0, 3, 'corrupt JSON', [], [1, 2], NaN, Infinity])(
    'returns defaults for invalid top-level input %s',
    (input) => expect(normalizeConfig(input)).toEqual(createDefaultConfig()),
  )

  it.each([null, [], false, 'broken', 27])('handles invalid nested sections %s', (value) => {
    expect(normalizeConfig({ room: value, receiver: value, motion: value, lighting: value, optical: value, positions: value, display: value, appearance: value }))
      .toEqual(createDefaultConfig())
  })

  it('clamps low and high finite values to all specified limits', () => {
    const low = normalizeConfig({
      room: { width: -3, depth: 0, height: 1 },
      lighting: { count: 0, power: -1, temperature: 200, spacing: 0 },
    })
    expect(low.room).toEqual({ width: 2, depth: 2, height: 1.8 })
    expect(low.lighting).toMatchObject({ count: 1, power: 0, temperature: 2700, spacing: 0.2 })
    const high = normalizeConfig({
      room: { width: 30, depth: 11, height: 6 },
      lighting: { count: 500, power: 3, temperature: 9000, spacing: 10 },
    })
    expect(high.room).toEqual({ width: 10, depth: 10, height: 5 })
    expect(high.lighting).toMatchObject({ count: 9, power: 2, temperature: 6500, spacing: 0.8 })
  })

  it.each([NaN, Infinity, -Infinity, null, '4', true, [], {}])('does not coerce invalid numeric fields %s', (value) => {
    expect(normalizeConfig({
      room: { width: value, depth: value, height: value },
      lighting: { count: value, power: value, temperature: value, spacing: value },
    })).toEqual(createDefaultConfig())
  })

  it('rounds count to the nearest integer and preserves other valid fractions', () => {
    const config = normalizeConfig({
      room: { width: 2.7, depth: 4.1, height: 2.25 },
      lighting: { count: 5.6, power: 0.127, temperature: 3123.5, spacing: 0.375 },
    })
    expect(config.room).toEqual({ width: 2.7, depth: 4.1, height: 2.25 })
    expect(config.lighting).toMatchObject({ count: 6, power: 0.127, temperature: 3123.5, spacing: 0.375 })
  })

  it('defaults unknown enums and nonboolean display fields in serialized data', () => {
    const input: unknown = JSON.parse('{"lighting":{"shape":"triangle","layout":"scatter","count":"9","power":null},"display":{"grid":"true","dimensions":0,"labels":null,"beams":1,"ceiling":[]}}')
    expect(normalizeConfig(input)).toEqual(createDefaultConfig())
  })

  it('preserves valid enums and literal booleans, including false defaults being enabled', () => {
    const config = normalizeConfig({
      lighting: { shape: 'square', layout: 'line' },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
    })
    expect(config.lighting.shape).toBe('square')
    expect(config.lighting.layout).toBe('line')
    expect(config.display).toEqual({ grid: true, dimensions: false, labels: false, beams: true, ceiling: true })
  })

  it('retains only finite two-coordinate overrides for current exact LED IDs', () => {
    const config = normalizeConfig({
      lighting: { count: 9 },
      positions: {
        'LED-01': [0.1, -0.2],
        'LED-02': [NaN, 0],
        'LED-03': [0, Infinity],
        'LED-04': ['0', 0],
        'LED-05': [0],
        'LED-06': [0, 0, 0],
        'LED-07': null,
        'LED-08': { 0: 0, 1: 0 },
        'LED-09': [0, -0.4],
        'LED-10': [0, 0],
        'LED-1': [0, 0],
        arbitrary: [0, 0],
      },
    })
    expect(config.positions).toEqual({ 'LED-01': [0.1, -0.2], 'LED-09': [0, -0.4] })
  })

  it('drops old overrides when the fixture count decreases', () => {
    expect(normalizeConfig({ lighting: { count: 1 }, positions: { 'LED-01': [0, 0], 'LED-02': [0.5, 0.5] } }).positions)
      .toEqual({ 'LED-01': [0, 0] })
  })

  it('clamps overrides against the normalized room, including fixture clearance', () => {
    const config = normalizeConfig({
      room: { width: 0, depth: 0, height: 0 },
      positions: { 'LED-01': [100, -100], 'LED-02': [-100, 100] },
    })
    expect(config.positions).toEqual({ 'LED-01': [0.78, -0.78], 'LED-02': [-0.78, 0.78] })
    expect(getFixtures(config)[0].position).toEqual([0.78, -0.78, 1.8])
    const smaller = normalizeConfig({ ...config, room: { width: 3, depth: 4, height: 2 }, positions: { 'LED-01': [100, -100] } })
    expect(smaller.positions['LED-01']).toEqual([1.28, -1.78])
  })

  it('applies only the requested override without changing layout-generated neighbors', () => {
    const baseline = getFixtures(createDefaultConfig())
    const config = normalizeConfig({ positions: { 'LED-02': [0.15, -0.25] } })
    const fixtures = getFixtures(config)
    expect(fixtures[1].position).toEqual([0.15, -0.25, 2])
    expect(fixtures.filter(({ id }) => id !== 'LED-02')).toEqual(baseline.filter(({ id }) => id !== 'LED-02'))
  })

  it('ignores prototype keys and inherited fields without polluting any objects', () => {
    const hostile: unknown = JSON.parse('{"__proto__":{"polluted":true},"positions":{"__proto__":{"polluted":true},"constructor":[0,0],"prototype":[0,0],"LED-01":[0.1,0.2]},"lighting":{"constructor":"square"}}')
    const result = normalizeConfig(hostile)
    expect(result.positions).toEqual({ 'LED-01': [0.1, 0.2] })
    expect(Object.prototype.hasOwnProperty.call(result, '__proto__')).toBe(false)
    expect(Object.prototype.hasOwnProperty.call(result.positions, '__proto__')).toBe(false)
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'polluted')).toBe(false)
    expect(normalizeConfig(Object.create({ lighting: { count: 9 }, room: { width: 10 } }))).toEqual(createDefaultConfig())
    expect(normalizeConfig({ positions: Object.create({ 'LED-01': [0.5, 0.5] }) }).positions).toEqual({})
    expect(normalizeConfig({ lighting: Object.create({ count: 9 }), display: Object.create({ grid: true }) })).toEqual(createDefaultConfig())
  })

  it('is idempotent and survives a JSON round trip', () => {
    const config = normalizeConfig({ lighting: { layout: 'ring', count: 7, power: 0 }, positions: { 'LED-03': [0.2, 0.4] } })
    expect(normalizeConfig(config)).toEqual(config)
    expect(normalizeConfig(JSON.parse(JSON.stringify(config)))).toEqual(config)
  })
})

describe('optical configuration and migration', () => {
  it('adds science defaults to a legacy config without changing any existing field or stored byte', () => {
    const legacy: Omit<TwinConfig, 'optical' | 'motion'> = {
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
    expect(migrated).toEqual({ ...legacy, motion: createMotionConfig(), optical: createOpticalParameters() })
    expect(normalizeConfig(migrated)).toEqual(migrated)
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
    expect(stored[STORAGE_KEY]).toBe(serialized)
    expect(JSON.stringify(legacy)).toBe(serialized)
  })

  it.each([
    undefined,
    null,
    [],
    'corrupt',
    { halfPowerAngleDeg: 45, detectorAreaM2: 0.00005, fovHalfAngleDeg: 65 },
    { halfPowerAngleDeg: -5, detectorAreaM2: 0, fovHalfAngleDeg: 200 },
    { halfPowerAngleDeg: NaN, detectorAreaM2: Infinity, fovHalfAngleDeg: '60' },
    { noise: { enabled: true, varianceW2: 1e-16, averagingSamples: 32, seed: 42 } },
    { noise: { enabled: 'true', varianceW2: -1, averagingSamples: 0.5, seed: Infinity } },
    { noise: null },
  ])('delegates optical normalization to science for %j', (optical) => {
    expect(normalizeConfig({ optical }).optical).toEqual(normalizeOpticalParameters(optical))
  })

  it('ignores an inherited optical section', () => {
    const inherited = Object.create({ optical: { halfPowerAngleDeg: 45, detectorAreaM2: 0.00005 } })
    expect(normalizeConfig(inherited)).toEqual(createDefaultConfig())
  })

  it('preserves custom optical and noise settings through frozen normalization and JSON round trips', () => {
    const optical = {
      halfPowerAngleDeg: 60,
      detectorAreaM2: 0.00005,
      fovHalfAngleDeg: 65,
      noise: { enabled: true, varianceW2: 1e-16, averagingSamples: 32, seed: 42 },
    }
    const saved = deepFreeze({ ...createDefaultConfig(), optical })
    const before = JSON.stringify(saved)
    const normalized = normalizeConfig(saved)
    expect(normalized).toEqual(saved)
    expect(normalized.optical).not.toBe(saved.optical)
    expect(normalized.optical.noise).not.toBe(saved.optical.noise)
    expect(normalizeConfig(normalized)).toEqual(saved)
    expect(normalizeConfig(JSON.parse(before))).toEqual(saved)
    expect(JSON.stringify(saved)).toBe(before)
  })

  it('keeps optical defaults and normalized noise objects independent', () => {
    const first = createDefaultConfig()
    const second = createDefaultConfig()
    first.optical.halfPowerAngleDeg = 60
    first.optical.noise.enabled = !second.optical.noise.enabled
    expect(first.optical).not.toBe(second.optical)
    expect(first.optical.noise).not.toBe(second.optical.noise)
    const normalized = normalizeConfig(first)
    expect(normalized.optical).not.toBe(first.optical)
    expect(normalized.optical.noise).not.toBe(first.optical.noise)
    normalized.optical.halfPowerAngleDeg = 30
    normalized.optical.noise.seed = second.optical.noise.seed + 1
    expect(first.optical.halfPowerAngleDeg).toBe(60)
    expect(first.optical.noise.seed).toBe(second.optical.noise.seed)
    expect(second.optical).toEqual(createOpticalParameters())
  })
})

describe('motion configuration and migration', () => {
  it('adds motion defaults to old persisted data without changing any other field or stored byte', () => {
    const legacy: Omit<TwinConfig, 'motion'> = {
      room: { width: 7, depth: 5, height: 3.1 },
      receiver: { position: [1.2, -0.6, 1.1], yaw: 73.25, platform: 'drone', rotorsSpinning: false },
      optical: normalizeOpticalParameters({ halfPowerAngleDeg: 60, noise: { enabled: true, seed: 42 } }),
      lighting: { count: 7, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-03': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      appearance: { theme: 'mist' },
    }
    const serialized = JSON.stringify(legacy)
    const stored = { [STORAGE_KEY]: serialized }
    const migrated = normalizeConfig(JSON.parse(stored[STORAGE_KEY]))
    expect(migrated).toEqual({ ...legacy, motion: createMotionConfig() })
    expect(normalizeConfig(migrated)).toEqual(migrated)
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
    expect(stored[STORAGE_KEY]).toBe(serialized)
    expect(JSON.stringify(legacy)).toBe(serialized)
    expect(getFixtures(migrated)).toEqual(getFixtures(normalizeConfig(legacy)))
  })

  it.each(['circle', 'figure-eight', 'raster'] satisfies MotionPattern[])('round trips frozen %s settings without changing geometry, receiver, or science', (pattern) => {
    const baseline = deepFreeze(normalizeConfig({
      room: { width: 7, depth: 5, height: 3.1 },
      receiver: { position: [1.2, -0.6, 1.1], yaw: 73.25, platform: 'drone', rotorsSpinning: false },
      optical: { halfPowerAngleDeg: 60, noise: { enabled: true, seed: 42 } },
      positions: { 'LED-03': [0.2, -0.4] },
      appearance: { theme: 'mist' },
    }))
    const motion = { pattern, extentM: 3.5, altitudeM: 1.23, speedMps: 0.375, loop: false }
    const saved = deepFreeze({ ...baseline, motion })
    const serialized = JSON.stringify(saved)
    const normalized = normalizeConfig(saved)
    expect(normalized).toEqual(saved)
    expect(normalized.motion).not.toBe(saved.motion)
    expect(normalizeConfig(normalized)).toEqual(saved)
    expect(normalizeConfig(JSON.parse(serialized))).toEqual(saved)
    expect(JSON.stringify(saved)).toBe(serialized)
    expect(getFixtures(normalized)).toEqual(getFixtures(baseline))
    expect(getTotalPower(normalized)).toBe(getTotalPower(baseline))
    expect(normalized.optical).toEqual(baseline.optical)
    expect(normalized.receiver).toEqual(baseline.receiver)
  })

  it.each(platforms)('normalizes motion only after the room and %s receiver', (platform) => {
    for (const altitudeM of [-100, 100]) {
      const motion = { pattern: 'raster', extentM: 4, altitudeM, speedMps: 0.1, loop: false }
      const normalized = normalizeConfig({ room: { width: 0, depth: 30, height: 0 }, receiver: { platform, yaw: 405 }, motion })
      expect(normalized.room).toEqual({ width: 2, depth: 10, height: 1.8 })
      expect(normalized.receiver.yaw).toBe(45)
      const bounds = getReceiverBounds(normalized.room, platform, 45)
      expect(normalized.motion.altitudeM).toBe(altitudeM < 0 ? bounds.z[0] : bounds.z[1])
      expect(normalized.motion.extentM).toBe(4)
      expect(normalized.motion).toEqual(normalizeMotionConfig(motion, normalized.room, normalized.receiver))
    }
  })

  it('ignores inherited and accessor motion sections and drops transient playback state', () => {
    expect(normalizeConfig(Object.create({ motion: { pattern: 'raster', loop: false } }))).toEqual(createDefaultConfig())
    expect(normalizeConfig(Object.defineProperty({}, 'motion', { get() { throw new Error('accessor executed') } }))).toEqual(createDefaultConfig())
    expect(normalizeConfig({ motion: Object.create({ pattern: 'circle', speedMps: 1 }) })).toEqual(createDefaultConfig())
    expect(normalizeConfig({ motion: { ...createMotionConfig(), playing: true, progress: 12, route: [[1, 2, 3]] } })).toEqual(createDefaultConfig())
  })

  it('keeps default and normalized motion objects independent', () => {
    const first = createDefaultConfig()
    const second = createDefaultConfig()
    first.motion.extentM = 2
    expect(second.motion).toEqual(createMotionConfig())
    expect(first.motion).not.toBe(second.motion)
    const normalized = normalizeConfig(first)
    normalized.motion.loop = false
    expect(first.motion.loop).toBe(true)
    expect(normalized.motion).not.toBe(first.motion)
  })
})

describe('appearance normalization and migration', () => {
  it.each(themes)('preserves %s and all saved settings through normalization and a JSON round trip', (theme) => {
    const saved = deepFreeze({
      optical: createOpticalParameters(),
      motion: createMotionConfig(),
      appearance: { theme },
      room: { width: 7, depth: 5, height: 3.1 },
      receiver: { position: [1.2, -0.6, 1.1], yaw: 73.25, platform: 'cylinder', rotorsSpinning: true },
      lighting: { count: 7, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-03': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
    })
    const before = JSON.stringify(saved)
    const config = normalizeConfig(saved)
    expect(config).toEqual(saved)
    expect(normalizeConfig(config)).toEqual(saved)
    expect(normalizeConfig(JSON.parse(before))).toEqual(saved)
    expect(JSON.stringify(saved)).toBe(before)
  })

  it('migrates a serialized v1 config without resetting any existing settings', () => {
    const legacy = {
      room: { width: 7, depth: 5, height: 3.1 },
      lighting: { count: 6, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-01': [-1.2, 0.3], 'LED-06': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
    }
    const stored = { [STORAGE_KEY]: JSON.stringify(legacy) }
    const migrated = normalizeConfig(JSON.parse(stored['cambridge-digital-twin:v1']))
    expect(migrated).toEqual({ ...legacy, motion: createMotionConfig(), optical: createOpticalParameters(), receiver: { position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true }, appearance: { theme: 'chalk' } })
    expect(getFixtures(migrated)[0].position).toEqual([-1.2, 0.3, 3.1])
    expect(getFixtures(migrated)[5].position).toEqual([0.2, -0.4, 3.1])
    expect(getTotalPower(migrated)).toBeCloseTo(0.762, 12)
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
  })

  it.each([
    ['lavender', 'white'],
    ['unknown', 'chalk'],
    [undefined, 'chalk'],
  ])('migrates saved theme %s to %s without resetting or mutating any settings', (theme, expectedTheme) => {
    const saved = {
      room: { width: 7, depth: 5, height: 3.1 },
      lighting: { count: 6, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-01': [-1.2, 0.3], 'LED-06': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      appearance: { theme },
    }
    const before = JSON.stringify(saved)
    const migrated = normalizeConfig(saved)
    expect(migrated).toEqual({ ...saved, motion: createMotionConfig(), optical: createOpticalParameters(), receiver: { position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true }, appearance: { theme: expectedTheme } })
    expect(normalizeConfig(JSON.parse(before))).toEqual(migrated)
    expect(getFixtures(migrated)[0].position).toEqual([-1.2, 0.3, 3.1])
    expect(getFixtures(migrated)[5].position).toEqual([0.2, -0.4, 3.1])
    expect(getTotalPower(migrated)).toBeCloseTo(0.762, 12)
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
    expect(JSON.stringify(saved)).toBe(before)
  })

  it.each([
    undefined, null, false, true, 0, NaN, Infinity, '', 'rose', [], ['rose'],
    Object.assign([], { theme: 'rose' }), () => ({ theme: 'rose' }),
  ])('defaults a missing or corrupt appearance section %s to Chalk', (appearance) => {
    expect(normalizeConfig({ appearance }).appearance).toEqual({ theme: 'chalk' })
  })

  it.each([
    undefined, null, false, true, 0, NaN, Infinity, '', 'unknown', 'Sage', 'ROSE', ' rose ',
    '__proto__', 'constructor', 'toString', [], ['rose'], {}, { id: 'rose' },
    { toString: () => 'rose' }, Object('rose'),
  ])('does not coerce or accept an invalid theme %s', (theme) => {
    expect(normalizeConfig({ appearance: { theme } }).appearance).toEqual({ theme: 'chalk' })
  })

  it('ignores inherited appearance and theme fields and drops unknown palette data', () => {
    expect(normalizeConfig(Object.create({ appearance: { theme: 'rose' } })).appearance).toEqual({ theme: 'chalk' })
    expect(normalizeConfig({ appearance: Object.create({ theme: 'rose' }) }).appearance).toEqual({ theme: 'chalk' })
    expect(normalizeConfig({ appearance: { palette: 'rose' } }).appearance).toEqual({ theme: 'chalk' })
    const hostile = JSON.parse('{"appearance":{"__proto__":{"theme":"rose"},"constructor":"rose"}}')
    expect(normalizeConfig(hostile).appearance).toEqual({ theme: 'chalk' })
    const appearance = Object.assign(Object.create(null), { theme: 'mist', colors: { ink: '#ffffff' } })
    expect(normalizeConfig({ appearance }).appearance).toEqual({ theme: 'mist' })
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'theme')).toBe(false)
  })

  it.each(themes)('changes only appearance for %s without mutating input or optical data', (theme) => {
    for (const layout of layouts) {
      const baseline = deepFreeze(normalizeConfig({
        room: { width: 7, depth: 5, height: 3.1 },
        lighting: { count: 7, layout, shape: 'square', power: 0.127, temperature: 5300, spacing: 0.375 },
        positions: { 'LED-03': [0.2, -0.4] },
        display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      }))
      const before = JSON.stringify(baseline)
      const input = deepFreeze({ ...baseline, appearance: { theme } })
      const inputBefore = JSON.stringify(input)
      const changed = normalizeConfig(input)
      expect(changed).toEqual({ ...baseline, appearance: { theme } })
      expect(changed.appearance).not.toBe(input.appearance)
      expect(getFixtures(changed)).toEqual(getFixtures(baseline))
      expect(getTotalPower(changed)).toBe(getTotalPower(baseline))
      expect(JSON.stringify(baseline)).toBe(before)
      expect(JSON.stringify(input)).toBe(inputBefore)
    }
  })
})

describe('receiver configuration and migration', () => {
  it('adds a centered receiver to legacy v1 data while retaining every existing field and stored byte', () => {
    const legacy = {
      room: { width: 7, depth: 5, height: 3.1 },
      lighting: { count: 6, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-01': [-1.2, 0.3], 'LED-06': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      appearance: { theme: 'mist' },
    }
    const serialized = JSON.stringify(legacy)
    const stored = { [STORAGE_KEY]: serialized }
    const migrated = normalizeConfig(JSON.parse(stored['cambridge-digital-twin:v1']))
    expect(migrated).toEqual({ ...legacy, motion: createMotionConfig(), optical: createOpticalParameters(), receiver: { position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: true } })
    expect(normalizeConfig(migrated)).toEqual(migrated)
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
    expect(stored[STORAGE_KEY]).toBe(serialized)
    expect(JSON.stringify(legacy)).toBe(serialized)
    expect(getFixtures(migrated)).toEqual(getFixtures(normalizeConfig(legacy)))
    expect(getTotalPower(migrated)).toBeCloseTo(0.762, 12)
  })

  it.each([
    { width: 0, depth: 0, height: 0 },
    { width: 30, depth: 30, height: 30 },
    { width: 6, depth: 8, height: 4.2 },
  ])('initializes missing and invalid receiver positions at 0.3 m after normalizing room %j', (room) => {
    expect(normalizeConfig({ room }).receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
    expect(normalizeConfig({ room, receiver: { position: [1, 2], yaw: 27 } }).receiver)
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 27 })
  })

  it('preserves custom receiver coordinates and yaw through normalization and JSON serialization', () => {
    const saved = deepFreeze({ ...createDefaultConfig(), receiver: { position: [0.8, -0.7, 1.2], yaw: 123.45, platform: 'cylinder', rotorsSpinning: true } })
    const before = JSON.stringify(saved)
    expect(normalizeConfig(saved)).toEqual(saved)
    expect(normalizeConfig(JSON.parse(before))).toEqual(saved)
    expect(JSON.stringify(saved)).toBe(before)
  })

  it('clamps a receiver when the room shrinks while preserving its yaw and all unrelated settings', () => {
    const saved = deepFreeze(normalizeConfig({
      room: { width: 10, depth: 10, height: 5 },
      receiver: { position: [4, -4, 4], yaw: 285 },
      lighting: { power: 1.2, shape: 'square' },
      appearance: { theme: 'rose' },
    }))
    const smaller = normalizeConfig({ ...saved, room: { width: 0, depth: 0, height: 0 } })
    expect(smaller).toEqual({
      ...saved,
      room: { width: 2, depth: 2, height: 1.8 },
      receiver: { position: [0.94, -0.94, 1.8 - 0.04 - 0.002 - 0.01], yaw: 285, platform: 'cylinder', rotorsSpinning: true },
    })
    expect(saved.receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [4, -4, 4], yaw: 285 })
  })

  it('ignores inherited receivers and strips unconfigurable geometry and hostile keys', () => {
    expect(normalizeConfig(Object.create({ receiver: { position: [1, 1, 1.5], yaw: 90 } }))).toEqual(createDefaultConfig())
    const hostile = JSON.parse('{"receiver":{"position":[0.2,-0.3,1.4],"yaw":-90,"diameter":7,"geometry":{"pdWidth":2},"__proto__":{"polluted":true},"constructor":{"polluted":true}}}')
    expect(normalizeConfig(hostile).receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 270 })
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'polluted')).toBe(false)
  })

  it('returns fresh centered receiver data on reset without sharing previous defaults or normalized positions', () => {
    const changed = createDefaultConfig()
    changed.receiver.position[0] = 1
    changed.receiver.yaw = 70
    const normalized = normalizeConfig(changed)
    normalized.receiver.position[1] = -1
    normalized.receiver.yaw = 20
    const reset = createDefaultConfig()
    expect(reset.receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
    expect(changed.receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [1, 0, 0.3], yaw: 70 })
    expect(reset.receiver).not.toBe(changed.receiver)
    expect(normalized.receiver).not.toBe(changed.receiver)
    expect(reset.receiver.position).not.toBe(changed.receiver.position)
    expect(normalized.receiver.position).not.toBe(changed.receiver.position)
  })
})

describe('receiver platform configuration and migration', () => {
  it('migrates stored receiver data missing platform fields without changing existing pose or any other settings', () => {
    const legacy = {
      room: { width: 7, depth: 5, height: 3.1 },
      receiver: { position: [1.234567, -0.654321, 1], yaw: 123.456789 },
      lighting: { count: 6, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
      positions: { 'LED-01': [-1.2, 0.3], 'LED-06': [0.2, -0.4] },
      display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
      appearance: { theme: 'mist' },
    }
    const serialized = JSON.stringify(legacy)
    const stored = { [STORAGE_KEY]: serialized }
    const migrated = normalizeConfig(JSON.parse(stored[STORAGE_KEY]))
    expect(migrated).toEqual({ ...legacy, motion: createMotionConfig(), optical: createOpticalParameters(), receiver: { ...legacy.receiver, platform: 'cylinder', rotorsSpinning: true } })
    expect(normalizeConfig(JSON.parse(JSON.stringify(migrated)))).toEqual(migrated)
    expect(getFixtures(migrated)).toEqual(getFixtures(normalizeConfig(legacy)))
    expect(getTotalPower(migrated)).toBeCloseTo(0.762, 12)
    expect(stored[STORAGE_KEY]).toBe(serialized)
    expect(JSON.stringify(legacy)).toBe(serialized)
  })

  it.each(platforms)('preserves saved %s receiver and all unrelated data through normalization and serialization', (platform) => {
    for (const rotorsSpinning of [false, true]) {
      const saved = deepFreeze({
        optical: createOpticalParameters(),
        motion: createMotionConfig(),
        room: { width: 7, depth: 5, height: 3.1 },
        receiver: { position: [1.234567, -0.654321, 1.123456], yaw: 123.456789, platform, rotorsSpinning },
        lighting: { count: 7, shape: 'square', layout: 'ring', power: 0.127, temperature: 5300, spacing: 0.375 },
        positions: { 'LED-03': [0.2, -0.4] },
        display: { grid: true, dimensions: false, labels: false, beams: true, ceiling: true },
        appearance: { theme: 'mist' },
      })
      const before = JSON.stringify(saved)
      const normalized = normalizeConfig(saved)
      expect(normalized).toEqual(saved)
      expect(normalized.receiver).not.toBe(saved.receiver)
      expect(normalized.receiver.position).not.toBe(saved.receiver.position)
      expect(normalizeConfig(JSON.parse(before))).toEqual(saved)
      expect(normalizeConfig(normalized)).toEqual(saved)
      const toggled = normalizeConfig({ ...saved, receiver: { ...saved.receiver, rotorsSpinning: !rotorsSpinning } })
      expect(toggled).toEqual({ ...saved, receiver: { ...saved.receiver, rotorsSpinning: !rotorsSpinning } })
      const changed = normalizeConfig({ ...saved, receiver: { ...saved.receiver, platform: platform === 'drone' ? 'cylinder' : 'drone' } })
      expect(changed).toEqual({ ...saved, receiver: { ...saved.receiver, platform: platform === 'drone' ? 'cylinder' : 'drone' } })
      expect(getFixtures(changed)).toEqual(getFixtures(saved))
      expect(getTotalPower(changed)).toBe(getTotalPower(saved))
      expect(JSON.stringify(saved)).toBe(before)
    }
  })

  it('defaults corrupt serialized platform and animation fields independently without losing valid receiver data', () => {
    const corrupt = JSON.parse('{"receiver":{"position":[0.234567,-0.345678,1.234567],"yaw":234.56789,"platform":"constructor","rotorsSpinning":"false"},"lighting":{"power":0.127},"appearance":{"theme":"sage"}}')
    const expected = createDefaultConfig()
    expected.receiver.position = [0.234567, -0.345678, 1.234567]
    expected.receiver.yaw = 234.56789
    expected.lighting.power = 0.127
    expected.appearance.theme = 'sage'
    expect(normalizeConfig(corrupt)).toEqual(expected)
    expect(normalizeConfig({ ...corrupt, receiver: { ...corrupt.receiver, platform: 'drone', rotorsSpinning: false } }))
      .toEqual({ ...expected, receiver: { ...expected.receiver, platform: 'drone', rotorsSpinning: false } })
  })

  it('clamps only necessary coordinates on a near-wall platform or yaw change', () => {
    const saved = deepFreeze(normalizeConfig({
      receiver: { position: [1.44, -0.654321, 1.234567], yaw: 0, rotorsSpinning: false },
      lighting: { power: 0.127, count: 6, shape: 'square', layout: 'ring' },
      positions: { 'LED-03': [0.2, -0.4] },
      appearance: { theme: 'mist' },
    }))
    const drone = normalizeConfig({ ...saved, receiver: { ...saved.receiver, platform: 'drone' } })
    expect(drone).toEqual({ ...saved, receiver: { ...saved.receiver, platform: 'drone', position: [1.35, -0.654321, 1.234567] } })
    const rotated = normalizeConfig({ ...drone, receiver: { ...drone.receiver, yaw: 405 } })
    const angle = 45 * Math.PI / 180
    const limit = 1.5 - (0.08 * (Math.abs(Math.cos(angle)) + Math.abs(Math.sin(angle))) + 0.06 + 0.01)
    expect(rotated).toEqual({ ...drone, receiver: { ...drone.receiver, yaw: 45, position: [limit, -0.654321, 1.234567] } })
    expect(normalizeConfig({ ...rotated, receiver: { ...rotated.receiver, platform: 'cylinder' } }))
      .toEqual({ ...rotated, receiver: { ...rotated.receiver, platform: 'cylinder' } })
    expect(saved.receiver.position).toEqual([1.44, -0.654321, 1.234567])
  })

  it('uses normalized room dimensions and rotated drone bounds when a room shrinks', () => {
    const saved = deepFreeze(normalizeConfig({
      room: { width: 10, depth: 10, height: 5 },
      receiver: { position: [4, -4, 4], yaw: 45, platform: 'drone', rotorsSpinning: false },
      lighting: { power: 1.2, shape: 'square' },
      appearance: { theme: 'rose' },
    }))
    const smaller = normalizeConfig({ ...saved, room: { width: 0, depth: 0, height: 0 } })
    const margin = 0.08 * (Math.cos(Math.PI / 4) + Math.sin(Math.PI / 4)) + 0.06 + 0.01
    expect(smaller).toEqual({
      ...saved,
      room: { width: 2, depth: 2, height: 1.8 },
      receiver: { ...saved.receiver, position: [1 - margin, -1 + margin, 1.8 - 0.03 - 0.002 - 0.01] },
    })
    expect(saved.receiver.position).toEqual([4, -4, 4])
  })
})

describe('coordinate transform and power data', () => {
  it('maps world x/y floor coordinates and z height to scene x/y/z', () => {
    expect(toScenePosition([1.25, -0.5, 2])).toEqual([1.25, 2, 0.5])
    expect(toScenePosition([-1, 0.75, 3])).toEqual([-1, 3, -0.75])
  })

  it('preserves a right-handed coordinate system and distances', () => {
    const x = toScenePosition([1, 0, 0])
    const y = toScenePosition([0, 1, 0])
    const z = toScenePosition([0, 0, 1])
    const cross: WorldPosition = [x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0]]
    cross.forEach((value, index) => expect(value).toBeCloseTo(z[index], 12))
    const world: WorldPosition = [1.25, -0.75, 2.8]
    expect(Math.hypot(...toScenePosition(world))).toBeCloseTo(Math.hypot(...world), 12)
  })

  it('multiplies fixture count by power and preserves zero power', () => {
    expect(getTotalPower(createDefaultConfig())).toBeCloseTo(1.62, 12)
    const config = normalizeConfig({ lighting: { count: 9, power: 0 } })
    expect(getTotalPower(config)).toBe(0)
    expect(getFixtures(config).every(({ power }) => power === 0)).toBe(true)
    expect(getTotalPower(normalizeConfig({ lighting: { count: 9, power: 2 } }))).toBe(18)
  })
})

describe('mutation isolation', () => {
  it('returns independent defaults and normalized objects', () => {
    const first = createDefaultConfig()
    const second = createDefaultConfig()
    first.room.width = 10
    first.lighting.power = 0
    first.display.labels = false
    first.appearance.theme = 'rose'
    first.positions['LED-01'] = [0.1, 0.2]
    expect(first.appearance).not.toBe(second.appearance)
    expect(second.appearance).toEqual({ theme: 'chalk' })
    expect(second).toEqual(normalizeConfig(undefined))
    const normalized = normalizeConfig(first)
    normalized.positions['LED-01'][0] = 0.9
    normalized.room.width = 2
    normalized.lighting.count = 1
    normalized.display.grid = true
    normalized.appearance.theme = 'mist'
    expect(first.appearance).toEqual({ theme: 'rose' })
    expect(first.positions['LED-01']).toEqual([0.1, 0.2])
    expect(first.room.width).toBe(10)
    expect(first.lighting.count).toBe(4)
    expect(first.display.grid).toBe(false)
  })

  it('never mutates frozen inputs or shares fixture positions across calls', () => {
    const config = deepFreeze(normalizeConfig({ positions: { 'LED-01': [0.1, 0.2] } }))
    const before = JSON.stringify(config)
    expect(() => normalizeConfig(config)).not.toThrow()
    expect(() => getTotalPower(config)).not.toThrow()
    const fixtures = getFixtures(config)
    fixtures[0].position[0] = 99
    fixtures[1].position[1] = 99
    fixtures[0].power = 99
    expect(JSON.stringify(config)).toBe(before)
    expect(getFixtures(config)[0].position).toEqual([0.1, 0.2, 2])
    expect(getFixtures(config)[1].position).toEqual([0.75, -0.75, 2])
    expect(getFixtures(config)[0].power).toBe(0.405)
  })

  it('does not mutate or reuse the world tuple in coordinate conversion', () => {
    const world: WorldPosition = [1, 2, 3]
    Object.freeze(world)
    const scene = toScenePosition(world)
    scene[0] = 9
    expect(world).toEqual([1, 2, 3])
    expect(toScenePosition(world)).toEqual([1, 3, -2])
  })
})
