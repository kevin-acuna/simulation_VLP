import { Suspense, useState } from 'react'
import { Canvas } from '@react-three/fiber'
import { ACESFilmicToneMapping, PCFSoftShadowMap, SRGBColorSpace } from 'three'
import type { SceneProps } from '../model/types'
import { getTheme } from '../theme/themes'
import CameraRig from './CameraRig'
import Led from './Led'
import Room from './Room'
import Receiver from './Receiver'
import { RECEIVER_ID } from '../model/receiver'
import SceneGuides from './SceneGuides'
import SceneLighting from './SceneLighting'

export default function TestbedScene({ config, fixtures, selectedId, onSelect, onReceiverPreview, onReceiverCommit, view, cameraReset, framing }: SceneProps) {
  const [dragging, setDragging] = useState(false)
  const { accent, muted } = getTheme(config.appearance.theme).colors
  const interior = view === 'perspective'

  return (
    <Canvas
      className="testbed-canvas"
      style={{ width: '100%', height: '100%', background: 'transparent', touchAction: 'none' }}
      orthographic
      camera={{ position: [7, 6, 7], zoom: 110, near: 0.01, far: 100 }}
      dpr={[1, 1.75]}
      frameloop="demand"
      shadows={{ type: PCFSoftShadowMap }}
      gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }}
      onCreated={({ gl }) => {
        gl.setClearColor('#000000', 0)
        gl.toneMapping = ACESFilmicToneMapping
        gl.toneMappingExposure = 1.05
        gl.outputColorSpace = SRGBColorSpace
      }}
      onPointerMissed={() => { if (!dragging) onSelect(null) }}
      fallback={<div className="scene-fallback" role="status">This 3D testbed requires a browser with WebGL enabled. Your room settings remain available in the control panel.</div>}
    >
      <Suspense fallback={null}>
        <Room room={config.room} ceiling={config.display.ceiling} guideColor={muted} interior={interior} />
        {fixtures.map((fixture, index) => (
          <Led
            key={fixture.id}
            fixture={fixture}
            selected={fixture.id === selectedId}
            onSelect={onSelect}
            labels={config.display.labels}
            beams={config.display.beams}
            castShadow={index < 4}
            accent={accent}
            guideColor={muted}
            interior={interior}
          />
        ))}
        <SceneGuides room={config.room} display={{ ...config.display, dimensions: !interior && config.display.dimensions }} accent={accent} guideColor={muted} />
        <SceneLighting room={config.room} interior={interior} />
        <Receiver receiver={config.receiver} room={config.room} selected={selectedId === RECEIVER_ID} view={view} cameraReset={cameraReset} accent={accent} guideColor={muted} onSelect={(inspect) => onSelect(RECEIVER_ID, inspect)} onPreview={onReceiverPreview} onCommit={onReceiverCommit} onDragChange={setDragging} />
        <CameraRig room={config.room} view={view} cameraReset={cameraReset} dimensions={config.display.dimensions} framing={framing} enabled={!dragging} />
      </Suspense>
    </Canvas>
  )
}
