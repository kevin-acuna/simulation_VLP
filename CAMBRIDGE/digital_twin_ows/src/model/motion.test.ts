import { describe, expect, it } from 'vitest'
import { normalizeConfig } from './config'
import { buildMotionRoute, createMotionConfig, normalizeMotionConfig, sampleMotionRoute } from './motion'
import type { MotionRoute } from './motion'
import { clampReceiverPosition, createReceiver, getReceiverBounds } from './receiver'
import type { MotionPattern, ReceiverPlatform, RoomConfig, WorldPosition } from './types'

const patterns: MotionPattern[] = ['circle', 'figure-eight', 'raster']
const platforms: ReceiverPlatform[] = ['cylinder', 'drone']
const room: RoomConfig = { width: 3, depth: 3, height: 2 }
const receiver = createReceiver(room)

function distance(a: WorldPosition, b: WorldPosition): number {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2])
}

function expectPosition(actual: WorldPosition, expected: WorldPosition): void {
  actual.forEach((value, axis) => expect(value).toBeCloseTo(expected[axis], 11))
}

describe('motion configuration', () => {
  it('returns exact independent defaults', () => {
    const defaults = { pattern: 'figure-eight', extentM: 0.8, altitudeM: 0.3, speedMps: 0.25, loop: true }
    const first = createMotionConfig()
    expect(first).toEqual(defaults)
    expect(createMotionConfig()).not.toBe(first)
    first.extentM = 4
    expect(createMotionConfig()).toEqual(defaults)
  })

  it.each([undefined, null, false, true, 0, NaN, Infinity, 'circle', [], ['circle'], Object.assign([], { pattern: 'circle' }), () => ({ pattern: 'circle' })])(
    'defaults invalid input %s without coercion',
    (input) => expect(normalizeMotionConfig(input, room, receiver)).toEqual(createMotionConfig()),
  )

  it.each([undefined, null, NaN, Infinity, -Infinity, true, false, '0.5', [], {}, Object(0.5)])(
    'rejects invalid numeric fields %s independently',
    (value) => expect(normalizeMotionConfig({ extentM: value, altitudeM: value, speedMps: value }, room, receiver)).toEqual(createMotionConfig()),
  )

  it.each(['Circle', 'figure8', ' figure-eight ', 'constructor', '__proto__', '', null, 1, {}, ['circle']])(
    'defaults unknown pattern %s',
    (pattern) => expect(normalizeMotionConfig({ pattern }, room, receiver).pattern).toBe('figure-eight'),
  )

  it.each([undefined, null, 0, 1, 'true', 'false', [], {}, Object(false)])(
    'requires a literal loop boolean rather than %s',
    (loop) => expect(normalizeMotionConfig({ loop }, room, receiver).loop).toBe(true),
  )

  it.each(patterns)('preserves valid %s settings through a frozen JSON round trip', (pattern) => {
    const input = Object.freeze({ pattern, extentM: 1.2345, altitudeM: 1.1234, speedMps: 0.5678, loop: false })
    const normalized = normalizeMotionConfig(input, room, receiver)
    expect(normalized).toEqual(input)
    expect(normalized).not.toBe(input)
    expect(normalizeMotionConfig(normalized, room, receiver)).toEqual(input)
    expect(normalizeMotionConfig(JSON.parse(JSON.stringify(input)), room, receiver)).toEqual(input)
  })

  it.each(platforms)('clamps numeric limits using %s geometry without reducing the requested extent', (platform) => {
    const smallRoom = { width: 2, depth: 2, height: 1.8 }
    const active = { ...createReceiver(smallRoom, platform), yaw: 45 }
    const bounds = getReceiverBounds(smallRoom, platform, active.yaw)
    expect(normalizeMotionConfig({ extentM: -1, altitudeM: -100, speedMps: 0, loop: false }, smallRoom, active))
      .toEqual({ ...createMotionConfig(), extentM: 0.1, altitudeM: bounds.z[0], speedMps: 0.05, loop: false })
    expect(normalizeMotionConfig({ extentM: 100, altitudeM: 100, speedMps: 100 }, smallRoom, active))
      .toEqual({ ...createMotionConfig(), extentM: 4, altitudeM: bounds.z[1], speedMps: 1 })
    expect(normalizeMotionConfig({ extentM: 4 }, smallRoom, active).extentM).toBe(4)
  })

  it('accepts only own data fields and never evaluates accessors', () => {
    const values = { pattern: 'raster', extentM: 2, altitudeM: 1.2, speedMps: 0.75, loop: false }
    expect(normalizeMotionConfig(Object.create(values), room, receiver)).toEqual(createMotionConfig())
    expect(normalizeMotionConfig(Object.assign([], values), room, receiver)).toEqual(createMotionConfig())
    expect(normalizeMotionConfig({ pattern: ['circle'], extentM: [1], altitudeM: [1], speedMps: [1], loop: [false] }, room, receiver)).toEqual(createMotionConfig())
    const accessors = Object.create(null)
    for (const key of Object.keys(values)) {
      Object.defineProperty(accessors, key, { enumerable: true, get() { throw new Error('accessor executed') } })
    }
    expect(normalizeMotionConfig(accessors, room, receiver)).toEqual(createMotionConfig())
    const ownFields = Object.assign(Object.create(values), { extentM: 1.5, loop: false })
    expect(normalizeMotionConfig(ownFields, room, receiver)).toEqual({ ...createMotionConfig(), extentM: 1.5, loop: false })
    const hostile = JSON.parse('{"pattern":"circle","__proto__":{"polluted":true},"constructor":"raster","speedMps":0.5,"geometry":{"radius":4},"playing":true}')
    expect(normalizeMotionConfig(hostile, room, receiver)).toEqual({ ...createMotionConfig(), pattern: 'circle', speedMps: 0.5 })
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'polluted')).toBe(false)
    expect(normalizeMotionConfig(Object.assign(Object.create(null), values), room, receiver)).toEqual(values)
  })
})

describe.each(patterns)('%s motion route', (pattern) => {
  it('keeps a clamped initial position and an explicit straight lead-in without teleporting', () => {
    const motion = { ...createMotionConfig(), pattern, altitudeM: 1.2 }
    const start: WorldPosition = [0.25, -0.4, 0.6]
    const route = buildMotionRoute(room, receiver, motion, start)
    expect(route.points[0]).toEqual(start)
    expect(route.points[0]).not.toBe(start)
    expect(route.points[1][2]).toBe(motion.altitudeM)
    expect(route.leadInLengthM).toBeCloseTo(distance(start, route.points[1]), 12)
    expect(route.cumulativeDistances[0]).toBe(0)
    expect(route.cumulativeDistances[1]).toBe(route.leadInLengthM)
    expect(route.lengthM).toBeCloseTo(route.leadInLengthM + route.loopLengthM, 12)
    expect(sampleMotionRoute(route, 0, true)).toEqual({ position: start, done: false })
    const midpoint = sampleMotionRoute(route, route.leadInLengthM / 2, true)
    expectPosition(midpoint.position, start.map((value, axis) => (value + route.points[1][axis]) / 2) as WorldPosition)
    expect(distance(sampleMotionRoute(route, 1e-6, true).position, start)).toBeCloseTo(1e-6, 11)
    const outside: WorldPosition = [100, -100, 100]
    expect(buildMotionRoute(room, receiver, motion, outside).points[0]).toEqual(clampReceiverPosition(outside, room, receiver.platform, receiver.yaw))
    expect(buildMotionRoute(room, receiver, motion).points[0]).toEqual(receiver.position)
  })

  it('closes the main circuit exactly and accumulates every segment length', () => {
    const route = buildMotionRoute(room, receiver, { ...createMotionConfig(), pattern })
    expect(route.points.at(-1)).toEqual(route.points[1])
    expect(route.points.at(-1)).not.toBe(route.points[1])
    expect(route.points).toHaveLength(route.cumulativeDistances.length)
    let length = 0
    for (let index = 1; index < route.points.length; index += 1) {
      length += distance(route.points[index - 1], route.points[index])
      expect(route.cumulativeDistances[index]).toBeCloseTo(length, 12)
      expect(route.cumulativeDistances[index]).toBeGreaterThanOrEqual(route.cumulativeDistances[index - 1])
    }
    expect(route.lengthM).toBe(length)
    expect(route.loopLengthM).toBeGreaterThan(0)
  })

  it('fits every axis across normalized rooms, platforms, altitudes, extents, and drone yaws', () => {
    const rooms = [
      { width: 0, depth: 0, height: 0 },
      { width: 10, depth: 10, height: 5 },
      { width: 2, depth: 10, height: 1.8 },
      { width: 10, depth: 2, height: 5 },
      { width: 2.7, depth: 4.1, height: 2.25 },
    ]
    for (const dimensions of rooms) {
      for (const platform of platforms) {
        for (const yaw of [0, 15, 45, 90, 135, 225, 315, 359.9]) {
          for (const extentM of [0.1, 0.8, 4]) {
            const config = normalizeConfig({ room: dimensions, receiver: { platform, yaw, position: [100, -100, 100] }, motion: { pattern, extentM, altitudeM: yaw % 2 ? 100 : -100 } })
            const route = buildMotionRoute(config.room, config.receiver, config.motion)
            const bounds = getReceiverBounds(config.room, platform, config.receiver.yaw)
            const limits = [bounds.x, bounds.y, bounds.z]
            expect(route.points.at(-1)).toEqual(route.points[1])
            expect(config.motion.extentM).toBe(extentM)
            expect(route.points.slice(1).every((point) => point[2] === config.motion.altitudeM)).toBe(true)
            const samples = Array.from({ length: 21 }, (_, index) => sampleMotionRoute(route, route.lengthM * index / 20, true).position)
            limits.forEach(([minimum, maximum], axis) => {
              const coordinates = [...route.points, ...samples].map((point) => point[axis])
              expect(coordinates.every(Number.isFinite)).toBe(true)
              expect(Math.min(...coordinates)).toBeGreaterThanOrEqual(minimum - 1e-12)
              expect(Math.max(...coordinates)).toBeLessThanOrEqual(maximum + 1e-12)
            })
          }
        }
      }
    }
  })

  it('is continuous at the lead and every loop boundary without re-flying the lead', () => {
    const start: WorldPosition = [-0.7, 0.2, 1.3]
    const route = buildMotionRoute(room, receiver, { ...createMotionConfig(), pattern }, start)
    const epsilon = 1e-7
    expectPosition(sampleMotionRoute(route, route.leadInLengthM, true).position, route.points[1])
    for (const cycles of [0, 1, 2, 5]) {
      const boundary = route.leadInLengthM + route.loopLengthM * cycles
      expectPosition(sampleMotionRoute(route, boundary, true).position, route.points[1])
      expect(distance(sampleMotionRoute(route, boundary - epsilon, true).position, route.points[1])).toBeCloseTo(epsilon, 9)
      expect(distance(sampleMotionRoute(route, boundary + epsilon, true).position, route.points[1])).toBeCloseTo(epsilon, 9)
      expect(sampleMotionRoute(route, boundary, true).done).toBe(false)
    }
    for (const fraction of [0.01, 0.25, 0.5, 0.9]) {
      const offset = route.loopLengthM * fraction
      expectPosition(sampleMotionRoute(route, route.leadInLengthM + 4 * route.loopLengthM + offset, true).position,
        sampleMotionRoute(route, route.leadInLengthM + offset, true).position)
    }
    expect(distance(sampleMotionRoute(route, route.lengthM, true).position, start)).toBeGreaterThan(0.1)
  })

  it('interpolates arc length at constant speed within and across differently sized segments', () => {
    const motion = { ...createMotionConfig(), pattern, speedMps: 0.37 }
    const route = buildMotionRoute(room, receiver, motion, [-0.6, 0.7, 1.5])
    for (let index = 1; index < route.points.length; index += 1) {
      const from = route.points[index - 1]
      const to = route.points[index]
      const length = distance(from, to)
      if (length === 0) continue
      const begin = route.cumulativeDistances[index - 1]
      const first = sampleMotionRoute(route, begin + length * 0.2, false).position
      const second = sampleMotionRoute(route, begin + length * 0.8, false).position
      expectPosition(first, from.map((value, axis) => value + (to[axis] - value) * 0.2) as WorldPosition)
      const elapsed = length * 0.6 / motion.speedMps
      expect(distance(first, second) / elapsed).toBeCloseTo(motion.speedMps, 10)
      if (index < route.points.length - 1) {
        const nextLength = distance(to, route.points[index + 1])
        if (nextLength === 0) continue
        const step = Math.min(length, nextLength) / 4
        const before = sampleMotionRoute(route, route.cumulativeDistances[index] - step, false).position
        const after = sampleMotionRoute(route, route.cumulativeDistances[index] + step, false).position
        expect((distance(before, to) + distance(to, after)) / (2 * step / motion.speedMps)).toBeCloseTo(motion.speedMps, 10)
      }
    }
  })

  it('finishes one full circuit including the return when not looping', () => {
    const route = buildMotionRoute(room, receiver, { ...createMotionConfig(), pattern, loop: false }, [-0.6, 0.7, 1.5])
    expect(sampleMotionRoute(route, route.lengthM - 1e-8, false).done).toBe(false)
    for (const distanceM of [route.lengthM, route.lengthM + 1, Number.MAX_VALUE]) {
      expect(sampleMotionRoute(route, distanceM, false)).toEqual({ position: route.points[1], done: true })
    }
    expect(sampleMotionRoute(route, Number.MAX_VALUE, true).position.every(Number.isFinite)).toBe(true)
    expect(sampleMotionRoute(route, Number.MAX_VALUE, true).done).toBe(false)
  })

  it('does not mutate or share frozen input data or sampled positions', () => {
    const active = createReceiver(room, 'drone')
    const motion = createMotionConfig()
    motion.pattern = pattern
    Object.freeze(active.position)
    Object.freeze(active)
    Object.freeze(motion)
    const dimensions = Object.freeze({ ...room })
    const route = buildMotionRoute(dimensions, active, motion)
    const original = JSON.stringify(route)
    route.points.forEach(Object.freeze)
    Object.freeze(route.points)
    Object.freeze(route.cumulativeDistances)
    Object.freeze(route)
    for (const distanceM of [0, route.leadInLengthM, route.lengthM / 2, route.lengthM, route.lengthM + 1]) {
      for (const loop of [true, false]) {
        const sampled = sampleMotionRoute(route, distanceM, loop)
        expect(route.points.includes(sampled.position)).toBe(false)
        sampled.position[0] = 100
      }
    }
    expect(JSON.stringify(route)).toBe(original)
    expect(active.position).toEqual([0, 0, 0.3])
    expect(motion).toEqual({ ...createMotionConfig(), pattern })
    expect(buildMotionRoute(dimensions, active, motion)).toEqual(route)
  })
})

describe('pattern geometry', () => {
  it('uses 96 circular segments with radius limited by the tighter safe half-axis', () => {
    const dimensions = { width: 2, depth: 8, height: 2 }
    const active = { ...createReceiver(dimensions, 'drone'), yaw: 45 }
    const motion = { ...createMotionConfig(), pattern: 'circle' as const, extentM: 4 }
    const route = buildMotionRoute(dimensions, active, motion)
    const radius = getReceiverBounds(dimensions, active.platform, active.yaw).x[1]
    expect(route.points).toHaveLength(98)
    route.points.slice(1).forEach(([x, y, z]) => {
      expect(Math.hypot(x, y)).toBeCloseTo(radius, 12)
      expect(z).toBe(0.3)
    })
    expect(route.loopLengthM).toBeCloseTo(96 * 2 * radius * Math.sin(Math.PI / 96), 11)
    expect(motion.extentM).toBe(4)
  })

  it.each([{ width: 2, depth: 10, height: 2 }, { width: 10, depth: 2, height: 2 }])(
    'uses 160 figure-eight segments with independent X and 0.6-scaled Y extents in %j',
    (dimensions) => {
      const active = { ...createReceiver(dimensions, 'drone'), yaw: 45 }
      const motion = { ...createMotionConfig(), extentM: 4 }
      const bounds = getReceiverBounds(dimensions, active.platform, active.yaw)
      const route = buildMotionRoute(dimensions, active, motion)
      expect(route.points).toHaveLength(162)
      const extentX = Math.min(4, bounds.x[1])
      const extentY = Math.min(2.4, bounds.y[1])
      route.points.slice(1, -1).forEach((point, index) => {
        const theta = index * 2 * Math.PI / 160
        expectPosition(point, [extentX * Math.sin(theta), extentY * Math.sin(2 * theta), 0.3])
      })
    },
  )

  it('covers five alternating raster rows and returns along the perimeter rather than diagonally', () => {
    const dimensions = { width: 2, depth: 8, height: 2 }
    const active = createReceiver(dimensions)
    const motion = { ...createMotionConfig(), pattern: 'raster' as const, extentM: 2 }
    const route = buildMotionRoute(dimensions, active, motion)
    const x = getReceiverBounds(dimensions).x[1]
    expect(route.points.slice(1)).toEqual([
      [-x, -2, 0.3], [x, -2, 0.3],
      [x, -1, 0.3], [-x, -1, 0.3],
      [-x, 0, 0.3], [x, 0, 0.3],
      [x, 1, 0.3], [-x, 1, 0.3],
      [-x, 2, 0.3], [x, 2, 0.3],
      [x, -2, 0.3], [-x, -2, 0.3],
    ])
    expect(route.loopLengthM).toBeCloseTo(12 * x + 4 * 2, 12)
  })
})

describe('invalid and degenerate motion sampling', () => {
  const route: MotionRoute = {
    points: [[0, 0, 0.3], [1, 0, 0.3], [1, 0, 0.3], [1, 2, 0.3], [1, 0, 0.3], [1, 0, 0.3]],
    cumulativeDistances: [0, 1, 1, 3, 5, 5],
    lengthM: 5,
    leadInLengthM: 1,
    loopLengthM: 4,
  }

  it.each([-1, NaN, Infinity, -Infinity])('explicitly rejects invalid distance %s', (distanceM) => {
    expect(() => sampleMotionRoute(route, distanceM, true)).toThrow(RangeError)
    expect(() => sampleMotionRoute(route, distanceM, false)).toThrow(RangeError)
  })

  it('rejects an empty route instead of inventing a position', () => {
    expect(() => sampleMotionRoute({ points: [], cumulativeDistances: [], lengthM: 0, leadInLengthM: 0, loopLengthM: 0 }, 0, true)).toThrow(RangeError)
  })

  it('skips duplicate vertices and zero distances at the lead, middle, and exact loop end', () => {
    for (const loop of [true, false]) {
      expectPosition(sampleMotionRoute(route, 0, loop).position, [0, 0, 0.3])
      expectPosition(sampleMotionRoute(route, 1, loop).position, [1, 0, 0.3])
      expectPosition(sampleMotionRoute(route, 2, loop).position, [1, 1, 0.3])
      expectPosition(sampleMotionRoute(route, 3, loop).position, [1, 2, 0.3])
      expectPosition(sampleMotionRoute(route, 5, loop).position, [1, 0, 0.3])
    }
    expect(sampleMotionRoute(route, 5, true).done).toBe(false)
    expect(sampleMotionRoute(route, 5, false).done).toBe(true)
    expectPosition(sampleMotionRoute(route, 6, true).position, [1, 1, 0.3])
    const zeroLead = buildMotionRoute(room, receiver, createMotionConfig())
    expect(zeroLead.leadInLengthM).toBe(0)
    expect(zeroLead.cumulativeDistances.slice(0, 2)).toEqual([0, 0])
    expect(sampleMotionRoute(zeroLead, 0, true)).toEqual({ position: receiver.position, done: false })
  })

  it.each([1, 3])('completes a stationary route with %i vertices without NaNs', (count) => {
    const stationary: MotionRoute = {
      points: Array.from({ length: count }, () => [0.2, -0.4, 0.3]),
      cumulativeDistances: Array(count).fill(0),
      lengthM: 0,
      leadInLengthM: 0,
      loopLengthM: 0,
    }
    for (const loop of [true, false]) {
      for (const distanceM of [0, 1, Number.MAX_VALUE]) {
        const sample = sampleMotionRoute(stationary, distanceM, loop)
        expect(sample).toEqual({ position: [0.2, -0.4, 0.3], done: true })
        expect(sample.position).not.toBe(stationary.points[0])
      }
    }
  })

  it('traverses a lead-only route once even when looping is requested', () => {
    const leadOnly: MotionRoute = { points: [[0, 0, 0.3], [1, 0, 0.3]], cumulativeDistances: [0, 1], lengthM: 1, leadInLengthM: 1, loopLengthM: 0 }
    expect(sampleMotionRoute(leadOnly, 0.5, true)).toEqual({ position: [0.5, 0, 0.3], done: false })
    expect(sampleMotionRoute(leadOnly, 1, true)).toEqual({ position: [1, 0, 0.3], done: true })
    expect(sampleMotionRoute(leadOnly, 2, true)).toEqual({ position: [1, 0, 0.3], done: true })
  })

  it.each([[NaN, 0, 0.3], [0, Infinity, 0.3], [0, 0, -Infinity]])('rejects a nonfinite start %j', (x, y, z) => {
    expect(() => buildMotionRoute(room, receiver, createMotionConfig(), [x, y, z])).toThrow(RangeError)
  })
})
