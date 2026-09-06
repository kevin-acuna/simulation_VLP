import { useEffect, useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Line } from '@react-three/drei'
import { DataTexture, DoubleSide, LinearFilter, RepeatWrapping, RGBAFormat, SRGBColorSpace, Vector3 } from 'three'
import type { Group } from 'three'
import type { RoomConfig } from '../model/types'
import { getRoomBounds } from './coordinates'
import type { ScenePosition } from './coordinates'

interface RoomProps {
  room: RoomConfig
  ceiling: boolean
  interior: boolean
  guideColor: string
}

function useConcreteTexture(width: number, depth: number) {
  const texture = useMemo(() => {
    const size = 128
    const pixels = new Uint8Array(size * size * 4)
    let seed = 32771
    for (let index = 0; index < size * size; index += 1) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
      const grain = 229 + Math.round((seed / 4294967296) * 14)
      pixels[index * 4] = grain
      pixels[index * 4 + 1] = grain
      pixels[index * 4 + 2] = grain - 2
      pixels[index * 4 + 3] = 255
    }
    const result = new DataTexture(pixels, size, size, RGBAFormat)
    result.wrapS = RepeatWrapping
    result.wrapT = RepeatWrapping
    result.repeat.set(width * 1.5, depth * 1.5)
    result.magFilter = LinearFilter
    result.minFilter = LinearFilter
    result.colorSpace = SRGBColorSpace
    result.needsUpdate = true
    return result
  }, [width, depth])

  useEffect(() => () => texture.dispose(), [texture])
  return texture
}

interface CutawayWallProps {
  center: ScenePosition
  size: ScenePosition
  normal: [number, number]
  room: RoomConfig
  color: string
  interior: boolean
}

export function isInteriorWallVisible(position: Pick<Vector3, 'x' | 'z'>, center: ScenePosition, size: ScenePosition, normal: [number, number]): boolean {
  const halfThickness = (Math.abs(normal[0]) * size[0] + Math.abs(normal[1]) * size[2]) / 2
  const exteriorDistance = (position.x - center[0]) * normal[0] + (position.z - center[2]) * normal[1] + halfThickness
  return exteriorDistance <= 0.001
}

function CutawayWall({ center, size, normal, room, color, interior }: CutawayWallProps) {
  const group = useRef<Group>(null)
  const direction = useMemo(() => new Vector3(), [])
  const position = useMemo(() => new Vector3(), [])
  const horizontal = size[0] > size[2]

  useFrame(({ camera }) => {
    if (!group.current) return
    if (interior) {
      camera.getWorldPosition(position)
      group.current.visible = isInteriorWallVisible(position, center, size, normal)
      return
    }
    camera.getWorldDirection(direction)
    const horizontalLength = Math.hypot(direction.x, direction.z)
    const facing = -direction.x * normal[0] - direction.z * normal[1]
    group.current.visible = horizontalLength < 0.01 || facing <= horizontalLength * 0.025
  })

  return (
    <group ref={group} position={center}>
      <mesh receiveShadow castShadow={interior}>
        <boxGeometry args={size} />
        <meshStandardMaterial color={color} roughness={0.94} />
      </mesh>
      <mesh position={[-normal[0] * 0.048, -room.height / 2 + 0.035, -normal[1] * 0.048]} receiveShadow castShadow={interior}>
        <boxGeometry args={[horizontal ? size[0] : 0.016, 0.07, horizontal ? 0.016 : size[2]]} />
        <meshStandardMaterial color="#ced0c8" roughness={0.72} />
      </mesh>
      <mesh position={[0, room.height / 2 + 0.009, 0]} castShadow={interior}>
        <boxGeometry args={[size[0] + (horizontal ? 0 : 0.008), 0.018, size[2] + (horizontal ? 0.008 : 0)]} />
        <meshStandardMaterial color="#f3f2ea" roughness={0.75} />
      </mesh>
    </group>
  )
}

export default function Room({ room, ceiling, interior, guideColor }: RoomProps) {
  const { width, depth, height } = room
  const concrete = useConcreteTexture(width, depth)
  const { minX, maxX, minZ, maxZ } = getRoomBounds(room)
  const perimeter = useMemo<ScenePosition[]>(() => [
    [minX, height + 0.015, maxZ],
    [maxX, height + 0.015, maxZ],
    [maxX, height + 0.015, minZ],
    [minX, height + 0.015, minZ],
    [minX, height + 0.015, maxZ],
  ], [minX, maxX, minZ, maxZ, height])

  return (
    <group>
      <mesh position={[0, -0.072, 0]} receiveShadow castShadow>
        <boxGeometry args={[width + 0.18, 0.144, depth + 0.18]} />
        <meshStandardMaterial color="#c8cbc4" roughness={0.95} />
      </mesh>
      <mesh position={[0, 0.002, 0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[width + 0.12, depth + 0.12]} />
        <meshStandardMaterial color="#e3e4dc" map={concrete} roughness={0.94} />
      </mesh>
      <CutawayWall room={room} interior={interior} center={[minX - 0.04, height / 2, 0]} size={[0.08, height, depth + 0.16]} normal={[-1, 0]} color="#e8e7de" />
      <CutawayWall room={room} interior={interior} center={[maxX + 0.04, height / 2, 0]} size={[0.08, height, depth + 0.16]} normal={[1, 0]} color="#e8e7de" />
      <CutawayWall room={room} interior={interior} center={[0, height / 2, maxZ + 0.04]} size={[width, height, 0.08]} normal={[0, 1]} color="#eeece3" />
      <CutawayWall room={room} interior={interior} center={[0, height / 2, minZ - 0.04]} size={[width, height, 0.08]} normal={[0, -1]} color="#eeece3" />
      {!interior && <Line points={perimeter} color={guideColor} lineWidth={1} transparent opacity={0.44} dashed dashSize={0.065} gapSize={0.04} depthWrite={false} />}
      {interior && (
        <mesh position={[0, height + 0.04, 0]} receiveShadow castShadow>
          <boxGeometry args={[width + 0.16, 0.08, depth + 0.16]} />
          <meshStandardMaterial color="#eeece3" roughness={0.97} metalness={0} />
        </mesh>
      )}
      {!interior && ceiling && (
        <mesh position={[0, height + 0.032, 0]} renderOrder={2}>
          <boxGeometry args={[width + 0.08, 0.035, depth + 0.08]} />
          <meshStandardMaterial color="#edf2e9" transparent opacity={0.16} roughness={0.92} side={DoubleSide} depthWrite={false} />
        </mesh>
      )}
    </group>
  )
}
