import { describe, expect, it } from 'vitest'
import { PerspectiveCamera, Vector3 } from 'three'
import { createDefaultConfig, getFixtures, normalizeConfig, toScenePosition as modelToScenePosition } from '../model/config'
import type { LedLayout, RoomConfig } from '../model/types'
import { constrainPerspectiveCameraPose, getCameraZoom, getFloorGridPositions, getPerspectiveCameraBounds, getPerspectiveCameraPose, getPerspectiveViewportSize, getRoomBounds, getRoomCorners, toScenePosition } from './coordinates'
import type { ScenePosition } from './coordinates'

const rooms: RoomConfig[] = [
  { width: 3, depth: 3, height: 2 },
  { width: 2, depth: 10, height: 5 },
  { width: 7.3, depth: 2.6, height: 2.4 },
]

function expectInsideRoom(position: [number, number, number], room: RoomConfig) {
  const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
  expect(position[0]).toBeGreaterThanOrEqual(minX)
  expect(position[0]).toBeLessThanOrEqual(maxX)
  expect(position[1]).toBe(room.height)
  expect(position[2]).toBeGreaterThanOrEqual(minZ)
  expect(position[2]).toBeLessThanOrEqual(maxZ)
}

describe('centered scene coordinates', () => {
  it('re-exports the model conversion rather than defining another transform', () => {
    expect(toScenePosition).toBe(modelToScenePosition)
    expect(toScenePosition([-0.75, -0.75, 2])).toEqual([-0.75, 2, 0.75])
    expect(toScenePosition([0.75, 0.75, 2])).toEqual([0.75, 2, -0.75])
  })

  it('contains all four default LEDs in a room centered on the floor origin', () => {
    const config = createDefaultConfig()
    expect(getRoomBounds(config.room)).toEqual({ minX: -1.5, maxX: 1.5, minZ: -1.5, maxZ: 1.5 })
    const fixtures = getFixtures(config)
    expect(fixtures.map((fixture) => fixture.position)).toEqual([
      [-0.75, -0.75, 2],
      [0.75, -0.75, 2],
      [-0.75, 0.75, 2],
      [0.75, 0.75, 2],
    ])
    fixtures.forEach((fixture) => expectInsideRoom(toScenePosition(fixture.position), config.room))
  })

  it.each<LedLayout>(['grid', 'ring', 'line'])('contains every fixture for all supported counts in the %s layout', (layout) => {
    for (const room of rooms) {
      for (let count = 1; count <= 9; count += 1) {
        const config = createDefaultConfig()
        config.room = room
        config.lighting = { ...config.lighting, layout, count, spacing: 0.8 }
        getFixtures(config).forEach((fixture) => expectInsideRoom(toScenePosition(fixture.position), room))
      }
    }
  })

  it('keeps manually clamped world positions within the same centered room bounds', () => {
    const config = normalizeConfig({ room: rooms[1], positions: { 'LED-01': [-100, 100], 'LED-02': [100, -100] } })
    getFixtures(config).forEach((fixture) => expectInsideRoom(toScenePosition(fixture.position), config.room))
  })
})

describe('room and camera-fitting bounds', () => {
  it.each(rooms)('centers the eight room corners for $width × $depth × $height', (room) => {
    const corners = getRoomCorners(room)
    expect(corners).toHaveLength(8)
    expect(new Set(corners.map((corner) => corner.join(','))).size).toBe(8)
    const center = corners.reduce<number[]>((sum, point) => sum.map((value, axis) => value + point[axis] / 8), [0, 0, 0])
    expect(center[0]).toBeCloseTo(0, 12)
    expect(center[1]).toBeCloseTo(room.height / 2, 12)
    expect(center[2]).toBeCloseTo(0, 12)
    for (const corner of corners) {
      expect(Math.abs(corner[0])).toBe(room.width / 2)
      expect(Math.abs(corner[2])).toBe(room.depth / 2)
      expect(corner[1] === 0 || corner[1] === room.height).toBe(true)
    }
  })

  it('pads camera-fitting bounds symmetrically around the centered footprint', () => {
    const room = rooms[2]
    const corners = getRoomCorners(room, 0.53, 0.18, 0.28)
    expect(Math.min(...corners.map(([x]) => x))).toBeCloseTo(-room.width / 2 - 0.53)
    expect(Math.max(...corners.map(([x]) => x))).toBeCloseTo(room.width / 2 + 0.53)
    expect(Math.min(...corners.map(([, , z]) => z))).toBeCloseTo(-room.depth / 2 - 0.53)
    expect(Math.max(...corners.map(([, , z]) => z))).toBeCloseTo(room.depth / 2 + 0.53)
    expect(Math.min(...corners.map(([, y]) => y))).toBe(-0.18)
    expect(Math.max(...corners.map(([, y]) => y))).toBe(room.height + 0.28)
  })
})

describe('camera framing', () => {
  it('enlarges the initial landscape view while keeping a distinct full-room fit', () => {
    const fit = getCameraZoom(1280, 720, 4, 4, 'fit')
    const immersive = getCameraZoom(1280, 720, 4, 4, 'immersive')
    expect(fit).toBeCloseTo(84.6)
    expect(immersive).toBeCloseTo(fit * 1.6)
    expect(immersive * 8).toBeGreaterThan(720)
    expect(immersive * 8).toBeLessThan(1280)
  })

  it('caps the close-up at the available width on portrait screens', () => {
    const fit = getCameraZoom(390, 844, 4, 3, 'fit')
    const immersive = getCameraZoom(390, 844, 4, 3, 'immersive')
    expect(immersive).toBeCloseTo(fit)
    expect(immersive * 8).toBeCloseTo(390 * 0.94)
  })

  it('keeps the full padded bounds visible in fit mode across viewports', () => {
    for (const [width, height] of [[1440, 1000], [1024, 526], [390, 844], [844, 390]]) {
      for (const [halfWidth, halfHeight] of [[2, 3], [7, 2], [3, 5]]) {
        const fit = getCameraZoom(width, height, halfWidth, halfHeight, 'fit')
        const immersive = getCameraZoom(width, height, halfWidth, halfHeight, 'immersive')
        expect(fit * halfWidth * 2).toBeLessThanOrEqual(width)
        expect(fit * halfHeight * 2).toBeLessThanOrEqual(height)
        expect(immersive).toBeGreaterThanOrEqual(fit)
        expect(immersive * halfWidth * 2).toBeLessThanOrEqual(width)
      }
    }
  })

  it('returns a finite zoom for degenerate bounds', () => {
    expect(Number.isFinite(getCameraZoom(1280, 720, 0, 0, 'immersive'))).toBe(true)
  })
})

const perspectiveRooms: RoomConfig[] = [
  ...rooms,
  { width: 2, depth: 2, height: 1.8 },
  { width: 2, depth: 2, height: 5 },
  { width: 10, depth: 2, height: 1.8 },
  { width: 10, depth: 2, height: 5 },
  { width: 10, depth: 10, height: 1.8 },
  { width: 10, depth: 10, height: 5 },
  { width: 2, depth: 10, height: 1.8 },
]
const perspectiveCases = perspectiveRooms.flatMap((room) =>
  [[1440, 1000], [1024, 526], [390, 844]].map(([width, height]) => ({
    room, aspect: width / height, name: `${room.width}x${room.depth}x${room.height} at ${width}x${height}`,
  })),
)

function makePerspectiveCamera(room: RoomConfig, aspect: number, framing: 'fit' | 'immersive') {
  const pose = getPerspectiveCameraPose(room, aspect, framing)
  const camera = new PerspectiveCamera(pose.fov, aspect, pose.near, pose.far)
  camera.position.set(...pose.position)
  camera.lookAt(new Vector3(...pose.target))
  camera.updateMatrixWorld(true)
  return camera
}

function expectInFrustum(point: ScenePosition, camera: PerspectiveCamera) {
  const projected = new Vector3(...point).project(camera)
  expect(Math.abs(projected.x)).toBeLessThanOrEqual(0.941)
  expect(Math.abs(projected.y)).toBeLessThanOrEqual(0.941)
  expect(projected.z).toBeGreaterThan(-1)
  expect(projected.z).toBeLessThan(1)
}

describe('perspective projection and framing', () => {
  it('makes the visible size grow with depth, unlike orthographic zoom', () => {
    const near = getPerspectiveViewportSize(2, 1.5, 60)
    const far = getPerspectiveViewportSize(4, 1.5, 60)
    expect(near.height).toBeCloseTo(4 * Math.tan(Math.PI / 6))
    expect(near.width).toBeCloseTo(near.height * 1.5)
    expect(far.width).toBeCloseTo(near.width * 2)
    expect(far.height).toBeCloseTo(near.height * 2)
    const camera = new PerspectiveCamera(60, 1.5, 0.01, 100)
    const front = new Vector3(0.5, 0, -2).project(camera)
    const rear = new Vector3(0.5, 0, -4).project(camera)
    expect(front.x).toBeCloseTo(rear.x * 2)
    expect(getCameraZoom(1440, 1000, 4, 4, 'immersive')).toBeCloseTo(169.2)
  })

  it.each(perspectiveCases)('starts at an eye-level front threshold for $name', ({ room, aspect }) => {
    const pose = getPerspectiveCameraPose(room, aspect, 'immersive')
    const bounds = getPerspectiveCameraBounds(room, aspect)
    expect(pose.fov).toBeGreaterThanOrEqual(60)
    expect(pose.fov).toBeLessThanOrEqual(70)
    expect(pose.position[0]).toBe(0)
    expect(pose.position[1] / room.height).toBeGreaterThanOrEqual(0.45)
    expect(pose.position[1] / room.height).toBeLessThanOrEqual(0.5)
    expect(pose.position[2]).toBeGreaterThan(room.depth / 2)
    expect(pose.target[1] / room.height).toBeGreaterThanOrEqual(0.55)
    expect(pose.target[1] / room.height).toBeLessThanOrEqual(0.6)
    expect(pose.target[2]).toBe(-room.depth / 2)
    const offset = new Vector3(...pose.position).sub(new Vector3(...pose.target))
    const polar = Math.acos(offset.y / offset.length())
    expect(polar).toBeGreaterThanOrEqual(bounds.minPolarAngle)
    expect(polar).toBeLessThanOrEqual(bounds.maxPolarAngle)
    expect(offset.length()).toBeGreaterThan(bounds.minDistance)
    expect(offset.length()).toBeLessThan(bounds.maxDistance)
    expect(pose.near).toBeGreaterThan(0)
    expect(pose.far).toBeGreaterThan(bounds.maxDistance)
    expect(constrainPerspectiveCameraPose(room, pose.position, pose.target)).toEqual({ position: pose.position, target: pose.target })
    const camera = makePerspectiveCamera(room, aspect, 'immersive')
    const frontEdge = new Vector3(room.width / 2, pose.position[1], room.depth / 2).project(camera)
    const ceilingEdge = new Vector3(0, room.height, room.depth / 2).project(camera)
    expect(Math.max(Math.abs(frontEdge.x), Math.abs(ceilingEdge.y))).toBeGreaterThan(0.9)
  })

  it.each(perspectiveCases)('keeps all four default fixture housings visible with an opaque ceiling for $name', ({ room, aspect }) => {
    const config = createDefaultConfig()
    config.room = room
    const camera = makePerspectiveCamera(room, aspect, 'immersive')
    for (const fixture of getFixtures(config)) {
      const [x, y, z] = toScenePosition(fixture.position)
      for (const dx of [-0.11, 0.11]) {
        for (const dz of [-0.11, 0.11]) {
          for (const dy of [-0.071, 0]) {
            const point: ScenePosition = [x + dx, y + dy, z + dz]
            expectInFrustum(point, camera)
            const entrance = camera.position.clone().lerp(new Vector3(...point),
              (camera.position.z - room.depth / 2) / (camera.position.z - point[2]))
            expect(entrance.y).toBeGreaterThan(0)
            expect(entrance.y).toBeLessThan(room.height)
            expect(Math.abs(entrance.x)).toBeLessThan(room.width / 2)
          }
        }
      }
    }
  })

  it.each(perspectiveCases)('pulls back to fit all eight room corners for $name', ({ room, aspect }) => {
    const entry = getPerspectiveCameraPose(room, aspect, 'immersive')
    const fit = getPerspectiveCameraPose(room, aspect, 'fit')
    const camera = makePerspectiveCamera(room, aspect, 'fit')
    expect(fit.position[2]).toBeGreaterThan(entry.position[2])
    expect(fit.position[1]).toBe(entry.position[1])
    expect(fit.target).toEqual(entry.target)
    getRoomCorners(room).forEach((point) => expectInFrustum(point, camera))
    const firstFit = camera.projectionMatrix.clone()
    camera.position.set(100, 100, 100)
    camera.zoom = 4
    expect(makePerspectiveCamera(room, aspect, 'fit').projectionMatrix).toEqual(firstFit)
  })

  it.each(perspectiveRooms)('constrains panning and orbit height without changing horizontal position in $width x $depth x $height', (room) => {
    const bounds = getPerspectiveCameraBounds(room, 1)
    const position: ScenePosition = [2, -100, 4]
    const target: ScenePosition = [-1, 100, -2]
    const pose = constrainPerspectiveCameraPose(room, position, target)
    expect(position).toEqual([2, -100, 4])
    expect(target).toEqual([-1, 100, -2])
    expect(pose.position[0]).toBe(position[0])
    expect(pose.position[2]).toBe(position[2])
    expect(pose.target[0]).toBe(target[0])
    expect(pose.target[2]).toBe(target[2])
    for (const point of [pose.position, pose.target]) {
      expect(point[1]).toBeGreaterThanOrEqual(bounds.minHeight)
      expect(point[1]).toBeLessThanOrEqual(bounds.maxHeight)
    }
    const high = constrainPerspectiveCameraPose(room, [0, 100, 0.01], [0, -100, 0])
    expect(high.position[1]).toBeLessThanOrEqual(bounds.maxHeight)
    expect(high.target[1]).toBeGreaterThanOrEqual(bounds.minHeight)
    for (const constrained of [pose, high]) {
      const offset = new Vector3(...constrained.position).sub(new Vector3(...constrained.target))
      const polar = Math.acos(offset.y / offset.length())
      expect(polar).toBeGreaterThanOrEqual(bounds.minPolarAngle - 1e-9)
      expect(polar).toBeLessThanOrEqual(bounds.maxPolarAngle + 1e-9)
    }
    expect(constrainPerspectiveCameraPose(room, pose.position, pose.target)).toEqual(pose)
  })
})

describe('centered floor grid', () => {
  it.each(rooms)('stays within the floor and includes the world-origin crossing for $width × $depth', (room) => {
    const grid = getFloorGridPositions(room)
    const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
    let centerX = false
    let centerZ = false
    expect(grid.length % 6).toBe(0)
    expect(grid.length).toBeGreaterThan(0)
    for (let index = 0; index < grid.length; index += 3) {
      expect(grid[index]).toBeGreaterThanOrEqual(minX - 0.000001)
      expect(grid[index]).toBeLessThanOrEqual(maxX + 0.000001)
      expect(grid[index + 1]).toBeCloseTo(0.007)
      expect(grid[index + 2]).toBeGreaterThanOrEqual(minZ - 0.000001)
      expect(grid[index + 2]).toBeLessThanOrEqual(maxZ + 0.000001)
    }
    for (let index = 0; index < grid.length; index += 6) {
      if (grid[index] === 0 && grid[index + 3] === 0) {
        centerX = true
        expect(grid[index + 2]).toBeCloseTo(minZ)
        expect(grid[index + 5]).toBeCloseTo(maxZ)
      }
      if (grid[index + 2] === 0 && grid[index + 5] === 0) {
        centerZ = true
        expect(grid[index]).toBeCloseTo(minX)
        expect(grid[index + 3]).toBeCloseTo(maxX)
      }
    }
    expect(centerX).toBe(true)
    expect(centerZ).toBe(true)
  })
})
