import { RECEIVER_GEOMETRY } from '../../model/receiver'
import Photodiode from './Photodiode'

const { diameter, height } = RECEIVER_GEOMETRY
const radius = diameter / 2
const top = height / 2

export default function CylinderPlatform({ yaw }: { yaw: number }) {
  return (
    <group name="receiver-platform-cylinder">
      <mesh castShadow receiveShadow>
        <cylinderGeometry args={[radius, radius, height - 0.004, 64]} />
        <meshStandardMaterial color="#384448" metalness={0.18} roughness={0.76} />
      </mesh>
      {[-1, 1].map((side) => (
        <mesh key={side} position={[0, side * (top - 0.001), 0]} castShadow>
          <cylinderGeometry args={[radius, radius, 0.002, 64]} />
          <meshStandardMaterial color="#aab3b5" metalness={0.78} roughness={0.34} />
        </mesh>
      ))}
      {[-0.024, 0.024].map((level) => (
        <mesh key={level} position={[0, level, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[radius - 0.0003, 0.0003, 6, 64]} />
          <meshStandardMaterial color="#202a2e" roughness={0.85} />
        </mesh>
      ))}
      <mesh position={[0, -0.013, radius - 0.0008]}>
        <boxGeometry args={[0.01, 0.006, 0.001]} />
        <meshStandardMaterial color="#171e22" metalness={0.25} roughness={0.7} />
      </mesh>
      <group rotation={[0, yaw * Math.PI / 180, 0]}>
        <mesh position={[0, top - 0.0005, 0]} castShadow receiveShadow>
          <cylinderGeometry args={[radius - 0.004, radius - 0.004, 0.001, 64]} />
          <meshStandardMaterial color="#566164" metalness={0.42} roughness={0.61} />
        </mesh>
        <mesh position={[0.029, top + 0.00015, 0]}>
          <boxGeometry args={[0.016, 0.0003, 0.0015]} />
          <meshStandardMaterial color="#e2dfcd" roughness={0.75} />
        </mesh>
        {[Math.PI / 3, Math.PI, Math.PI * 5 / 3].map((angle) => (
          <mesh key={angle} position={[Math.cos(angle) * 0.037, top + 0.00015, Math.sin(angle) * 0.037]}>
            <cylinderGeometry args={[0.0015, 0.0015, 0.0003, 12]} />
            <meshStandardMaterial color="#a0aaad" metalness={0.8} roughness={0.4} />
          </mesh>
        ))}
        <Photodiode platform="cylinder" />
      </group>
    </group>
  )
}
