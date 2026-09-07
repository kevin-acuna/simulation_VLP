import { Camera, OrthographicCamera, PerspectiveCamera, Ray, Vector3 } from 'three'
import { toScenePosition } from '../model/config'
import { clampReceiverPosition } from '../model/receiver'
import type { ReceiverPlatform, RoomConfig, WorldPosition } from '../model/types'

export type ReceiverDragAxis = 'xy' | 'x' | 'y' | 'z'
export interface ScreenPoint { x: number; y: number }
export interface GroundBasis { right: [number, number]; up: [number, number] }

const worldX = new Vector3(...toScenePosition([1, 0, 0]))
const worldY = new Vector3(...toScenePosition([0, 1, 0]))
const worldZ = new Vector3(...toScenePosition([0, 0, 1]))

export function intersectReceiverPlane(ray: Ray, height: number, minSlope = 0.08): WorldPosition | null {
  const length = ray.direction.length()
  const slope = ray.direction.dot(worldZ)
  if (!Number.isFinite(height) || !Number.isFinite(length) || length < 1e-12
    || Math.abs(slope) / length < Math.max(1e-8, minSlope)) return null
  const distance = (height - ray.origin.dot(worldZ)) / slope
  if (!Number.isFinite(distance) || distance < 0) return null
  const hit = ray.at(distance, new Vector3())
  const position: WorldPosition = [hit.dot(worldX), hit.dot(worldY), height]
  return position.every(Number.isFinite) ? position : null
}

export function getReceiverPlaneAnchor(camera: Camera, ray: Ray, position: WorldPosition): WorldPosition | null {
  const origin = new Vector3().setFromMatrixPosition(camera.matrixWorld)
  const direction = camera instanceof OrthographicCamera
    ? new Vector3().setFromMatrixColumn(camera.matrixWorld, 2).negate()
    : new Vector3(...toScenePosition(position)).sub(origin).normalize()
  if (!intersectReceiverPlane(new Ray(origin, direction), position[2])) return null
  return intersectReceiverPlane(ray, position[2])
}

export function getWorldUnitsPerPixel(camera: Camera, position: WorldPosition, viewportHeight: number): number {
  if (!Number.isFinite(viewportHeight) || viewportHeight <= 0 || !position.every(Number.isFinite)) return 0
  let height = 0
  if (camera instanceof OrthographicCamera) {
    height = Math.abs(camera.top - camera.bottom) / camera.zoom
  } else if (camera instanceof PerspectiveCamera) {
    const point = new Vector3(...toScenePosition(position)).applyMatrix4(camera.matrixWorldInverse)
    const depth = Math.max(camera.near, -point.z)
    height = 2 * depth * Math.tan(camera.getEffectiveFOV() * Math.PI / 360)
  }
  return Number.isFinite(height) && height > 0 ? height / viewportHeight : 0
}

export function getCameraGroundBasis(camera: Camera): GroundBasis {
  const cameraRight = new Vector3().setFromMatrixColumn(camera.matrixWorld, 0)
  const cameraUp = new Vector3().setFromMatrixColumn(camera.matrixWorld, 1)
  const cameraForward = new Vector3().setFromMatrixColumn(camera.matrixWorld, 2).negate()
  let right: [number, number] = [cameraRight.dot(worldX), cameraRight.dot(worldY)]
  let length = Math.hypot(...right)
  if (!Number.isFinite(length) || length < 1e-8) {
    right = [cameraUp.dot(worldY), -cameraUp.dot(worldX)]
    length = Math.hypot(...right)
  }
  right = Number.isFinite(length) && length >= 1e-8 ? [right[0] / length, right[1] / length] : [1, 0]
  const up: [number, number] = [-right[1], right[0]]
  const projectedUp: [number, number] = [cameraUp.dot(worldX), cameraUp.dot(worldY)]
  const reference = Math.hypot(...projectedUp) > 0.2
    ? projectedUp : [cameraForward.dot(worldX), cameraForward.dot(worldY)]
  if (up[0] * reference[0] + up[1] * reference[1] < 0) {
    up[0] *= -1
    up[1] *= -1
  }
  return { right, up }
}

export function getAxisDragDelta(axis: Exclude<ReceiverDragAxis, 'xy'>, delta: ScreenPoint, unitsPerPixel: number): WorldPosition {
  if (![delta.x, delta.y, unitsPerPixel].every(Number.isFinite) || unitsPerPixel <= 0) return [0, 0, 0]
  if (axis === 'x') return [delta.x * unitsPerPixel, 0, 0]
  if (axis === 'y') return [0, -delta.y * unitsPerPixel, 0]
  return [0, 0, -delta.y * unitsPerPixel]
}

export function getGroundDragDelta(delta: ScreenPoint, unitsPerPixel: number, basis: GroundBasis): WorldPosition {
  if (![delta.x, delta.y, unitsPerPixel, ...basis.right, ...basis.up].every(Number.isFinite) || unitsPerPixel <= 0) return [0, 0, 0]
  return [
    (delta.x * basis.right[0] - delta.y * basis.up[0]) * unitsPerPixel,
    (delta.x * basis.right[1] - delta.y * basis.up[1]) * unitsPerPixel,
    0,
  ]
}

export function getPlaneDragDelta(anchor: WorldPosition, hit: WorldPosition): WorldPosition {
  return [hit[0] - anchor[0], hit[1] - anchor[1], 0]
}

export function applyReceiverDragDelta(position: WorldPosition, delta: WorldPosition, axis: ReceiverDragAxis, room: RoomConfig, platform: ReceiverPlatform = 'cylinder', yaw = 0): WorldPosition {
  const next: WorldPosition = [...position]
  const indices = axis === 'xy' ? [0, 1] : [axis === 'x' ? 0 : axis === 'y' ? 1 : 2]
  for (const index of indices) {
    if (Number.isFinite(delta[index])) next[index] += delta[index]
  }
  const clamped = clampReceiverPosition(next, room, platform, yaw)
  for (const index of indices) next[index] = clamped[index]
  return next
}
