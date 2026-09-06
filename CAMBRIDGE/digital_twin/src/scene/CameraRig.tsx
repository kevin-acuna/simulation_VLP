import { useLayoutEffect, useMemo, useRef } from 'react'
import { OrbitControls } from '@react-three/drei'
import { useFrame, useThree } from '@react-three/fiber'
import { OrthographicCamera, PerspectiveCamera, Vector3 } from 'three'
import type { CameraFraming, CameraView, RoomConfig } from '../model/types'
import type { ComponentRef } from 'react'
import { constrainPerspectiveCameraPose, getCameraZoom, getPerspectiveCameraBounds, getPerspectiveCameraPose, getRoomCorners } from './coordinates'

interface CameraRigProps {
  room: RoomConfig
  view: CameraView
  cameraReset: number
  dimensions: boolean
  framing: CameraFraming
}

interface CameraSnapshot {
  view: CameraView
  reset: number
  framing: CameraFraming
  width: number
  depth: number
  height: number
  viewportWidth: number
  viewportHeight: number
}

export default function CameraRig({ room, view, cameraReset, dimensions, framing }: CameraRigProps) {
  const controls = useRef<ComponentRef<typeof OrbitControls>>(null)
  const previous = useRef<CameraSnapshot | null>(null)
  const interacted = useRef(false)
  const cameras = useMemo(() => ({
    orthographic: Object.assign(new OrthographicCamera(), { manual: true }),
    perspective: Object.assign(new PerspectiveCamera(), { manual: true }),
  }), [])
  const camera = view === 'perspective' ? cameras.perspective : cameras.orthographic
  const size = useThree((state) => state.size)
  const get = useThree((state) => state.get)
  const set = useThree((state) => state.set)
  const invalidate = useThree((state) => state.invalidate)
  const aspect = size.width / Math.max(1, size.height)
  const bounds = getPerspectiveCameraBounds(room, aspect)

  useLayoutEffect(() => {
    if (!controls.current || size.width <= 0 || size.height <= 0) return
    const orbit = controls.current
    const last = previous.current
    const reset = !last || last.view !== view || last.reset !== cameraReset || last.framing !== framing
    const resized = !last || last.width !== room.width || last.depth !== room.depth || last.height !== room.height
      || last.viewportWidth !== size.width || last.viewportHeight !== size.height
    const snapshot: CameraSnapshot = {
      view, reset: cameraReset, framing, width: room.width, depth: room.depth, height: room.height,
      viewportWidth: size.width, viewportHeight: size.height,
    }

    if (camera instanceof PerspectiveCamera) {
      if (!reset && !resized) return
      const pose = getPerspectiveCameraPose(room, aspect, framing)
      const limits = getPerspectiveCameraBounds(room, aspect)
      const reframe = reset || !interacted.current
      const damping = orbit.enableDamping
      if (reframe) {
        orbit.enableDamping = false
        orbit.update()
        camera.position.set(...pose.position)
        orbit.target.set(...pose.target)
        camera.zoom = 1
        interacted.current = false
      }
      const constrained = constrainPerspectiveCameraPose(room, camera.position.toArray(), orbit.target.toArray())
      camera.position.set(...constrained.position)
      orbit.target.set(...constrained.target)
      camera.up.set(0, 1, 0)
      camera.fov = pose.fov
      camera.aspect = aspect
      camera.near = pose.near
      camera.far = pose.far
      camera.lookAt(orbit.target)
      camera.updateProjectionMatrix()
      orbit.minDistance = limits.minDistance
      orbit.maxDistance = limits.maxDistance
      orbit.update()
      orbit.enableDamping = damping
      camera.updateMatrixWorld(true)
      orbit.saveState()
      previous.current = snapshot
      invalidate()
      return
    }

    const damping = orbit.enableDamping
    orbit.enableDamping = false
    orbit.update()
    const direction = reset
      ? new Vector3(...(view === 'top' ? [0, 1, 0.0001] as const : view === 'front' ? [0, 0.005, 1] as const : [1, 0.92, 1.12] as const)).normalize()
      : camera.position.clone().sub(orbit.target).normalize()
    const target = new Vector3(0, room.height / 2, 0)
    const distance = Math.max(room.width, room.depth, room.height) * 5 + 8
    camera.position.copy(target).addScaledVector(direction, distance)
    camera.up.set(0, 1, 0)
    camera.near = 0.01
    camera.far = distance + Math.max(room.width, room.depth, room.height) * 5 + 20
    camera.lookAt(target)
    camera.updateMatrixWorld(true)

    const padding = dimensions ? 0.53 : 0.22
    let halfWidth = 0
    let halfHeight = 0
    for (const corner of getRoomCorners(room, padding, 0.18, 0.28)) {
      const point = new Vector3(...corner).applyMatrix4(camera.matrixWorldInverse)
      halfWidth = Math.max(halfWidth, Math.abs(point.x))
      halfHeight = Math.max(halfHeight, Math.abs(point.y))
    }

    const fitZoom = getCameraZoom(size.width, size.height, halfWidth, halfHeight, 'fit')
    camera.left = -size.width / 2
    camera.right = size.width / 2
    camera.top = size.height / 2
    camera.bottom = -size.height / 2
    camera.zoom = getCameraZoom(size.width, size.height, halfWidth, halfHeight, framing)
    camera.updateProjectionMatrix()
    orbit.target.copy(target)
    orbit.minZoom = fitZoom * 0.32
    orbit.maxZoom = fitZoom * 5
    orbit.update()
    orbit.enableDamping = damping
    orbit.saveState()
    previous.current = snapshot
    invalidate()
  }, [camera, room.width, room.depth, room.height, view, cameraReset, dimensions, framing, size.width, size.height, aspect, invalidate])

  useLayoutEffect(() => {
    const original = get().camera
    set({ camera })
    return () => {
      if (get().camera === camera) set({ camera: original })
    }
  }, [camera, get, set])

  useFrame(() => {
    if (!(camera instanceof PerspectiveCamera) || !controls.current) return
    const orbit = controls.current
    const pose = constrainPerspectiveCameraPose(room, camera.position.toArray(), orbit.target.toArray())
    if (camera.position.y === pose.position[1] && orbit.target.y === pose.target[1]) return
    camera.position.set(...pose.position)
    orbit.target.set(...pose.target)
    camera.lookAt(orbit.target)
    camera.updateMatrixWorld(true)
  }, -0.5)

  return (
    <OrbitControls
      ref={controls}
      camera={camera}
      makeDefault
      enableDamping
      dampingFactor={0.085}
      rotateSpeed={view === 'perspective' ? 0.4 : 0.65}
      zoomSpeed={0.85}
      panSpeed={0.7}
      screenSpacePanning
      minDistance={view === 'perspective' ? bounds.minDistance : 0}
      maxDistance={view === 'perspective' ? bounds.maxDistance : Infinity}
      minPolarAngle={view === 'perspective' ? bounds.minPolarAngle : 0}
      maxPolarAngle={view === 'perspective' ? bounds.maxPolarAngle : Math.PI / 2 - 0.004}
      onStart={() => { interacted.current = true }}
    />
  )
}
