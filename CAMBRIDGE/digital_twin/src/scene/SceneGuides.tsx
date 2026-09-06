import { useMemo } from 'react'
import { Html, Line } from '@react-three/drei'
import type { DisplayConfig, RoomConfig } from '../model/types'
import { getFloorGridPositions, getRoomBounds } from './coordinates'
import type { ScenePosition } from './coordinates'

interface SceneGuidesProps {
  room: RoomConfig
  display: DisplayConfig
  accent: string
  guideColor: string
}

function FloorGrid({ room, guideColor }: { room: RoomConfig; guideColor: string }) {
  const positions = useMemo(() => getFloorGridPositions(room), [room.width, room.depth])

  return (
    <lineSegments>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <lineBasicMaterial color={guideColor} transparent opacity={0.2} depthWrite={false} />
    </lineSegments>
  )
}

interface DimensionProps {
  start: ScenePosition
  end: ScenePosition
  tick: ScenePosition
  labelPosition: ScenePosition
  value: number
  axis: string
  accent: string
}

function Dimension({ start, end, tick, labelPosition, value, axis, accent }: DimensionProps) {
  const cap = (point: ScenePosition): [ScenePosition, ScenePosition] => [
    [point[0] - tick[0], point[1] - tick[1], point[2] - tick[2]],
    [point[0] + tick[0], point[1] + tick[1], point[2] + tick[2]],
  ]

  return (
    <group>
      <Line points={[start, end]} color={accent} lineWidth={0.8} transparent opacity={0.62} depthWrite={false} />
      <Line points={cap(start)} color={accent} lineWidth={0.8} transparent opacity={0.62} depthWrite={false} />
      <Line points={cap(end)} color={accent} lineWidth={0.8} transparent opacity={0.62} depthWrite={false} />
      <Html center position={labelPosition} zIndexRange={[9, 0]} style={{ pointerEvents: 'none', whiteSpace: 'nowrap' }}>
        <span className="dimension-label"><span className="dimension-axis">{axis}</span> {value.toFixed(2)} m</span>
      </Html>
    </group>
  )
}

export default function SceneGuides({ room, display, accent, guideColor }: SceneGuidesProps) {
  const { width, depth, height } = room
  const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
  return (
    <group>
      {display.grid && <FloorGrid room={room} guideColor={guideColor} />}
      {display.dimensions && (
        <group>
          <Dimension accent={accent} start={[minX, -0.035, maxZ + 0.34]} end={[maxX, -0.035, maxZ + 0.34]} tick={[0, 0, 0.055]} labelPosition={[0, -0.025, maxZ + 0.42]} value={width} axis="X" />
          <Dimension accent={accent} start={[maxX + 0.34, -0.035, maxZ]} end={[maxX + 0.34, -0.035, minZ]} tick={[0.055, 0, 0]} labelPosition={[maxX + 0.43, -0.025, 0]} value={depth} axis="Y" />
          <Dimension accent={accent} start={[minX - 0.24, 0, maxZ + 0.16]} end={[minX - 0.24, height, maxZ + 0.16]} tick={[0.055, 0, 0]} labelPosition={[minX - 0.31, height / 2, maxZ + 0.19]} value={height} axis="Z" />
        </group>
      )}
    </group>
  )
}
