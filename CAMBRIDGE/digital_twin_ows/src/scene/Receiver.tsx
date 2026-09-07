import { useEffect, useState } from 'react'
import { Html, Line, useCursor } from '@react-three/drei'
import { MoveHorizontal, MoveVertical, Settings2 } from 'lucide-react'
import { Vector3 } from 'three'
import { toScenePosition } from '../model/config'
import { getPhotodiodePosition, getReceiverGeometry, getReceiverRadius, RECEIVER_ID } from '../model/receiver'
import type { CameraView, ReceiverConfig, RoomConfig, WorldPosition } from '../model/types'
import CylinderPlatform from './platforms/CylinderPlatform'
import DronePlatform from './platforms/DronePlatform'
import useReceiverDrag from './useReceiverDrag'

interface ReceiverProps {
  receiver: ReceiverConfig
  room: RoomConfig
  selected: boolean
  view: CameraView
  cameraReset: number
  accent: string
  guideColor: string
  onSelect: (inspect?: boolean) => void
  onPreview: (position: WorldPosition) => void
  onCommit: (position: WorldPosition | null) => void
  onDragChange: (dragging: boolean) => void
}

const axes = ['x', 'y', 'z'] as const

export default function Receiver({ receiver, room, selected, view, cameraReset, accent, guideColor, onSelect, onPreview, onCommit, onDragChange }: ReceiverProps) {
  const [hovered, setHovered] = useState(false)
  const [controlsOpen, setControlsOpen] = useState(false)
  const { activeAxis, dragging, onBodyPointerDown, onHandlePointerDown } = useReceiverDrag({ receiver, room, view, cameraReset, onSelect, onPreview, onCommit, onDragChange })
  useCursor(hovered || dragging, dragging ? 'grabbing' : 'grab')
  const { width, depth, height, pdThickness } = getReceiverGeometry(receiver.platform)
  const radius = getReceiverRadius(receiver.platform)
  const top = height / 2
  const sensorPosition = toScenePosition(getPhotodiodePosition({ ...receiver, position: [0, 0, 0] }))
  const floor = -receiver.position[2] + 0.012
  const hasControls = selected && controlsOpen

  useEffect(() => {
    if (!selected) setControlsOpen(false)
  }, [selected])

  function toggleControls() {
    onSelect(false)
    setControlsOpen((open) => !open)
  }

  return (
    <group position={toScenePosition(receiver.position)} name={RECEIVER_ID}>
      <group
        onPointerDown={onBodyPointerDown}
        onClick={(event) => event.stopPropagation()}
        onDoubleClick={(event) => { event.stopPropagation(); toggleControls() }}
        onPointerOver={(event) => { event.stopPropagation(); setHovered(true) }}
        onPointerOut={() => setHovered(false)}
      >
        {receiver.platform === 'drone'
          ? <DronePlatform yaw={receiver.yaw} rotorsSpinning={receiver.rotorsSpinning} />
          : <CylinderPlatform yaw={receiver.yaw} />}
        <mesh name="receiver-pick-target" rotation={[0, receiver.yaw * Math.PI / 180, 0]}>
          {receiver.platform === 'drone'
            ? <boxGeometry args={[width + 0.012, height + pdThickness + 0.012, depth + 0.012]} />
            : <sphereGeometry args={[radius + 0.035, 20, 12]} />}
          <meshBasicMaterial transparent opacity={0} colorWrite={false} depthWrite={false} />
        </mesh>
      </group>
      {(selected || hovered) && (
        <mesh position={[0, -top + 0.002, 0]} rotation={[-Math.PI / 2, 0, 0]} raycast={() => {}}>
          <ringGeometry args={[radius + 0.006, radius + 0.008, 64]} />
          <meshBasicMaterial color={accent} transparent opacity={selected ? 0.8 : 0.4} depthWrite={false} toneMapped={false} />
        </mesh>
      )}
      {selected && (
        <group>
          <Line
            points={[[0, -top, 0], [0, floor, 0]]}
            color={guideColor}
            lineWidth={1}
            transparent
            opacity={0.6}
            dashed
            dashSize={0.035}
            gapSize={0.03}
            depthWrite={false}
            raycast={() => {}}
          />
          <mesh position={[0, floor, 0]} rotation={[-Math.PI / 2, 0, 0]} raycast={() => {}}>
            <ringGeometry args={[radius + 0.013, radius + 0.018, 64]} />
            <meshBasicMaterial color={accent} transparent opacity={0.65} depthWrite={false} toneMapped={false} />
          </mesh>
        </group>
      )}
      <Html
        position={[sensorPosition[0], sensorPosition[1] + pdThickness / 2, sensorPosition[2]]}
        zIndexRange={[24, 12]}
        style={{ pointerEvents: 'none' }}
        calculatePosition={(object, camera, size) => {
          const point = new Vector3().setFromMatrixPosition(object.matrixWorld).project(camera)
          const width = hasControls ? Math.min(230, size.width - 32) : 56
          const overlayHeight = hasControls ? 178 : 24
          const x = (point.x + 1) * size.width / 2
          const y = (1 - point.y) * size.height / 2
          const fitsRight = x + 30 + width <= size.width - 12
          const fitsLeft = x - width - 30 >= 12
          const left = fitsRight ? x + 30 : fitsLeft ? x - width - 30 : x - width / 2
          const upper = fitsRight || fitsLeft ? y - 40 : y - overlayHeight - 24
          return [
            Math.max(12, Math.min(size.width - width - 12, left)),
            Math.max(12, Math.min(size.height - overlayHeight - 12, upper)),
          ]
        }}
      >
        <div className="receiver-overlay" style={{ pointerEvents: 'none' }}>
          <button
            type="button"
            className={`receiver-tag${selected ? ' selected' : ''}${view === 'perspective' ? ' interior' : ''}`}
            aria-label="Move receiver in X and Y"
            aria-pressed={selected}
            aria-expanded={hasControls && !dragging}
            data-dragging={dragging}
            title="Drag to move X/Y · Double-click for axis controls"
            style={{ cursor: dragging ? 'grabbing' : 'grab' }}
            onPointerDown={(event) => onHandlePointerDown('xy', event)}
            onClick={(event) => { event.stopPropagation(); if (event.detail === 0) toggleControls() }}
            onDoubleClick={(event) => { event.stopPropagation(); toggleControls() }}
            onKeyDown={(event) => { if (event.key === 'Escape') setControlsOpen(false) }}
            onDragStart={(event) => event.preventDefault()}
          >
            {RECEIVER_ID}
          </button>
          {hasControls && (
            <div
              className="receiver-hud"
              role="group"
              aria-label="Receiver world position and drag controls"
              aria-hidden={dragging}
              style={{ pointerEvents: dragging ? 'none' : 'auto', visibility: dragging ? 'hidden' : 'visible', marginTop: 6 }}
              onPointerDown={(event) => event.stopPropagation()}
              onClick={(event) => event.stopPropagation()}
              onWheel={(event) => event.stopPropagation()}
            >
              <div className="receiver-coordinates" aria-label="World body-centre coordinates in metres">
                {axes.map((axis, index) => (
                  <span key={axis} data-axis={axis}><strong>{axis.toUpperCase()}</strong> {receiver.position[index].toFixed(3)}</span>
                ))}
                <span>m</span>
              </div>
              <div className="receiver-actions receiver-axis-controls">
                {axes.map((axis) => (
                  <button
                    key={axis}
                    type="button"
                    className={`receiver-axis${activeAxis === axis ? ' active' : ''}`}
                    data-axis={axis}
                    data-dragging={activeAxis === axis}
                    aria-label={`Move receiver along ${axis.toUpperCase()}`}
                    title={`World ${axis.toUpperCase()}: drag ${axis === 'x' ? 'right' : 'up'} to increase`}
                    style={{ touchAction: 'none', minWidth: 32, minHeight: 32, cursor: axis === 'x' ? 'ew-resize' : 'ns-resize' }}
                    onPointerDown={(event) => onHandlePointerDown(axis, event)}
                    onClick={(event) => event.stopPropagation()}
                    onDragStart={(event) => event.preventDefault()}
                  >
                    {axis === 'x' ? <MoveHorizontal size={12} aria-hidden="true" /> : <MoveVertical size={12} aria-hidden="true" />}
                    {axis.toUpperCase()}
                  </button>
                ))}
                <button
                  type="button"
                  className="receiver-properties"
                  aria-label="Receiver properties"
                  title="Receiver properties"
                  style={{ minWidth: 32, minHeight: 32 }}
                  onPointerDown={(event) => event.stopPropagation()}
                  onClick={(event) => { event.stopPropagation(); onSelect(true) }}
                >
                  <Settings2 size={14} aria-hidden="true" />
                </button>
              </div>
              <div className="receiver-drag-hint">{dragging ? 'Release to place · Esc to cancel' : 'Drag XY or a world axis · Z sets height'}</div>
            </div>
          )}
        </div>
      </Html>
    </group>
  )
}
