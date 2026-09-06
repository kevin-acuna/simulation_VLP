import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import { Raycaster, Vector2 } from 'three'
import type { PointerEvent as ReactPointerEvent } from 'react'
import type { ThreeEvent } from '@react-three/fiber'
import type { Camera, EventDispatcher, Matrix4 } from 'three'
import type { CameraView, ReceiverConfig, ReceiverPlatform, RoomConfig, WorldPosition } from '../model/types'
import { applyReceiverDragDelta, getAxisDragDelta, getCameraGroundBasis, getGroundDragDelta, getPlaneDragDelta, getReceiverPlaneAnchor, getWorldUnitsPerPixel, intersectReceiverPlane } from './receiverDrag'
import type { GroundBasis, ReceiverDragAxis, ScreenPoint } from './receiverDrag'

interface ReceiverDragOptions {
  receiver: ReceiverConfig
  room: RoomConfig
  view: CameraView
  cameraReset: number
  onSelect: (inspect?: boolean) => void
  onPreview: (position: WorldPosition) => void
  onCommit: (position: WorldPosition | null) => void
  onDragChange: (dragging: boolean) => void
}

type DragControls = EventDispatcher & { enabled: boolean }

interface DragSession {
  pointerId: number
  axis: ReceiverDragAxis
  camera: Camera
  cameraMatrix: Matrix4
  projectionMatrix: Matrix4
  controls: DragControls | null
  controlsEnabled: boolean
  captureTarget: HTMLElement
  cursorTarget: HTMLCanvasElement
  originalCursor: string
  rect: DOMRect
  room: RoomConfig
  platform: ReceiverPlatform
  yaw: number
  startScreen: ScreenPoint
  startPosition: WorldPosition
  planeAnchor: WorldPosition | null
  fallback: { screen: ScreenPoint; position: WorldPosition } | null
  basis: GroundBasis
  unitsPerPixel: number
  lastScreen: ScreenPoint
  lastPosition: WorldPosition
  moved: boolean
  frame: number | null
  removeListeners: () => void
}

function pointerRay(camera: Camera, point: ScreenPoint, rect: DOMRect) {
  const raycaster = new Raycaster()
  raycaster.setFromCamera(new Vector2(
    (point.x - rect.left) / rect.width * 2 - 1,
    -(point.y - rect.top) / rect.height * 2 + 1,
  ), camera)
  return raycaster.ray
}

function cameraChanged(drag: DragSession) {
  return !drag.camera.matrixWorld.equals(drag.cameraMatrix) || !drag.camera.projectionMatrix.equals(drag.projectionMatrix)
}

export default function useReceiverDrag(options: ReceiverDragOptions) {
  const camera = useThree((state) => state.camera)
  const controls = useThree((state) => state.controls) as DragControls | null
  const gl = useThree((state) => state.gl)
  const size = useThree((state) => state.size)
  const invalidate = useThree((state) => state.invalidate)
  const latest = useRef(options)
  const session = useRef<DragSession | null>(null)
  const suppressedClick = useRef<{ pointerId: number; until: number } | null>(null)
  const [activeAxis, setActiveAxis] = useState<ReceiverDragAxis | null>(null)

  useLayoutEffect(() => { latest.current = options })

  const finish = useCallback((cancelled: boolean, updateState = true) => {
    const drag = session.current
    if (!drag) return
    session.current = null
    if (drag.frame !== null) window.cancelAnimationFrame(drag.frame)
    drag.removeListeners()
    if (drag.controls) drag.controls.enabled = drag.controlsEnabled
    drag.cursorTarget.style.cursor = drag.originalCursor
    if (drag.captureTarget.hasPointerCapture(drag.pointerId)) drag.captureTarget.releasePointerCapture(drag.pointerId)
    suppressedClick.current = cancelled || drag.moved ? { pointerId: drag.pointerId, until: performance.now() + 500 } : null
    if (updateState) setActiveAxis(null)
    latest.current.onDragChange(false)
    latest.current.onCommit(!cancelled && drag.moved ? [...drag.lastPosition] : null)
    invalidate()
  }, [invalidate])

  const updatePosition = useCallback((event: PointerEvent) => {
    const drag = session.current
    if (!drag || event.pointerId !== drag.pointerId) return
    if (cameraChanged(drag)) {
      finish(true)
      return
    }
    const point = { x: event.clientX, y: event.clientY }
    const delta = { x: point.x - drag.startScreen.x, y: point.y - drag.startScreen.y }
    if (!drag.moved && Math.hypot(delta.x, delta.y) < 4) return
    drag.moved = true
    let position: WorldPosition
    if (drag.axis !== 'xy') {
      position = applyReceiverDragDelta(drag.startPosition, getAxisDragDelta(drag.axis, delta, drag.unitsPerPixel), drag.axis, drag.room, drag.platform, drag.yaw)
    } else {
      const hit = drag.fallback ? null : intersectReceiverPlane(pointerRay(drag.camera, point, drag.rect), drag.startPosition[2])
      if (drag.planeAnchor && hit && !drag.fallback) {
        position = applyReceiverDragDelta(drag.startPosition, getPlaneDragDelta(drag.planeAnchor, hit), 'xy', drag.room, drag.platform, drag.yaw)
      } else {
        drag.fallback ??= { screen: drag.lastScreen, position: drag.lastPosition }
        const fallbackDelta = { x: point.x - drag.fallback.screen.x, y: point.y - drag.fallback.screen.y }
        position = applyReceiverDragDelta(drag.fallback.position, getGroundDragDelta(fallbackDelta, drag.unitsPerPixel, drag.basis), 'xy', drag.room, drag.platform, drag.yaw)
      }
    }
    drag.lastScreen = point
    if (position.every((value, index) => value === drag.lastPosition[index])) return
    drag.lastPosition = position
    if (drag.frame === null) {
      drag.frame = window.requestAnimationFrame(() => {
        drag.frame = null
        if (session.current !== drag) return
        latest.current.onPreview([...drag.lastPosition])
        invalidate()
      })
    }
  }, [finish, invalidate])

  const begin = useCallback((axis: ReceiverDragAxis, event: PointerEvent, captureTarget: HTMLElement, stopEvent: () => void) => {
    if (session.current || !event.isPrimary || event.button !== 0) return
    const rect = gl.domElement.getBoundingClientRect()
    if (rect.width <= 0 || rect.height <= 0) return
    camera.updateMatrixWorld(true)
    const startPosition: WorldPosition = [...latest.current.receiver.position]
    const startScreen = { x: event.clientX, y: event.clientY }
    const unitsPerPixel = getWorldUnitsPerPixel(camera, startPosition, rect.height)
    if (unitsPerPixel <= 0) return
    const controlsEnabled = controls?.enabled ?? false
    if (controls) controls.enabled = false
    stopEvent()
    const planeAnchor = axis === 'xy' ? getReceiverPlaneAnchor(camera, pointerRay(camera, startScreen, rect), startPosition) : null
    const drag: DragSession = {
      pointerId: event.pointerId, axis, camera,
      cameraMatrix: camera.matrixWorld.clone(), projectionMatrix: camera.projectionMatrix.clone(),
      controls, controlsEnabled, captureTarget,
      cursorTarget: gl.domElement, originalCursor: gl.domElement.style.cursor,
      rect, room: { ...latest.current.room }, platform: latest.current.receiver.platform, yaw: latest.current.receiver.yaw, startScreen, startPosition, planeAnchor,
      fallback: axis === 'xy' && !planeAnchor ? { screen: startScreen, position: startPosition } : null,
      basis: getCameraGroundBasis(camera), unitsPerPixel,
      lastScreen: startScreen, lastPosition: startPosition, moved: false, frame: null,
      removeListeners: () => {},
    }
    session.current = drag
    gl.domElement.style.cursor = 'grabbing'

    const move = (next: PointerEvent) => {
      if (next.pointerId !== drag.pointerId) return
      next.stopPropagation()
      if (next.cancelable) next.preventDefault()
      if (next.pointerType === 'mouse' && (next.buttons & 1) === 0) finish(true)
      else updatePosition(next)
    }
    const up = (next: PointerEvent) => {
      if (next.pointerId !== drag.pointerId) return
      next.stopPropagation()
      if (next.cancelable) next.preventDefault()
      updatePosition(next)
      finish(false)
    }
    const cancel = (next: PointerEvent) => { if (next.pointerId === drag.pointerId) finish(true) }
    const blur = () => finish(true)
    const keydown = (next: KeyboardEvent) => { if (next.key === 'Escape') finish(true) }
    const blockAdditionalPointer = (next: PointerEvent) => { if (next.pointerId !== drag.pointerId) next.stopPropagation() }
    window.addEventListener('pointermove', move, { capture: true, passive: false })
    window.addEventListener('pointerup', up, { capture: true, passive: false })
    window.addEventListener('pointercancel', cancel, true)
    window.addEventListener('lostpointercapture', cancel, true)
    window.addEventListener('pointerdown', blockAdditionalPointer, true)
    window.addEventListener('blur', blur)
    window.addEventListener('keydown', keydown, true)
    drag.removeListeners = () => {
      window.removeEventListener('pointermove', move, true)
      window.removeEventListener('pointerup', up, true)
      window.removeEventListener('pointercancel', cancel, true)
      window.removeEventListener('lostpointercapture', cancel, true)
      window.removeEventListener('pointerdown', blockAdditionalPointer, true)
      window.removeEventListener('blur', blur)
      window.removeEventListener('keydown', keydown, true)
    }
    try {
      captureTarget.setPointerCapture(event.pointerId)
    } catch (error) {
      finish(true)
      if (!(error instanceof DOMException && error.name === 'NotFoundError')) throw error
      return
    }
    setActiveAxis(axis)
    latest.current.onDragChange(true)
    latest.current.onSelect(false)
    invalidate()
  }, [camera, controls, gl, finish, updatePosition, invalidate])

  useLayoutEffect(() => {
    finish(true)
  }, [camera, controls, options.view, options.cameraReset, options.receiver.platform, options.receiver.yaw, options.room.width, options.room.depth, options.room.height, size.width, size.height, finish])

  useEffect(() => {
    const click = (event: MouseEvent) => {
      const suppressed = suppressedClick.current
      if (!suppressed || event.detail === 0 || performance.now() > suppressed.until) return
      if (event instanceof PointerEvent && event.pointerId !== suppressed.pointerId) return
      suppressedClick.current = null
      event.preventDefault()
      event.stopImmediatePropagation()
    }
    const down = () => { suppressedClick.current = null }
    window.addEventListener('click', click, true)
    window.addEventListener('pointerdown', down, true)
    return () => {
      finish(true, false)
      window.removeEventListener('click', click, true)
      window.removeEventListener('pointerdown', down, true)
    }
  }, [finish])

  useFrame(() => {
    const drag = session.current
    if (drag && cameraChanged(drag)) finish(true)
  }, -0.25)

  const onBodyPointerDown = (event: ThreeEvent<PointerEvent>) => {
    begin('xy', event.nativeEvent, gl.domElement, () => {
      event.stopPropagation()
      event.nativeEvent.stopPropagation()
    })
  }

  const onHandlePointerDown = (axis: ReceiverDragAxis, event: ReactPointerEvent<HTMLButtonElement>) => {
    begin(axis, event.nativeEvent, event.currentTarget, () => {
      event.stopPropagation()
      event.preventDefault()
    })
  }

  return { activeAxis, dragging: activeAxis !== null, onBodyPointerDown, onHandlePointerDown }
}
