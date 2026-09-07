import { useMemo, useState } from 'react'
import { Html, Line, RoundedBox, useCursor } from '@react-three/drei'
import { Object3D } from 'three'
import type { ThreeEvent } from '@react-three/fiber'
import type { LedFixture } from '../model/types'
import { temperatureColor, toScenePosition } from './coordinates'
import type { ScenePosition } from './coordinates'

interface LedProps {
  fixture: LedFixture
  selected: boolean
  labels: boolean
  beams: boolean
  castShadow: boolean
  interior: boolean
  accent: string
  guideColor: string
  onSelect: (id: string | null) => void
}

function CircularHousing({ color, power }: { color: string; power: number }) {
  return (
    <group>
      <mesh position={[0, -0.007, 0]} castShadow>
        <cylinderGeometry args={[0.082, 0.082, 0.014, 48]} />
        <meshStandardMaterial color="#626e6a" metalness={0.7} roughness={0.35} />
      </mesh>
      <mesh position={[0, -0.031, 0]} castShadow>
        <cylinderGeometry args={[0.105, 0.105, 0.044, 64]} />
        <meshStandardMaterial color="#bcc5c0" metalness={0.68} roughness={0.3} />
      </mesh>
      {[-0.02, -0.032, -0.044].map((height) => (
        <mesh key={height} position={[0, height, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.105, 0.0018, 6, 48]} />
          <meshStandardMaterial color="#809088" metalness={0.6} roughness={0.43} />
        </mesh>
      ))}
      <mesh position={[0, -0.055, 0]}>
        <cylinderGeometry args={[0.11, 0.11, 0.008, 64]} />
        <meshStandardMaterial color="#e8ebe4" metalness={0.48} roughness={0.24} />
      </mesh>
      <mesh position={[0, -0.065, 0]}>
        <cylinderGeometry args={[0.106, 0.106, 0.012, 64]} />
        <meshStandardMaterial color={power > 0 ? '#fffdf0' : '#cbd0c7'} emissive={color} emissiveIntensity={power > 0 ? Math.min(3, 0.8 + power * 2.5) : 0} roughness={0.56} toneMapped={false} />
      </mesh>
    </group>
  )
}

function SquareHousing({ color, power }: { color: string; power: number }) {
  return (
    <group>
      <RoundedBox args={[0.15, 0.014, 0.15]} radius={0.008} smoothness={3} position={[0, -0.007, 0]} castShadow>
        <meshStandardMaterial color="#626e6a" metalness={0.7} roughness={0.35} />
      </RoundedBox>
      <RoundedBox args={[0.21, 0.044, 0.21]} radius={0.009} smoothness={3} position={[0, -0.031, 0]} castShadow>
        <meshStandardMaterial color="#bcc5c0" metalness={0.68} roughness={0.3} />
      </RoundedBox>
      <RoundedBox args={[0.22, 0.008, 0.22]} radius={0.003} smoothness={3} position={[0, -0.055, 0]}>
        <meshStandardMaterial color="#e8ebe4" metalness={0.48} roughness={0.24} />
      </RoundedBox>
      <RoundedBox args={[0.208, 0.012, 0.208]} radius={0.004} smoothness={3} position={[0, -0.065, 0]}>
        <meshStandardMaterial color={power > 0 ? '#fffdf0' : '#cbd0c7'} emissive={color} emissiveIntensity={power > 0 ? Math.min(3, 0.8 + power * 2.5) : 0} roughness={0.56} toneMapped={false} />
      </RoundedBox>
    </group>
  )
}

function BeamGuide({ height, selected, accent, guideColor }: { height: number; selected: boolean; accent: string; guideColor: string }) {
  const radius = height * 0.46
  const floor = -height + 0.014
  const circle = useMemo<ScenePosition[]>(() => Array.from({ length: 65 }, (_, index) => {
    const angle = (index / 64) * Math.PI * 2
    return [Math.cos(angle) * radius, floor, Math.sin(angle) * radius]
  }), [radius, floor])
  const color = selected ? accent : guideColor

  return (
    <group>
      <Line points={circle} color={color} lineWidth={0.8} transparent opacity={selected ? 0.32 : 0.15} dashed dashSize={0.05} gapSize={0.045} depthWrite={false} />
      {[0, Math.PI / 2, Math.PI, Math.PI * 1.5].map((angle) => (
        <Line key={angle} points={[[0, -0.064, 0], [Math.cos(angle) * radius, floor, Math.sin(angle) * radius]]} color={color} lineWidth={0.7} transparent opacity={selected ? 0.2 : 0.09} dashed dashSize={0.055} gapSize={0.045} depthWrite={false} />
      ))}
    </group>
  )
}

export default function Led({ fixture, selected, labels, beams, castShadow, interior, accent, guideColor, onSelect }: LedProps) {
  const [hovered, setHovered] = useState(false)
  const position = toScenePosition(fixture.position)
  const color = temperatureColor(fixture.temperature)
  const power = Math.max(0, fixture.power)
  const target = useMemo(() => new Object3D(), [])
  useCursor(hovered)

  const select = (event: ThreeEvent<MouseEvent>) => {
    event.stopPropagation()
    onSelect(fixture.id)
  }

  return (
    <group position={position}>
      <group
        onClick={select}
        onPointerOver={(event) => { event.stopPropagation(); setHovered(true) }}
        onPointerOut={() => setHovered(false)}
      >
        {fixture.shape === 'square'
          ? <SquareHousing color={color} power={power} />
          : <CircularHousing color={color} power={power} />}
        {(selected || hovered) && (
          <mesh position={[0, -0.046, 0]} rotation={[Math.PI / 2, 0, 0]}>
            <torusGeometry args={[0.16, selected ? 0.004 : 0.002, 8, 64]} />
            <meshBasicMaterial color={accent} transparent opacity={selected ? 0.95 : 0.5} toneMapped={false} />
          </mesh>
        )}
      </group>
      <primitive object={target} position={[0, -Math.max(1, fixture.position[2]), 0]} />
      <spotLight
        position={[0, -0.072, 0]}
        target={target}
        color={color}
        intensity={power * 22}
        distance={Math.max(4, fixture.position[2] * 3)}
        angle={0.9}
        penumbra={0.95}
        decay={2}
        castShadow={castShadow && power > 0}
        shadow-mapSize={[512, 512]}
        shadow-bias={-0.00025}
        shadow-normalBias={0.025}
        shadow-camera-near={0.04}
        shadow-camera-far={Math.max(4, fixture.position[2] * 3)}
      />
      {interior && power > 0 && (
        <pointLight
          position={[0, -0.18, 0]}
          color={color}
          intensity={Math.min(0.12, power * 0.12)}
          distance={0.9}
          decay={2}
        />
      )}
      {labels && (
        <Html position={interior ? [0, -0.16, 0] : [0, 0.08, 0]} center zIndexRange={[30, 10]}>
          <div style={{ transform: interior ? 'translateY(6px)' : 'translateY(-20px)' }}>
            <button
              type="button"
              className={`led-tag${interior ? ' interior' : ''}${selected ? ' selected' : ''}`}
              aria-label={`Select ${fixture.id}, ${fixture.power.toFixed(3)} optical watts`}
              aria-pressed={selected}
              onPointerDown={(event) => event.stopPropagation()}
              onClick={(event) => { event.stopPropagation(); onSelect(fixture.id) }}
            >
              <span className="led-tag-dot" aria-hidden="true" />
              {fixture.id}
            </button>
          </div>
        </Html>
      )}
      {beams && <BeamGuide height={fixture.position[2]} selected={selected} accent={accent} guideColor={guideColor} />}
      {selected && (
        <mesh position={[0, -fixture.position[2] + 0.012, 0]} rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[0.12, 0.128, 48]} />
          <meshBasicMaterial color={accent} transparent opacity={0.6} depthWrite={false} toneMapped={false} />
        </mesh>
      )}
    </group>
  )
}
