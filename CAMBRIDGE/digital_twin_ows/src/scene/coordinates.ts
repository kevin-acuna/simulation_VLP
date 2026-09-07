import type { CameraFraming, RoomConfig } from '../model/types'

export { toScenePosition } from '../model/config'

export type ScenePosition = [number, number, number]

export function getCameraZoom(width: number, height: number, halfWidth: number, halfHeight: number, framing: CameraFraming): number {
  const widthZoom = width / Math.max(0.1, halfWidth * 2) * 0.94
  const heightZoom = height / Math.max(0.1, halfHeight * 2) * 0.94
  const fitZoom = Math.min(widthZoom, heightZoom)
  return framing === 'immersive' ? Math.min(fitZoom * 1.6, widthZoom) : fitZoom
}

export function getPerspectiveViewportSize(distance: number, aspect: number, fov = 66) {
  const height = 2 * Math.max(0, distance) * Math.tan(fov * Math.PI / 360)
  return { width: height * Math.max(0.1, aspect), height }
}

export function getPerspectiveCameraBounds(room: RoomConfig, aspect = 1) {
  return {
    minHeight: room.height * 0.2,
    maxHeight: room.height * 0.8,
    minPolarAngle: Math.PI / 2 - 0.14,
    maxPolarAngle: Math.PI / 2 + 0.24,
    minDistance: Math.max(0.15, Math.min(room.width, room.depth) * 0.1),
    maxDistance: Math.max(room.width, room.depth, room.height) * 8 + room.width / Math.max(0.1, aspect) * 4,
  }
}

export function constrainPerspectiveCameraPose(room: RoomConfig, position: ScenePosition, target: ScenePosition): { position: ScenePosition; target: ScenePosition } {
  const bounds = getPerspectiveCameraBounds(room)
  const targetHeight = Math.max(bounds.minHeight, Math.min(bounds.maxHeight, target[1]))
  const horizontalDistance = Math.hypot(position[0] - target[0], position[2] - target[2])
  const minHeight = Math.max(bounds.minHeight, targetHeight - horizontalDistance * Math.tan(bounds.maxPolarAngle - Math.PI / 2))
  const maxHeight = Math.min(bounds.maxHeight, targetHeight + horizontalDistance * Math.tan(Math.PI / 2 - bounds.minPolarAngle))
  return {
    position: [position[0], Math.max(minHeight, Math.min(maxHeight, position[1])), position[2]],
    target: [target[0], targetHeight, target[2]],
  }
}

export function getPerspectiveCameraPose(room: RoomConfig, aspect: number, framing: CameraFraming) {
  const fov = 66
  const near = 0.01
  const bounds = getPerspectiveCameraBounds(room, aspect)
  const position: ScenePosition = [0, room.height * 0.47, room.depth / 2]
  const target: ScenePosition = [0, room.height * 0.57, -room.depth / 2]
  const unitViewport = getPerspectiveViewportSize(1, aspect, fov)
  const halfWidth = unitViewport.width * 0.46
  const halfHeight = unitViewport.height * 0.46
  const corners = getRoomCorners(room, 0.04, 0.02, 0.04)
  const points = framing === 'fit' ? corners : corners.filter((point) => point[2] < 0)
  if (framing === 'immersive') {
    for (const x of [-room.width / 4 - 0.14, room.width / 4 + 0.14]) {
      for (const z of [-room.depth / 4 - 0.14, room.depth / 4 + 0.14]) {
        points.push([x, room.height, z])
      }
    }
  }
  const containsPoints = (standoff: number) => {
    const z = room.depth / 2 + standoff
    const run = z - target[2]
    const rise = target[1] - position[1]
    const distance = Math.hypot(run, rise)
    const cosine = run / distance
    const sine = rise / distance
    return points.every(([x, y, pointZ]) => {
      const depth = (z - pointZ) * cosine + (y - position[1]) * sine
      const vertical = (y - position[1]) * cosine - (z - pointZ) * sine
      return depth > near && Math.abs(x) <= depth * halfWidth && Math.abs(vertical) <= depth * halfHeight
    })
  }
  let minimum = Math.max(0.12, Math.min(0.35, room.depth * 0.05))
  let maximum = bounds.maxDistance / 2
  if (!containsPoints(minimum)) {
    for (let step = 0; step < 48; step += 1) {
      const midpoint = (minimum + maximum) / 2
      if (containsPoints(midpoint)) maximum = midpoint
      else minimum = midpoint
    }
    minimum = maximum
  }
  position[2] += minimum
  return { position, target, fov, near, far: bounds.maxDistance + Math.hypot(room.width, room.depth, room.height) * 3 }
}

export function getRoomBounds(room: RoomConfig) {
  return {
    minX: -room.width / 2,
    maxX: room.width / 2,
    minZ: -room.depth / 2,
    maxZ: room.depth / 2,
  }
}

export function getRoomCorners(room: RoomConfig, horizontalPadding = 0, bottomPadding = 0, topPadding = 0): ScenePosition[] {
  const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
  const corners: ScenePosition[] = []
  for (const x of [minX - horizontalPadding, maxX + horizontalPadding]) {
    for (const y of [-bottomPadding, room.height + topPadding]) {
      for (const z of [minZ - horizontalPadding, maxZ + horizontalPadding]) {
        corners.push([x, y, z])
      }
    }
  }
  return corners
}

export function getFloorGridPositions(room: RoomConfig): Float32Array {
  const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
  const vertices: number[] = []
  const step = Math.max(room.width, room.depth) > 6 ? 0.5 : 0.25
  for (let x = Math.ceil(minX / step) * step; x < maxX - 0.001; x += step) {
    if (x > minX + 0.001) vertices.push(x, 0.007, minZ, x, 0.007, maxZ)
  }
  for (let z = Math.ceil(minZ / step) * step; z < maxZ - 0.001; z += step) {
    if (z > minZ + 0.001) vertices.push(minX, 0.007, z, maxX, 0.007, z)
  }
  return new Float32Array(vertices)
}

export function temperatureColor(temperature: number): string {
  const value = Math.max(1800, Math.min(10000, temperature)) / 100
  const red = value <= 66 ? 255 : 329.698727446 * Math.pow(value - 60, -0.1332047592)
  const green = value <= 66
    ? 99.4708025861 * Math.log(value) - 161.1195681661
    : 288.1221695283 * Math.pow(value - 60, -0.0755148492)
  const blue = value >= 66 ? 255 : value <= 19 ? 0 : 138.5177312231 * Math.log(value - 10) - 305.0447927307
  const channel = (component: number) => Math.round(Math.max(0, Math.min(255, component)))
  return `rgb(${channel(red)}, ${channel(green)}, ${channel(blue)})`
}
