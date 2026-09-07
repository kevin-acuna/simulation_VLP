import { clampReceiverPosition, getReceiverBounds } from './receiver'
import type { MotionConfig, ReceiverConfig, RoomConfig, WorldPosition } from './types'

export interface MotionRoute {
  points: WorldPosition[]
  cumulativeDistances: number[]
  lengthM: number
  leadInLengthM: number
  loopLengthM: number
}

export function createMotionConfig(): MotionConfig {
  return { pattern: 'figure-eight', extentM: 0.8, altitudeM: 0.3, speedMps: 0.25, loop: true }
}

function own(source: object, key: string): unknown {
  return Object.getOwnPropertyDescriptor(source, key)?.value
}

function finiteNumber(value: unknown, fallback: number, minimum: number, maximum: number): number {
  const number = typeof value === 'number' && Number.isFinite(value) ? value : fallback
  return Math.min(maximum, Math.max(minimum, number))
}

export function normalizeMotionConfig(input: unknown, room: RoomConfig, receiver: ReceiverConfig): MotionConfig {
  const source = input !== null && typeof input === 'object' && !Array.isArray(input) ? input : {}
  const defaults = createMotionConfig()
  const pattern = own(source, 'pattern')
  const loop = own(source, 'loop')
  const { z } = getReceiverBounds(room, receiver.platform, receiver.yaw)
  return {
    pattern: pattern === 'circle' || pattern === 'figure-eight' || pattern === 'raster' ? pattern : defaults.pattern,
    extentM: finiteNumber(own(source, 'extentM'), defaults.extentM, 0.1, 4),
    altitudeM: finiteNumber(own(source, 'altitudeM'), defaults.altitudeM, z[0], z[1]),
    speedMps: finiteNumber(own(source, 'speedMps'), defaults.speedMps, 0.05, 1),
    loop: typeof loop === 'boolean' ? loop : defaults.loop,
  }
}

export function buildMotionRoute(
  room: RoomConfig,
  receiver: ReceiverConfig,
  motion: MotionConfig,
  start: WorldPosition = receiver.position,
): MotionRoute {
  const bounds = getReceiverBounds(room, receiver.platform, receiver.yaw)
  if (Object.values(bounds).some(([minimum, maximum]) => !Number.isFinite(minimum) || !Number.isFinite(maximum) || minimum > maximum)) {
    throw new RangeError('Motion requires finite room bounds that contain the receiver')
  }
  if (start.length !== 3 || !start.every(Number.isFinite)) throw new RangeError('Motion start must contain three finite coordinates')
  const normalized = normalizeMotionConfig(motion, room, receiver)
  const { pattern, extentM, altitudeM } = normalized
  const extentX = Math.min(extentM, bounds.x[1])
  const extentY = Math.min(extentM * (pattern === 'figure-eight' ? 0.6 : 1), bounds.y[1])
  const circuit: WorldPosition[] = []

  if (pattern === 'raster') {
    for (let row = 0; row < 5; row += 1) {
      const y = -extentY + row * extentY / 2
      const x = row % 2 === 0 ? -extentX : extentX
      circuit.push([x, y, altitudeM], [-x, y, altitudeM])
    }
    circuit.push([extentX, -extentY, altitudeM])
  } else {
    const segments = pattern === 'circle' ? 96 : 160
    const radius = Math.min(extentX, extentY)
    for (let index = 0; index < segments; index += 1) {
      const theta = index * 2 * Math.PI / segments
      circuit.push(pattern === 'circle'
        ? [radius * Math.cos(theta), radius * Math.sin(theta), altitudeM]
        : [extentX * Math.sin(theta), extentY * Math.sin(2 * theta), altitudeM])
    }
  }
  circuit.push([...circuit[0]])
  const points = [clampReceiverPosition(start, room, receiver.platform, receiver.yaw), ...circuit]
  const cumulativeDistances = [0]
  for (let index = 1; index < points.length; index += 1) {
    const previous = points[index - 1]
    const point = points[index]
    cumulativeDistances.push(cumulativeDistances[index - 1] + Math.hypot(point[0] - previous[0], point[1] - previous[1], point[2] - previous[2]))
  }
  const lengthM = cumulativeDistances[cumulativeDistances.length - 1]
  const leadInLengthM = cumulativeDistances[1]
  return { points, cumulativeDistances, lengthM, leadInLengthM, loopLengthM: lengthM - leadInLengthM }
}

export function sampleMotionRoute(route: MotionRoute, distanceM: number, loop: boolean): { position: WorldPosition, done: boolean } {
  if (!Number.isFinite(distanceM) || distanceM < 0) throw new RangeError('Motion distance must be finite and nonnegative')
  const { points, cumulativeDistances, lengthM, leadInLengthM, loopLengthM } = route
  if (points.length === 0 || points.length !== cumulativeDistances.length) throw new RangeError('Motion route must contain points and matching distances')
  if ([lengthM, leadInLengthM, loopLengthM].some((value) => !Number.isFinite(value) || value < 0)) {
    throw new RangeError('Motion route lengths must be finite and nonnegative')
  }
  const repeating = loop && loopLengthM > 0
  const done = lengthM === 0 || (!repeating && distanceM >= lengthM)
  if (done) return { position: [...points[points.length - 1]], done: true }
  const target = repeating && distanceM >= leadInLengthM
    ? leadInLengthM + (distanceM - leadInLengthM) % loopLengthM
    : distanceM
  if (target === 0) return { position: [...points[0]], done: false }
  if (target >= lengthM) return { position: [...points[points.length - 1]], done: false }

  let low = 1
  let high = points.length - 1
  while (low < high) {
    const middle = Math.floor((low + high) / 2)
    if (cumulativeDistances[middle] <= target) low = middle + 1
    else high = middle
  }
  const segmentLength = cumulativeDistances[low] - cumulativeDistances[low - 1]
  const fraction = segmentLength > 0 ? (target - cumulativeDistances[low - 1]) / segmentLength : 0
  const from = points[low - 1]
  const to = points[low]
  return {
    position: [
      from[0] + (to[0] - from[0]) * fraction,
      from[1] + (to[1] - from[1]) * fraction,
      from[2] + (to[2] - from[2]) * fraction,
    ],
    done: false,
  }
}
