import type { ReceiverConfig, ReceiverPlatform, RoomConfig, WorldPosition } from './types'

export const RECEIVER_ID = 'RX-01'

export const RECEIVER_GEOMETRY = {
  diameter: 0.1,
  height: 0.08,
  pdWidth: 0.01,
  pdDepth: 0.01,
  pdThickness: 0.002,
  clearance: 0.01,
} as const

export const DRONE_GEOMETRY = {
  width: 0.28,
  depth: 0.28,
  height: 0.06,
  motorOffset: 0.08,
  rotorRadius: 0.06,
  pdWidth: 0.01,
  pdDepth: 0.01,
  pdThickness: 0.002,
  clearance: 0.01,
} as const

export interface ReceiverGeometry {
  readonly width: number
  readonly depth: number
  readonly height: number
  readonly pdWidth: number
  readonly pdDepth: number
  readonly pdThickness: number
  readonly clearance: number
  readonly diameter?: number
  readonly motorOffset?: number
  readonly rotorRadius?: number
}

export function getReceiverGeometry(platform: ReceiverPlatform = 'cylinder'): ReceiverGeometry {
  return platform === 'drone'
    ? DRONE_GEOMETRY
    : { ...RECEIVER_GEOMETRY, width: RECEIVER_GEOMETRY.diameter, depth: RECEIVER_GEOMETRY.diameter }
}

export function getReceiverRadius(platform: ReceiverPlatform = 'cylinder'): number {
  return platform === 'drone'
    ? Math.SQRT2 * DRONE_GEOMETRY.motorOffset + DRONE_GEOMETRY.rotorRadius
    : RECEIVER_GEOMETRY.diameter / 2
}

export function createReceiver(room: RoomConfig, platform: ReceiverPlatform = 'cylinder'): ReceiverConfig {
  return { position: clampReceiverPosition([0, 0, 0.3], room, platform), yaw: 0, platform, rotorsSpinning: true }
}

export function getReceiverBounds(
  room: RoomConfig,
  platform: ReceiverPlatform = 'cylinder',
  yaw = 0,
): { x: [number, number], y: [number, number], z: [number, number] } {
  const { height, pdThickness, clearance } = getReceiverGeometry(platform)
  const angle = yaw * Math.PI / 180
  const halfSpan = platform === 'drone'
    ? DRONE_GEOMETRY.motorOffset * (Math.abs(Math.cos(angle)) + Math.abs(Math.sin(angle))) + DRONE_GEOMETRY.rotorRadius
    : RECEIVER_GEOMETRY.diameter / 2
  const margin = halfSpan + clearance
  return {
    x: [-room.width / 2 + margin, room.width / 2 - margin],
    y: [-room.depth / 2 + margin, room.depth / 2 - margin],
    z: [height / 2 + clearance, room.height - height / 2 - pdThickness - clearance],
  }
}

export function clampReceiverPosition(
  position: WorldPosition,
  room: RoomConfig,
  platform: ReceiverPlatform = 'cylinder',
  yaw = 0,
): WorldPosition {
  const bounds = getReceiverBounds(room, platform, yaw)
  return [
    Math.min(bounds.x[1], Math.max(bounds.x[0], position[0])),
    Math.min(bounds.y[1], Math.max(bounds.y[0], position[1])),
    Math.min(bounds.z[1], Math.max(bounds.z[0], position[2])),
  ]
}

function own(source: object, key: string): unknown {
  return Object.prototype.hasOwnProperty.call(source, key) ? (source as Record<string, unknown>)[key] : undefined
}

function finiteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value)
}

export function normalizeReceiver(input: unknown, room: RoomConfig): ReceiverConfig {
  const source = input !== null && typeof input === 'object' && !Array.isArray(input) ? input : {}
  const platform = own(source, 'platform') === 'drone' ? 'drone' : 'cylinder'
  const receiver = createReceiver(room, platform)
  const rotorsSpinning = own(source, 'rotorsSpinning')
  if (typeof rotorsSpinning === 'boolean') receiver.rotorsSpinning = rotorsSpinning
  const position = own(source, 'position')
  if (Array.isArray(position) && position.length === 3) {
    const x = own(position, '0')
    const y = own(position, '1')
    const z = own(position, '2')
    if (finiteNumber(x) && finiteNumber(y) && finiteNumber(z)) receiver.position = [x, y, z]
  }
  const yaw = own(source, 'yaw')
  if (finiteNumber(yaw)) {
    const remainder = yaw % 360
    receiver.yaw = (remainder < 0 ? (remainder + 360) % 360 : remainder) || 0
  }
  receiver.position = clampReceiverPosition(receiver.position, room, receiver.platform, receiver.yaw)
  return receiver
}

export function getPhotodiodePosition(receiver: ReceiverConfig): WorldPosition {
  const [x, y, z] = receiver.position
  const { height, pdThickness } = getReceiverGeometry(receiver.platform)
  return [x, y, z + height / 2 + pdThickness / 2]
}
