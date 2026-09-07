import { describe, expect, it } from 'vitest'
import {
  DRONE_GEOMETRY,
  RECEIVER_GEOMETRY,
  RECEIVER_ID,
  clampReceiverPosition,
  createReceiver,
  getPhotodiodePosition,
  getReceiverBounds,
  getReceiverGeometry,
  getReceiverRadius,
  normalizeReceiver,
} from './receiver'
import type { ReceiverConfig, ReceiverPlatform, RoomConfig, WorldPosition } from './types'

const room: RoomConfig = Object.freeze({ width: 3, depth: 3, height: 2 })
const customRoom: RoomConfig = Object.freeze({ width: 7, depth: 5, height: 3.1 })
const platforms: ReceiverPlatform[] = ['cylinder', 'drone']
const yaws = [0, 15, 30, 45, 60, 90, 135, 180, 225, 270, 315, 359.5, -45, 405]

function freezeReceiver(receiver: ReceiverConfig): ReceiverConfig {
  Object.freeze(receiver.position)
  return Object.freeze(receiver)
}

describe('receiver identity and fixed geometry', () => {
  it('defines one 10 cm platform with a 1 cm square photodiode in metres', () => {
    expect(RECEIVER_ID).toBe('RX-01')
    expect(RECEIVER_GEOMETRY).toEqual({
      diameter: 0.1,
      height: 0.08,
      pdWidth: 0.01,
      pdDepth: 0.01,
      pdThickness: 0.002,
      clearance: 0.01,
    })
  })

  it('creates fresh receivers centered in XY with a body center at 0.3 m in default and custom rooms', () => {
    expect(createReceiver(room)).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
    expect(createReceiver(customRoom)).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
    const first = createReceiver(customRoom)
    first.position[0] = 2
    first.position[2] = 1.2
    first.yaw = 90
    const reset = createReceiver(customRoom)
    expect(reset).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
    expect(reset).not.toBe(first)
    expect(reset.position).not.toBe(first.position)
    expect(customRoom).toEqual({ width: 7, depth: 5, height: 3.1 })
  })

  it('clamps the default body center to the physical bounds of a short room', () => {
    const shortRoom = Object.freeze({ width: 3, depth: 3, height: 0.2 })
    const receiver = createReceiver(shortRoom)
    expect(receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.2 - 0.04 - 0.002 - 0.01], yaw: 0 })
    expect(receiver.position[2]).toBeGreaterThanOrEqual(getReceiverBounds(shortRoom).z[0])
    expect(getPhotodiodePosition(receiver)[2] + 0.001).toBeCloseTo(shortRoom.height - 0.01, 12)
    expect(normalizeReceiver(undefined, shortRoom)).toEqual(receiver)
  })
})

describe('receiver platform geometry', () => {
  it('exposes a unified cylinder profile without changing the legacy geometry export', () => {
    expect(getReceiverGeometry()).toEqual({ ...RECEIVER_GEOMETRY, width: 0.1, depth: 0.1 })
    expect(getReceiverGeometry('cylinder')).toEqual(getReceiverGeometry())
    expect(getReceiverRadius()).toBe(0.05)
    expect(getReceiverRadius('cylinder')).toBe(0.05)
    expect(Object.keys(RECEIVER_GEOMETRY).sort()).toEqual(['clearance', 'diameter', 'height', 'pdDepth', 'pdThickness', 'pdWidth'])
  })

  it('defines the drone body height, complete rotor envelope and centered top PD in metres', () => {
    expect(DRONE_GEOMETRY).toEqual({
      width: 0.28,
      depth: 0.28,
      height: 0.06,
      motorOffset: 0.08,
      rotorRadius: 0.06,
      pdWidth: 0.01,
      pdDepth: 0.01,
      pdThickness: 0.002,
      clearance: 0.01,
    })
    expect(getReceiverGeometry('drone')).toEqual(DRONE_GEOMETRY)
    expect(getReceiverRadius('drone')).toBeCloseTo(Math.SQRT2 * 0.08 + 0.06, 12)
    expect(getReceiverRadius('drone')).toBeGreaterThan(DRONE_GEOMETRY.width / 2)
  })

  it.each(platforms)('creates independent %s receivers without changing the default body center', (platform) => {
    for (const boundsRoom of [room, customRoom]) {
      const receiver = createReceiver(boundsRoom, platform)
      expect(receiver).toEqual({ position: [0, 0, 0.3], yaw: 0, platform, rotorsSpinning: true })
      expect(createReceiver(boundsRoom, platform)).not.toBe(receiver)
      expect(createReceiver(boundsRoom, platform).position).not.toBe(receiver.position)
    }
    const shortRoom = { width: 3, depth: 3, height: 0.2 }
    const receiver = createReceiver(shortRoom, platform)
    expect(receiver.position).toEqual([0, 0, getReceiverBounds(shortRoom, platform).z[1]])
    expect(getPhotodiodePosition(receiver)[2] + 0.001).toBeCloseTo(0.19, 12)
    expect(normalizeReceiver({ platform }, shortRoom)).toEqual(receiver)
  })

  it('uses the axis-aligned rotor envelope for unrotated drone bounds', () => {
    expect(getReceiverBounds(room, 'drone')).toEqual({
      x: [-1.35, 1.35],
      y: [-1.35, 1.35],
      z: [0.04, 2 - 0.03 - 0.002 - 0.01],
    })
    expect(getReceiverBounds(customRoom, 'drone')).toEqual({
      x: [-3.35, 3.35],
      y: [-2.35, 2.35],
      z: [0.04, 3.1 - 0.03 - 0.002 - 0.01],
    })
  })

  it.each(yaws)('computes drone bounds from rotated motor centers plus circular guards at yaw %s', (yaw) => {
    const angle = yaw * Math.PI / 180
    const halfSpan = 0.08 * (Math.abs(Math.cos(angle)) + Math.abs(Math.sin(angle))) + 0.06
    const bounds = getReceiverBounds(customRoom, 'drone', yaw)
    expect(bounds.x).toEqual([-3.5 + (halfSpan + 0.01), 3.5 - (halfSpan + 0.01)])
    expect(bounds.y).toEqual([-2.5 + (halfSpan + 0.01), 2.5 - (halfSpan + 0.01)])
    expect(bounds.z).toEqual([0.04, 3.1 - 0.03 - 0.002 - 0.01])
    expect(getReceiverBounds(room, 'cylinder', yaw)).toEqual(getReceiverBounds(room))
    expect(clampReceiverPosition([99, -99, 99], customRoom, 'drone', yaw))
      .toEqual([bounds.x[1], bounds.y[0], bounds.z[1]])
    expect(clampReceiverPosition([-99, 99, -99], customRoom, 'drone', yaw))
      .toEqual([bounds.x[0], bounds.y[1], bounds.z[0]])
  })

  it.each(yaws)('keeps every rotating rotor, guard, body and PD inside all room faces at yaw %s', (yaw) => {
    const angle = yaw * Math.PI / 180
    const cos = Math.cos(angle)
    const sin = Math.sin(angle)
    const boundsRoom = { width: 2, depth: 3, height: 1.8 }
    const bounds = getReceiverBounds(boundsRoom, 'drone', yaw)
    for (const x of bounds.x) {
      for (const y of bounds.y) {
        for (const z of bounds.z) {
          const receiver = freezeReceiver({ position: [x, y, z], yaw, platform: 'drone', rotorsSpinning: true })
          for (const motorX of [-0.08, 0.08]) {
            for (const motorY of [-0.08, 0.08]) {
              for (let phase = 0; phase < 360; phase += 15) {
                const localX = motorX + 0.06 * Math.cos(phase * Math.PI / 180)
                const localY = motorY + 0.06 * Math.sin(phase * Math.PI / 180)
                const offsetX = localX * cos - localY * sin
                const offsetY = localX * sin + localY * cos
                expect(Math.abs(x + offsetX)).toBeLessThanOrEqual(boundsRoom.width / 2 - 0.01 + 1e-12)
                expect(Math.abs(y + offsetY)).toBeLessThanOrEqual(boundsRoom.depth / 2 - 0.01 + 1e-12)
                expect(Math.hypot(offsetX, offsetY)).toBeLessThanOrEqual(getReceiverRadius('drone') + 1e-12)
              }
            }
          }
          const pd = getPhotodiodePosition(receiver)
          expect(Math.abs(pd[0]) + Math.hypot(0.005, 0.005)).toBeLessThan(boundsRoom.width / 2 - 0.01)
          expect(Math.abs(pd[1]) + Math.hypot(0.005, 0.005)).toBeLessThan(boundsRoom.depth / 2 - 0.01)
          expect(z - 0.03).toBeGreaterThanOrEqual(0.01 - 1e-12)
          expect(pd[2] + 0.001).toBeLessThanOrEqual(boundsRoom.height - 0.01 + 1e-12)
          expect(clampReceiverPosition(receiver.position, boundsRoom, 'drone', yaw)).toEqual(receiver.position)
        }
      }
    }
  })

  it('tightens only XY bounds on a 45-degree drone rotation without using a rotated bounding box', () => {
    const straight = getReceiverBounds(room, 'drone', 0)
    const diagonal = getReceiverBounds(room, 'drone', 45)
    expect(diagonal.x[1]).toBeCloseTo(1.5 - Math.SQRT2 * 0.08 - 0.06 - 0.01, 12)
    expect(diagonal.x[1]).toBeLessThan(straight.x[1])
    expect(diagonal.x[1]).toBeGreaterThan(1.5 - Math.SQRT2 * 0.14 - 0.01)
    expect(diagonal.z).toEqual(straight.z)
  })
})

describe('receiver bounds and clamping', () => {
  it('computes exact center limits with body radius, body height, top PD, and clearance', () => {
    expect(getReceiverBounds(room)).toEqual({
      x: [-1.44, 1.44],
      y: [-1.44, 1.44],
      z: [0.05, 2 - 0.04 - 0.002 - 0.01],
    })
    expect(getReceiverBounds(customRoom)).toEqual({
      x: [-3.44, 3.44],
      y: [-2.44, 2.44],
      z: [0.05, 3.1 - 0.04 - 0.002 - 0.01],
    })
  })

  it.each([room, customRoom, { width: 2, depth: 2, height: 1.8 }])(
    'keeps the complete body and PD inside every face of room %j',
    (boundsRoom) => {
      const bounds = getReceiverBounds(boundsRoom)
      for (const x of bounds.x) {
        for (const y of bounds.y) {
          for (const z of bounds.z) {
            const receiver: ReceiverConfig = { position: [x, y, z], yaw: 45, platform: 'cylinder', rotorsSpinning: true }
            const photodiode = getPhotodiodePosition(receiver)
            expect(Math.abs(x) + 0.05).toBeLessThanOrEqual(boundsRoom.width / 2 - 0.01 + 1e-12)
            expect(Math.abs(y) + 0.05).toBeLessThanOrEqual(boundsRoom.depth / 2 - 0.01 + 1e-12)
            expect(z - 0.04).toBeGreaterThanOrEqual(0.01 - 1e-12)
            expect(photodiode[2] + 0.001).toBeLessThanOrEqual(boundsRoom.height - 0.01 + 1e-12)
            const pdHalfDiagonal = Math.hypot(0.005, 0.005)
            expect(Math.abs(photodiode[0]) + pdHalfDiagonal).toBeLessThan(boundsRoom.width / 2 - 0.01)
            expect(Math.abs(photodiode[1]) + pdHalfDiagonal).toBeLessThan(boundsRoom.depth / 2 - 0.01)
            expect(clampReceiverPosition(receiver.position, boundsRoom)).toEqual(receiver.position)
          }
        }
      }
    },
  )

  it('clamps each coordinate to its bounds without mutating or reusing the input tuple', () => {
    const position: WorldPosition = [99, -99, 99]
    Object.freeze(position)
    const bounds = getReceiverBounds(customRoom)
    expect(clampReceiverPosition(position, customRoom)).toEqual([bounds.x[1], bounds.y[0], bounds.z[1]])
    expect(clampReceiverPosition([-99, 99, -99], customRoom)).toEqual([bounds.x[0], bounds.y[1], bounds.z[0]])
    const inside: WorldPosition = [0.2, -0.3, 1.4]
    Object.freeze(inside)
    const clamped = clampReceiverPosition(inside, customRoom)
    expect(clamped).toEqual(inside)
    expect(clamped).not.toBe(inside)
    clamped[0] = 9
    expect(inside).toEqual([0.2, -0.3, 1.4])
    expect(position).toEqual([99, -99, 99])
  })

  it('returns independent bounds on every call', () => {
    const bounds = getReceiverBounds(room)
    bounds.x[0] = 0
    bounds.y[0] = 0
    bounds.z[0] = 0
    expect(getReceiverBounds(room)).toEqual({ x: [-1.44, 1.44], y: [-1.44, 1.44], z: [0.05, 1.948] })
  })
})

describe('receiver normalization', () => {
  it.each([
    undefined, null, false, true, 0, 7, NaN, Infinity, '', 'receiver', [], [1, 2, 3],
    Object.assign([], { position: [0.1, 0.2, 0.3], yaw: 90 }), () => ({ position: [0, 0, 1], yaw: 90 }),
  ].map((input) => [input]))('defaults invalid receiver input %s to the XY center at 0.3 m', (input) => {
    expect(normalizeReceiver(input, customRoom)).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 0 })
  })

  it.each([
    undefined, null, false, true, 1, NaN, Infinity, '0,0,1', {}, { 0: 0, 1: 0, 2: 1, length: 3 },
    [], [0], [0, 1], [0, 0, 1, 2], [NaN, 0, 1], [0, Infinity, 1], [0, 0, -Infinity],
    ['0', 0, 1], [0, null, 1], [0, 0, true], [0, 0, undefined], [[], 0, 1], [0, {}, 1],
    Array(3), new Float64Array([0, 0, 1]),
  ].map((position) => [position]))('rejects the entire invalid position %j without coercing or retaining partial values', (position) => {
    expect(normalizeReceiver({ position, yaw: 45 }, customRoom)).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 45 })
  })

  it.each([undefined, null, false, true, NaN, Infinity, -Infinity, '90', [], [90], {}, Object(90)].map((yaw) => [yaw]))(
    'defaults invalid yaw %s without discarding a valid position',
    (yaw) => expect(normalizeReceiver({ position: [0.2, -0.3, 1.4], yaw }, room))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 0 }),
  )

  it.each([
    [0, 0], [-0, 0], [90, 90], [123.45, 123.45], [359.999, 359.999], [360, 0], [720, 0],
    [-360, 0], [-90, 270], [810.25, 90.25], [-810.25, 269.75], [Number.MIN_VALUE, Number.MIN_VALUE],
  ])('normalizes finite yaw %s degrees to %s degrees', (yaw, expected) => {
    expect(normalizeReceiver({ yaw }, room).yaw).toBe(expected)
  })

  it.each([Number.MAX_VALUE, -Number.MAX_VALUE, -Number.MIN_VALUE, -1e-14])(
    'keeps extreme finite yaw %s in the half-open range [0, 360)',
    (yaw) => {
      const receiver = normalizeReceiver({ yaw }, room)
      expect(receiver.yaw).toBeGreaterThanOrEqual(0)
      expect(receiver.yaw).toBeLessThan(360)
      expect(normalizeReceiver(receiver, room)).toEqual(receiver)
    },
  )

  it('clamps valid out-of-bounds positions and preserves independent yaw normalization', () => {
    expect(normalizeReceiver({ position: [99, -99, 99], yaw: -450 }, room))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [1.44, -1.44, 1.948], yaw: 270 })
    expect(normalizeReceiver({ position: [-99, 99, -99] }, room))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [-1.44, 1.44, 0.05], yaw: 0 })
  })

  it('accepts only own fields and own array coordinates, including null-prototype records', () => {
    expect(normalizeReceiver(Object.create({ position: [0.2, -0.3, 1.4], yaw: 90 }), room)).toEqual(createReceiver(room))
    expect(normalizeReceiver(Object.assign(Object.create({ yaw: 90 }), { position: [0.2, -0.3, 1.4] }), room))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 0 })
    expect(normalizeReceiver(Object.assign(Object.create({ position: [0.2, -0.3, 1.4] }), { yaw: 90 }), room))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 90 })
    const inheritedPosition = [0.2, -0.3, 1.4]
    delete inheritedPosition[1]
    Object.setPrototypeOf(inheritedPosition, Object.assign(Object.create(Array.prototype), { 1: -0.3 }))
    expect(normalizeReceiver({ position: inheritedPosition, yaw: 90 }, customRoom))
      .toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 0.3], yaw: 90 })
    const ownReceiver = Object.assign(Object.create(null), { position: [0.2, -0.3, 1.4], yaw: 90 })
    expect(normalizeReceiver(ownReceiver, room)).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 90 })
  })

  it('ignores hostile keys, geometry overrides, and unknown fields without prototype pollution', () => {
    const hostile = JSON.parse('{"position":[0.2,-0.3,1.4],"yaw":90,"__proto__":{"polluted":true},"constructor":{"prototype":{"polluted":true}},"prototype":{"polluted":true},"diameter":3,"pdWidth":2,"tilt":45,"id":"RX-02"}')
    const before = JSON.stringify(hostile)
    const receiver = normalizeReceiver(hostile, room)
    expect(receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 90 })
    expect(Object.getPrototypeOf(receiver)).toBe(Object.prototype)
    expect(Object.prototype.hasOwnProperty.call(receiver, '__proto__')).toBe(false)
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'polluted')).toBe(false)
    expect(JSON.stringify(hostile)).toBe(before)
    expect(RECEIVER_GEOMETRY.diameter).toBe(0.1)
    expect(RECEIVER_GEOMETRY.pdWidth).toBe(0.01)
  })

  it('preserves a saved pose at the former default height instead of applying the new default', () => {
    const saved = freezeReceiver({ platform: 'cylinder', rotorsSpinning: true, position: [0, 0, 1], yaw: 0 })
    expect(normalizeReceiver(saved, room)).toEqual(saved)
    expect(normalizeReceiver(JSON.parse(JSON.stringify(saved)), room)).toEqual(saved)
  })

  it('preserves custom coordinates and fractional yaw with fresh data, no mutation, and stable JSON round trips', () => {
    const saved = freezeReceiver({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 123.45 })
    const before = JSON.stringify(saved)
    const receiver = normalizeReceiver(saved, room)
    expect(receiver).toEqual(saved)
    expect(receiver).not.toBe(saved)
    expect(receiver.position).not.toBe(saved.position)
    expect(normalizeReceiver(receiver, room)).toEqual(receiver)
    expect(normalizeReceiver(JSON.parse(before), room)).toEqual(saved)
    receiver.position[0] = 0.8
    receiver.yaw = 80
    expect(JSON.stringify(saved)).toBe(before)
    expect(normalizeReceiver(saved, room)).toEqual(saved)
  })
})

describe('receiver platform normalization and migration', () => {
  it.each([
    undefined, null, false, true, 0, NaN, Infinity, '', 'unknown', 'Drone', 'CYLINDER', ' drone ',
    '__proto__', 'constructor', 'toString', [], ['drone'], {}, { platform: 'drone' },
    { toString: () => 'drone' }, Object('drone'),
  ].map((platform) => [platform]))('defaults invalid platform %s without discarding valid pose or rotor settings', (platform) => {
    expect(normalizeReceiver({ position: [0.2, -0.3, 1.4], yaw: 123.45, platform, rotorsSpinning: false }, room))
      .toEqual({ position: [0.2, -0.3, 1.4], yaw: 123.45, platform: 'cylinder', rotorsSpinning: false })
  })

  it.each(platforms)('preserves valid %s data exactly without mutation through repeated normalization and JSON', (platform) => {
    for (const rotorsSpinning of [false, true]) {
      const saved = freezeReceiver({ position: [0.234567, -0.345678, 1.456789], yaw: 123.456789, platform, rotorsSpinning })
      const before = JSON.stringify(saved)
      const normalized = normalizeReceiver(saved, room)
      expect(normalized).toEqual(saved)
      expect(normalized).not.toBe(saved)
      expect(normalized.position).not.toBe(saved.position)
      expect(normalizeReceiver(normalized, room)).toEqual(saved)
      expect(normalizeReceiver(JSON.parse(before), room)).toEqual(saved)
      expect(JSON.stringify(saved)).toBe(before)
    }
  })

  it.each([
    undefined, null, 0, 1, NaN, Infinity, '', 'true', 'false', [], [false], {}, Object(false),
  ].map((rotorsSpinning) => [rotorsSpinning]))('defaults nonboolean rotor animation %s without coercion on either platform', (rotorsSpinning) => {
    for (const platform of platforms) {
      expect(normalizeReceiver({ position: [0.2, -0.3, 1.4], yaw: 45, platform, rotorsSpinning }, room))
        .toEqual({ position: [0.2, -0.3, 1.4], yaw: 45, platform, rotorsSpinning: true })
    }
  })

  it('rejects inherited platform and rotor fields but accepts own null-prototype fields', () => {
    const pose = { position: [0.2, -0.3, 1.4], yaw: 45 }
    const inherited = Object.assign(Object.create({ platform: 'drone', rotorsSpinning: false }), pose)
    expect(normalizeReceiver(inherited, room)).toEqual({ ...pose, platform: 'cylinder', rotorsSpinning: true })
    const own = Object.assign(Object.create(null), { ...pose, platform: 'drone', rotorsSpinning: false })
    expect(normalizeReceiver(own, room)).toEqual({ ...pose, platform: 'drone', rotorsSpinning: false })
    const hostile = JSON.parse('{"platform":"__proto__","rotorsSpinning":false,"__proto__":{"platform":"drone"},"constructor":{"prototype":{"platform":"drone"}}}')
    expect(normalizeReceiver(hostile, room)).toEqual({ position: [0, 0, 0.3], yaw: 0, platform: 'cylinder', rotorsSpinning: false })
    expect(Object.prototype.hasOwnProperty.call(Object.prototype, 'platform')).toBe(false)
  })

  it.each([0.3, 1, 1.234567])('migrates serialized legacy pose at height %s without resetting any coordinate or yaw', (height) => {
    const legacy = { position: [0.123456, -0.234567, height], yaw: 234.56789 }
    const serialized = JSON.stringify(legacy)
    expect(normalizeReceiver(JSON.parse(serialized), room))
      .toEqual({ ...legacy, platform: 'cylinder', rotorsSpinning: true })
    expect(JSON.stringify(legacy)).toBe(serialized)
  })

  it('decodes drone platform and normalized yaw before clamping the entire rotated envelope', () => {
    const bounds = getReceiverBounds(room, 'drone', 45)
    expect(normalizeReceiver({ position: [1.44, -1.44, 0], yaw: 405, platform: 'drone', rotorsSpinning: false }, room))
      .toEqual({ position: [bounds.x[1], bounds.y[0], 0.04], yaw: 45, platform: 'drone', rotorsSpinning: false })
    expect(normalizeReceiver({ position: [99, -99, 99], yaw: -315, platform: 'drone' }, room))
      .toEqual({ position: [bounds.x[1], bounds.y[0], bounds.z[1]], yaw: 45, platform: 'drone', rotorsSpinning: true })
    expect(normalizeReceiver({ position: [99, -99, 1.958], yaw: '45', platform: 'drone' }, room))
      .toEqual({ position: [1.35, -1.35, 1.958], yaw: 0, platform: 'drone', rotorsSpinning: true })
  })

  it('preserves pose on a platform change unless the new body or rotating guards need clearance', () => {
    const cylinder = freezeReceiver({ position: [1.44, -0.345678, 0.05], yaw: 45, platform: 'cylinder', rotorsSpinning: false })
    const drone = normalizeReceiver({ ...cylinder, platform: 'drone' }, room)
    const bounds = getReceiverBounds(room, 'drone', 45)
    expect(drone).toEqual({ ...cylinder, platform: 'drone', position: [bounds.x[1], -0.345678, 0.05] })
    expect(normalizeReceiver({ ...drone, platform: 'cylinder' }, room)).toEqual({ ...drone, platform: 'cylinder' })
    expect(normalizeReceiver({ ...drone, position: [0.2, -0.3, 0.04], platform: 'cylinder' }, room).position)
      .toEqual([0.2, -0.3, 0.05])
    expect(normalizeReceiver({ ...drone, position: [0.2, -0.3, 1.958], platform: 'cylinder' }, room).position)
      .toEqual([0.2, -0.3, 1.948])
    expect(cylinder.position).toEqual([1.44, -0.345678, 0.05])
  })

  it('clamps a near-wall drone when yaw changes without resetting its Z or animation flag', () => {
    const drone = freezeReceiver({ position: [1.35, -1.35, 0.876543], yaw: 0, platform: 'drone', rotorsSpinning: false })
    const bounds = getReceiverBounds(room, 'drone', 45)
    const rotated = normalizeReceiver({ ...drone, yaw: 45 }, room)
    expect(rotated).toEqual({ ...drone, yaw: 45, position: [bounds.x[1], bounds.y[0], 0.876543] })
    expect(normalizeReceiver({ ...rotated, rotorsSpinning: true }, room)).toEqual({ ...rotated, rotorsSpinning: true })
    expect(drone.position).toEqual([1.35, -1.35, 0.876543])
  })
})

describe('derived photodiode position', () => {
  it.each(platforms)('keeps the %s PD centered above the body independently of yaw and rotor animation', (platform) => {
    for (const yaw of yaws) {
      for (const rotorsSpinning of [false, true]) {
        const receiver = freezeReceiver({ position: [0.234567, -0.345678, 1.456789], yaw, platform, rotorsSpinning })
        const photodiode = getPhotodiodePosition(receiver)
        expect(photodiode.slice(0, 2)).toEqual([0.234567, -0.345678])
        expect(photodiode[2]).toBeCloseTo(1.456789 + (platform === 'drone' ? 0.031 : 0.041), 12)
        expect(photodiode).not.toBe(receiver.position)
        expect(getPhotodiodePosition({ ...receiver, yaw: 0, rotorsSpinning: !rotorsSpinning })).toEqual(photodiode)
      }
    }
    expect(getPhotodiodePosition(createReceiver(room, platform))[2]).toBeCloseTo(platform === 'drone' ? 0.331 : 0.341, 12)
  })

  it('puts the PD center on top of the platform along world Z without changing x or y', () => {
    const receiver = freezeReceiver({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 27 })
    const photodiode = getPhotodiodePosition(receiver)
    expect(photodiode[0]).toBe(0.2)
    expect(photodiode[1]).toBe(-0.3)
    expect(photodiode[2]).toBeCloseTo(1.441, 12)
    expect(photodiode[2] - 0.001).toBeCloseTo(receiver.position[2] + 0.04, 12)
    expect(photodiode).not.toBe(receiver.position)
    photodiode[0] = 9
    expect(receiver).toEqual({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw: 27 })
    expect(getPhotodiodePosition(createReceiver(room))[2]).toBeCloseTo(0.341, 12)
  })

  it.each([0, 45, 90, 180, 270, 359.5])('keeps the top PD center unchanged under world-Z yaw %s degrees', (yaw) => {
    const receiver = freezeReceiver({ platform: 'cylinder', rotorsSpinning: true, position: [0.2, -0.3, 1.4], yaw })
    expect(getPhotodiodePosition(receiver)).toEqual(getPhotodiodePosition({ ...receiver, yaw: 0 }))
  })
})
