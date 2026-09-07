import { useEffect, useRef, useState } from 'react'
import { RoundedBox } from '@react-three/drei'
import { useFrame, useThree } from '@react-three/fiber'
import { DoubleSide, Shape } from 'three'
import type { Group } from 'three'
import { DRONE_GEOMETRY } from '../../model/receiver'
import Photodiode from './Photodiode'
import { advanceRotorAngle, shouldAnimateRotors } from './rotorAnimation'

const { height, motorOffset, rotorRadius } = DRONE_GEOMETRY
const motorPositions: [number, number, number][] = [
  [motorOffset, 0, motorOffset],
  [-motorOffset, 0, motorOffset],
  [-motorOffset, 0, -motorOffset],
  [motorOffset, 0, -motorOffset],
]
const rotorPlane = 0.019
const blade = new Shape()
blade.moveTo(0.006, -0.002)
blade.lineTo(0.047, -0.006)
blade.quadraticCurveTo(0.054, -0.006, 0.055, -0.002)
blade.quadraticCurveTo(0.055, 0.001, 0.05, 0.002)
blade.lineTo(0.011, 0.004)
blade.lineTo(0.006, 0.002)
blade.closePath()
const bladeExtrusion = { depth: 0.0012, bevelEnabled: false, steps: 1, curveSegments: 6 }

function RotorAssembly({ spinning }: { spinning: boolean }) {
  const rotors = useRef<(Group | null)[]>([])
  const invalidate = useThree((state) => state.invalidate)
  const [motion, setMotion] = useState(() => ({
    visible: typeof document !== 'undefined' && document.visibilityState === 'visible',
    reducedMotion: typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  }))
  const motionRef = useRef(motion)
  const running = shouldAnimateRotors('drone', spinning, motion.visible, motion.reducedMotion)

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    const refresh = () => {
      const next = { visible: document.visibilityState === 'visible', reducedMotion: media.matches }
      motionRef.current = next
      setMotion(next)
    }
    document.addEventListener('visibilitychange', refresh)
    media.addEventListener('change', refresh)
    refresh()
    return () => {
      document.removeEventListener('visibilitychange', refresh)
      media.removeEventListener('change', refresh)
      motionRef.current = { ...motionRef.current, visible: false }
    }
  }, [])

  useEffect(() => {
    if (running) invalidate()
  }, [running, invalidate])

  useFrame((_, delta) => {
    if (!shouldAnimateRotors('drone', spinning, motionRef.current.visible && document.visibilityState === 'visible', motionRef.current.reducedMotion)) return
    rotors.current.forEach((rotor, index) => {
      if (rotor) rotor.rotation.y = advanceRotorAngle(rotor.rotation.y, delta, index)
    })
    invalidate()
  })

  return (
    <group>
      {motorPositions.map((position, index) => (
        <group key={index} position={position}>
          <mesh position={[0, 0.003, 0]} castShadow receiveShadow>
            <cylinderGeometry args={[0.0115, 0.013, 0.018, 24]} />
            <meshStandardMaterial color="#30393f" metalness={0.48} roughness={0.56} />
          </mesh>
          <mesh position={[0, 0.013, 0]} castShadow>
            <cylinderGeometry args={[0.0095, 0.0105, 0.004, 24]} />
            <meshStandardMaterial color="#a8b0b1" metalness={0.64} roughness={0.4} />
          </mesh>
          <mesh position={[0, 0.0155, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
            <torusGeometry args={[rotorRadius - 0.0013, 0.0013, 6, 64]} />
            <meshStandardMaterial color="#647074" metalness={0.35} roughness={0.63} />
          </mesh>
          {[0, Math.PI / 2, Math.PI, Math.PI * 3 / 2].map((angle) => (
            <group key={angle} rotation={[0, angle, 0]}>
              <mesh position={[(rotorRadius + 0.008) / 2, 0.005, 0]} castShadow>
                <boxGeometry args={[rotorRadius - 0.01, 0.002, 0.002]} />
                <meshStandardMaterial color="#444e52" metalness={0.22} roughness={0.72} />
              </mesh>
              <mesh position={[rotorRadius - 0.002, 0.01, 0]} castShadow>
                <boxGeometry args={[0.002, 0.01, 0.002]} />
                <meshStandardMaterial color="#647074" metalness={0.35} roughness={0.63} />
              </mesh>
            </group>
          ))}
          <group name={`drone-rotor-${index}`} position={[0, rotorPlane, 0]} ref={(rotor) => { rotors.current[index] = rotor }}>
            {[0, Math.PI].map((angle) => (
              <group key={angle} rotation={[0, angle, 0]}>
                <mesh position={[0, 0.0006, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
                  <extrudeGeometry args={[blade, bladeExtrusion]} />
                  <meshStandardMaterial color={index % 2 === 0 ? '#525d63' : '#758087'} metalness={0.2} roughness={0.66} />
                </mesh>
              </group>
            ))}
            <mesh castShadow>
              <cylinderGeometry args={[0.0065, 0.007, 0.004, 20]} />
              <meshStandardMaterial color="#d3d8d6" metalness={0.5} roughness={0.42} />
            </mesh>
          </group>
          <mesh name={`drone-rotor-blur-${index}`} visible={running} position={[0, rotorPlane + 0.0008, 0]} rotation={[-Math.PI / 2, 0, 0]} raycast={() => {}} castShadow={false} receiveShadow={false}>
            <ringGeometry args={[0.009, 0.0555, 48]} />
            <meshBasicMaterial color="#89949a" transparent opacity={0.085} depthWrite={false} side={DoubleSide} toneMapped={false} />
          </mesh>
        </group>
      ))}
    </group>
  )
}

export default function DronePlatform({ yaw, rotorsSpinning }: { yaw: number, rotorsSpinning: boolean }) {
  return (
    <group name="receiver-platform-drone" rotation={[0, yaw * Math.PI / 180, 0]}>
      {motorPositions.map(([x, , z], index) => (
        <group key={index}>
          <RoundedBox args={[Math.hypot(x, z), 0.009, 0.013]} radius={0.003} smoothness={3} position={[x / 2, -0.004, z / 2]} rotation={[0, -Math.atan2(z, x), 0]} castShadow receiveShadow>
            <meshStandardMaterial color="#343f45" metalness={0.2} roughness={0.72} />
          </RoundedBox>
          <mesh position={[x * 0.54, -0.019, z * 0.54]} castShadow>
            <cylinderGeometry args={[0.0028, 0.0034, 0.016, 12]} />
            <meshStandardMaterial color="#899395" metalness={0.55} roughness={0.48} />
          </mesh>
          <RoundedBox args={[0.014, 0.006, 0.022]} radius={0.002} smoothness={3} position={[x * 0.54, -height / 2 + 0.003, z * 0.54]} castShadow receiveShadow>
            <meshStandardMaterial color="#283237" metalness={0.05} roughness={0.9} />
          </RoundedBox>
        </group>
      ))}
      <RoundedBox args={[0.068, 0.026, 0.084]} radius={0.009} smoothness={4} castShadow receiveShadow>
        <meshStandardMaterial color="#39454a" metalness={0.17} roughness={0.74} />
      </RoundedBox>
      <RoundedBox args={[0.072, 0.01, 0.088]} radius={0.004} smoothness={4} position={[0, 0.011, 0]} castShadow receiveShadow>
        <meshStandardMaterial color="#d9ddda" metalness={0.13} roughness={0.66} />
      </RoundedBox>
      <RoundedBox args={[0.043, 0.007, 0.059]} radius={0.003} smoothness={3} position={[0, -0.0135, 0]} castShadow receiveShadow>
        <meshStandardMaterial color="#222d32" metalness={0.12} roughness={0.82} />
      </RoundedBox>
      {[-1, 1].map((side) => (
        <group key={side}>
          <mesh position={[side * 0.024, 0.0162, 0]}>
            <boxGeometry args={[0.0015, 0.0004, 0.042]} />
            <meshStandardMaterial color="#8d989b" metalness={0.35} roughness={0.68} />
          </mesh>
          {[-0.023, 0.023].map((z) => (
            <mesh key={z} position={[side * 0.015, 0.0163, z]}>
              <cylinderGeometry args={[0.0012, 0.0012, 0.0006, 12]} />
              <meshStandardMaterial color="#778386" metalness={0.6} roughness={0.46} />
            </mesh>
          ))}
        </group>
      ))}
      <mesh position={[0, 0.0164, -0.031]}>
        <boxGeometry args={[0.008, 0.0008, 0.005]} />
        <meshStandardMaterial color="#a99c75" metalness={0.4} roughness={0.65} />
      </mesh>
      <mesh position={[0, 0.02, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[0.0105, 0.013, 0.008, 24]} />
        <meshStandardMaterial color="#687579" metalness={0.52} roughness={0.46} />
      </mesh>
      <RoundedBox args={[0.015, 0.008, 0.015]} radius={0.001} smoothness={3} position={[0, height / 2 - 0.004, 0]} castShadow receiveShadow>
        <meshStandardMaterial color="#e0e2db" metalness={0.12} roughness={0.68} />
      </RoundedBox>
      <RotorAssembly spinning={rotorsSpinning} />
      <Photodiode platform="drone" />
    </group>
  )
}
