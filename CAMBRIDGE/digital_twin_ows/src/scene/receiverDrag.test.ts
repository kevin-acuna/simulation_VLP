import { describe, expect, it } from 'vitest'
import { Camera, OrthographicCamera, PerspectiveCamera, Ray, Raycaster, Vector2, Vector3 } from 'three'
import { toScenePosition } from '../model/config'
import { getReceiverBounds } from '../model/receiver'
import type { RoomConfig, WorldPosition } from '../model/types'
import { applyReceiverDragDelta, getAxisDragDelta, getCameraGroundBasis, getGroundDragDelta, getPlaneDragDelta, getReceiverPlaneAnchor, getWorldUnitsPerPixel, intersectReceiverPlane } from './receiverDrag'

const room: RoomConfig = { width: 3, depth: 4, height: 2 }

function makeCamera(perspective: boolean, position: WorldPosition, target: WorldPosition) {
  const camera = perspective ? new PerspectiveCamera(60, 1.5, 0.01, 100) : new OrthographicCamera(-3, 3, 2, -2, 0.01, 100)
  camera.position.set(...toScenePosition(position))
  camera.lookAt(new Vector3(...toScenePosition(target)))
  camera.updateProjectionMatrix()
  camera.updateMatrixWorld(true)
  return camera
}

function worldRay(origin: WorldPosition, direction: WorldPosition) {
  return new Ray(new Vector3(...toScenePosition(origin)), new Vector3(...toScenePosition(direction)).normalize())
}

function expectPosition(actual: WorldPosition, expected: WorldPosition) {
  actual.forEach((value, index) => expect(value).toBeCloseTo(expected[index], 10))
}

describe('receiver ray-plane dragging', () => {
  it('intersects a horizontal world-Z plane using the canonical scene axes', () => {
    expectPosition(intersectReceiverPlane(worldRay([0.4, -0.6, 3], [0, 0, -1]), 1)!, [0.4, -0.6, 1])
    expectPosition(intersectReceiverPlane(worldRay([0, 0, 3], [1, 2, -2]), 1)!, [1, 2, 1])
    expectPosition(intersectReceiverPlane(worldRay([0.4, -0.6, 0], [0, 0, 1]), 1)!, [0.4, -0.6, 1])
  })

  it('rejects parallel, near-parallel, coplanar, reversed, zero and nonfinite rays', () => {
    expect(intersectReceiverPlane(worldRay([0, 0, 1], [1, 0, 0]), 1)).toBeNull()
    expect(intersectReceiverPlane(worldRay([0, 0, 3], [1, 0, -0.001]), 1)).toBeNull()
    expect(intersectReceiverPlane(worldRay([0, 0, 3], [0, 0, 1]), 1)).toBeNull()
    expect(intersectReceiverPlane(new Ray(new Vector3(), new Vector3()), 1)).toBeNull()
    expect(intersectReceiverPlane(new Ray(new Vector3(NaN, 0, 0), new Vector3(0, 1, 0)), 1)).toBeNull()
    expect(intersectReceiverPlane(worldRay([0, 0, 3], [0, 0, -1]), Infinity)).toBeNull()
  })

  it('uses the stable fallback for an offset label when the body is viewed nearly edge-on', () => {
    const camera = makeCamera(true, [0, -5, 0.95], [0, 0, 1.1])
    const labelRay = worldRay([0, -5, 0.95], [0.4, 5, 0.8])
    expect(intersectReceiverPlane(labelRay, 1)).not.toBeNull()
    expect(getReceiverPlaneAnchor(camera, labelRay, [0, 0, 1])).toBeNull()
  })

  it.each([false, true])('retains the label ray offset with an elevated camera, perspective=%s', (perspective) => {
    const camera = makeCamera(perspective, [3, -4, 5], [0, 0, 1])
    const raycaster = new Raycaster()
    raycaster.setFromCamera(new Vector2(0.1, 0.1), camera)
    expect(getReceiverPlaneAnchor(camera, raycaster.ray, [0, 0, 1])).toEqual(intersectReceiverPlane(raycaster.ray, 1))
    expect(getReceiverPlaneAnchor(camera, raycaster.ray, [0, 0, 1])).not.toBeNull()
  })

  it('preserves the pointer-to-body offset and body-centre height without a jump', () => {
    const original: WorldPosition = [0.2, -0.3, 1]
    const anchor: WorldPosition = [0.8, -0.6, 1]
    expectPosition(applyReceiverDragDelta(original, getPlaneDragDelta(anchor, anchor), 'xy', room), original)
    const hit: WorldPosition = [1, -0.4, 1]
    expectPosition(applyReceiverDragDelta(original, getPlaneDragDelta(anchor, hit), 'xy', room), [0.4, -0.1, 1])
    expect(original).toEqual([0.2, -0.3, 1])
  })

  it.each([false, true])('maps a top-view ray drag correctly with perspective=%s', (perspective) => {
    const camera = makeCamera(perspective, [0, -0.001, 5], [0, 0, 1])
    const raycaster = new Raycaster()
    raycaster.setFromCamera(new Vector2(0, 0), camera)
    const anchor = intersectReceiverPlane(raycaster.ray, 1)!
    raycaster.setFromCamera(new Vector2(0.25, 0.25), camera)
    const hit = intersectReceiverPlane(raycaster.ray, 1)!
    expect(getPlaneDragDelta(anchor, hit)[0]).toBeGreaterThan(0)
    expect(getPlaneDragDelta(anchor, hit)[1]).toBeGreaterThan(0)
    expect(getPlaneDragDelta(anchor, hit)[2]).toBe(0)
  })
})

describe('receiver screen-to-world scale', () => {
  it('accounts for orthographic zoom independently of receiver depth', () => {
    const camera = makeCamera(false, [0, -5, 1], [0, 0, 1])
    camera.zoom = 2
    camera.updateProjectionMatrix()
    expect(getWorldUnitsPerPixel(camera, [0, 0, 1], 800)).toBeCloseTo(0.0025)
    expect(getWorldUnitsPerPixel(camera, [0, 2, 1], 800)).toBeCloseTo(0.0025)
  })

  it('uses perspective view depth, effective field of view and viewport pixels', () => {
    const camera = makeCamera(true, [0, -5, 1], [0, 0, 1])
    const expected = 10 * Math.tan(Math.PI / 6) / 800
    expect(getWorldUnitsPerPixel(camera, [0, 0, 1], 800)).toBeCloseTo(expected)
    expect(getWorldUnitsPerPixel(camera, [2, 0, 1], 800)).toBeCloseTo(expected)
    expect(getWorldUnitsPerPixel(camera, [0, 5, 1], 800)).toBeCloseTo(expected * 2)
    camera.zoom = 2
    camera.updateProjectionMatrix()
    expect(getWorldUnitsPerPixel(camera, [0, 0, 1], 800)).toBeCloseTo(expected / 2)
  })

  it('remains finite for near-plane positions and rejects unusable inputs', () => {
    const camera = makeCamera(true, [0, -5, 1], [0, 0, 1])
    expect(getWorldUnitsPerPixel(camera, [0, -5, 1], 800)).toBeGreaterThan(0)
    expect(getWorldUnitsPerPixel(camera, [0, 0, 1], 0)).toBe(0)
    expect(getWorldUnitsPerPixel(camera, [0, 0, 1], Infinity)).toBe(0)
    expect(getWorldUnitsPerPixel(camera, [NaN, 0, 1], 800)).toBe(0)
    expect(getWorldUnitsPerPixel(new Camera(), [0, 0, 1], 800)).toBe(0)
    camera.zoom = 0
    expect(Number.isFinite(getWorldUnitsPerPixel(camera, [0, 0, 1], 800))).toBe(true)
  })
})

describe('receiver world-axis handles and fallback', () => {
  it('maps right to +X and screen-up to +Y / +Z without mixing the scene axes', () => {
    const delta = { x: 20, y: -30 }
    expectPosition(getAxisDragDelta('x', delta, 0.01), [0.2, 0, 0])
    expectPosition(getAxisDragDelta('y', delta, 0.01), [0, 0.3, 0])
    expectPosition(getAxisDragDelta('z', delta, 0.01), [0, 0, 0.3])
    expectPosition(getAxisDragDelta('z', { x: 100, y: 0 }, 0.01), [0, 0, 0])
    expectPosition(getAxisDragDelta('z', { x: 0, y: 30 }, 0.01), [0, 0, -0.3])
    expect(getAxisDragDelta('x', delta, NaN)).toEqual([0, 0, 0])
  })

  it.each([false, true])('keeps Z draggable from the top view with perspective=%s', (perspective) => {
    const camera = makeCamera(perspective, [0, -0.001, 5], [0, 0, 1])
    const delta = getAxisDragDelta('z', { x: 0, y: -40 }, getWorldUnitsPerPixel(camera, [0, 0, 1], 800))
    const result = applyReceiverDragDelta([0.1, 0.2, 1], delta, 'z', room)
    expect(result[0]).toBe(0.1)
    expect(result[1]).toBe(0.2)
    expect(result[2]).toBeGreaterThan(1)
  })

  it.each([-0.05, 0, 0.05])('uses a stable forward ground basis near eye level at pitch %s', (height) => {
    const camera = makeCamera(true, [0, -5, 1], [0, 0, 1 + height])
    const basis = getCameraGroundBasis(camera)
    expectPosition(getGroundDragDelta({ x: 20, y: -30 }, 0.01, basis), [0.2, 0.3, 0])
  })

  it('orients the fallback to an orbiting camera rather than hard-coded Three axes', () => {
    const camera = makeCamera(false, [5, 0, 1], [0, 0, 1])
    const basis = getCameraGroundBasis(camera)
    expectPosition(getGroundDragDelta({ x: 20, y: -30 }, 0.01, basis), [-0.3, 0.2, 0])
    expect(Math.hypot(...basis.right)).toBeCloseTo(1)
    expect(Math.hypot(...basis.up)).toBeCloseTo(1)
    expect(basis.right[0] * basis.up[0] + basis.right[1] * basis.up[1]).toBeCloseTo(0)
  })

  it('provides a finite orthogonal basis even with a vertical screen-right vector', () => {
    const camera = new Camera()
    camera.rotation.z = Math.PI / 2
    camera.updateMatrixWorld(true)
    const basis = getCameraGroundBasis(camera)
    expect([...basis.right, ...basis.up].every(Number.isFinite)).toBe(true)
    expect(Math.hypot(...basis.right)).toBeCloseTo(1)
    expect(Math.hypot(...basis.up)).toBeCloseTo(1)
    expect(getGroundDragDelta({ x: Infinity, y: 0 }, 0.01, basis)).toEqual([0, 0, 0])
  })

  it('clamps translation to authoritative receiver bounds while preserving constrained coordinates', () => {
    const bounds = getReceiverBounds(room)
    const original: WorldPosition = [0.123456, -0.234567, 1.123456]
    const delta: WorldPosition = [100, -100, 100]
    expect(applyReceiverDragDelta(original, delta, 'x', room)).toEqual([bounds.x[1], original[1], original[2]])
    expect(applyReceiverDragDelta(original, delta, 'y', room)).toEqual([original[0], bounds.y[0], original[2]])
    expect(applyReceiverDragDelta(original, delta, 'z', room)).toEqual([original[0], original[1], bounds.z[1]])
    expect(applyReceiverDragDelta(original, delta, 'xy', room)).toEqual([bounds.x[1], bounds.y[0], original[2]])
    expect(applyReceiverDragDelta(original, [0, 0, -100], 'z', room)).toEqual([original[0], original[1], bounds.z[0]])
    expect(applyReceiverDragDelta(original, [NaN, Infinity, 0], 'xy', room)).toEqual(original)
    expect(original).toEqual([0.123456, -0.234567, 1.123456])
  })

  it.each([0, 30, 45, 90])('clamps the live drone preview to the full rotor envelope at yaw %s', (yaw) => {
    const angle = yaw * Math.PI / 180
    const margin = 0.08 * (Math.abs(Math.cos(angle)) + Math.abs(Math.sin(angle))) + 0.06 + 0.01
    const moved = applyReceiverDragDelta([0, 0, 0.3], [100, -100, 0], 'xy', room, 'drone', yaw)
    expectPosition(moved, [room.width / 2 - margin, -room.depth / 2 + margin, 0.3])
    expect(moved[0]).toBeLessThan(getReceiverBounds(room).x[1])
  })

  it('uses the shorter drone body when dragging its altitude', () => {
    expectPosition(applyReceiverDragDelta([0, 0, 0.3], [0, 0, -100], 'z', room, 'drone'), [0, 0, 0.04])
    expectPosition(applyReceiverDragDelta([0, 0, 0.3], [0, 0, 100], 'z', room, 'drone'), [0, 0, room.height - 0.042])
  })
})
