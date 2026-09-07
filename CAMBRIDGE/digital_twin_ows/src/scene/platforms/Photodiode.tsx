import { toScenePosition } from '../../model/config'
import { getPhotodiodePosition, getReceiverGeometry } from '../../model/receiver'
import type { ReceiverPlatform } from '../../model/types'

const frameWidth = 0.0006

export default function Photodiode({ platform }: { platform: ReceiverPlatform }) {
  const { pdWidth, pdDepth, pdThickness } = getReceiverGeometry(platform)
  const position = toScenePosition(getPhotodiodePosition({ position: [0, 0, 0], yaw: 0, platform, rotorsSpinning: false }))

  return (
    <group name="receiver-photodiode" position={position}>
      <mesh name="photodiode-active-area" castShadow>
        <boxGeometry args={[pdWidth, pdThickness, pdDepth]} />
        <meshStandardMaterial color="#0b1521" metalness={0.12} roughness={0.29} />
      </mesh>
      {[-1, 1].map((side) => (
        <group key={side}>
          <mesh position={[side * (pdWidth + frameWidth) / 2, -0.0002, 0]}>
            <boxGeometry args={[frameWidth, pdThickness - 0.0004, pdDepth + frameWidth * 2]} />
            <meshStandardMaterial color="#b49c5c" metalness={0.74} roughness={0.42} />
          </mesh>
          <mesh position={[0, -0.0002, side * (pdDepth + frameWidth) / 2]}>
            <boxGeometry args={[pdWidth, pdThickness - 0.0004, frameWidth]} />
            <meshStandardMaterial color="#b49c5c" metalness={0.74} roughness={0.42} />
          </mesh>
        </group>
      ))}
    </group>
  )
}
