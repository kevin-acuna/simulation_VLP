import { useMemo } from 'react'
import { ContactShadows, Environment, Lightformer } from '@react-three/drei'
import { Object3D } from 'three'
import type { RoomConfig } from '../model/types'

export default function SceneLighting({ room, interior }: { room: RoomConfig; interior: boolean }) {
  const { width, depth, height } = room
  const extent = Math.max(width, depth, height)
  const target = useMemo(() => new Object3D(), [])

  return (
    <group>
      <hemisphereLight args={['#fffdf3', interior ? '#b5aa96' : '#9ca99f', interior ? 0.4 : 1.35]} />
      <ambientLight color="#f2f1e9" intensity={interior ? 0.08 : 0.22} />
      <primitive object={target} position={[0, 0, 0]} />
      <directionalLight
        position={[width * 0.1 + 3, height + 5, depth + 2]}
        target={target}
        color="#fff8e9"
        intensity={interior ? 0.12 : 2.1}
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-camera-left={-extent}
        shadow-camera-right={extent}
        shadow-camera-top={extent}
        shadow-camera-bottom={-extent}
        shadow-camera-near={0.1}
        shadow-camera-far={extent * 5 + 20}
        shadow-bias={-0.0002}
        shadow-normalBias={0.02}
        shadow-radius={3}
      />
      <Environment resolution={128} frames={1} environmentIntensity={interior ? 0.065 : 0.35} background={false}>
        <Lightformer form="rect" color="#fffaf0" intensity={2} position={[0, 5, 0]} rotation={[Math.PI / 2, 0, 0]} scale={[8, 8, 1]} />
        <Lightformer form="rect" color="#e9f0ee" intensity={2.5} position={[-5, 2, 0]} rotation={[0, Math.PI / 2, 0]} scale={[5, 5, 1]} />
        <Lightformer form="rect" color="#ffffff" intensity={1.5} position={[3, 2, 4]} rotation={[0, Math.PI, 0]} scale={[5, 3, 1]} />
      </Environment>
      <mesh position={[0, -0.158, 0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[extent * 4, extent * 4]} />
        <shadowMaterial color="#5b6a60" transparent opacity={0.12} depthWrite={false} />
      </mesh>
      <ContactShadows
        key={`${width}-${depth}-${height}`}
        position={[0, -0.15, 0]}
        depthWrite={false}
        scale={extent * 2.3}
        opacity={0.3}
        blur={2.2}
        far={0.55}
        resolution={256}
        frames={1}
        color="#5c665b"
      />
    </group>
  )
}
