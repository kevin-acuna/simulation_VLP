import { Circle, Crosshair, Drone, Ruler } from 'lucide-react'
import { Choice, RangeField, Toggle } from './Controls'
import { createReceiver, DRONE_GEOMETRY, getPhotodiodePosition, getReceiverBounds, getReceiverGeometry, RECEIVER_ID } from '../model/receiver'
import type { ReceiverPlatform, TwinConfig, WorldPosition } from '../model/types'

interface ReceiverPanelProps {
  config: TwinConfig
  onUpdate: (update: (previous: TwinConfig) => TwinConfig) => void
}

function ReceiverDiagram({ platform }: { platform: ReceiverPlatform }) {
  const geometry = getReceiverGeometry(platform)
  const isDrone = platform === 'drone'
  // One physical scale per diagram keeps the 10 mm PD true to the platform footprint.
  const scale = (isDrone ? 96 : 80) / geometry.width
  const width = geometry.width * scale
  const depth = geometry.depth * scale
  const height = geometry.height * scale
  const pdWidth = geometry.pdWidth * scale
  const pdDepth = geometry.pdDepth * scale
  const pdThickness = geometry.pdThickness * scale
  const motorOffset = DRONE_GEOMETRY.motorOffset * scale
  const rotorRadius = DRONE_GEOMETRY.rotorRadius * scale
  const sideTop = 72 - height / 2
  const sideBottom = 72 + height / 2
  const footprint = isDrone
    ? `${geometry.width * 1000} by ${geometry.depth * 1000} mm quadrotor footprint including propellers`
    : `${geometry.width * 1000} mm diameter cylinder`

  return (
    <figure className="receiver-diagram">
      <svg viewBox="0 0 284 158" role="img" aria-label={`Receiver top and side views at zero yaw: ${footprint}, ${geometry.height * 1000} mm high, with a ${geometry.pdWidth * 1000} by ${geometry.pdDepth * 1000} mm photodiode centred on top.`}>
        <text x="64" y="13" textAnchor="middle" className="receiver-diagram-view">TOP</text>
        <text x="202" y="13" textAnchor="middle" className="receiver-diagram-view">SIDE</text>
        <path d={`M${64 - width / 2 - 5} 70H${64 + width / 2 + 5}M64 ${70 - depth / 2 - 5}V${70 + depth / 2 + 5}`} className="receiver-diagram-guide" />
        {isDrone ? (
          <>
            {([-1, 1] as const).flatMap((x) => ([-1, 1] as const).map((y) => (
              <g key={`${x},${y}`}>
                <path d={`M64 70L${64 + x * motorOffset} ${70 + y * motorOffset}`} className="receiver-diagram-arm" />
                <g transform={`translate(${64 + x * motorOffset} ${70 + y * motorOffset})`}>
                  <circle r={rotorRadius} className="receiver-diagram-rotor" />
                  <g transform={`rotate(${x * y * 35})`}>
                    <ellipse rx={rotorRadius * 0.92} ry={rotorRadius * 0.13} className="receiver-diagram-propeller" />
                  </g>
                  <circle r={2.3} className="receiver-diagram-body" />
                </g>
              </g>
            )))}
            <rect x={64 - width / 6} y={70 - depth / 6} width={width / 3} height={depth / 3} rx="5" className="receiver-diagram-body" />
          </>
        ) : <circle cx="64" cy="70" r={width / 2} className="receiver-diagram-body" />}
        <rect x={64 - pdWidth / 2} y={70 - pdDepth / 2} width={pdWidth} height={pdDepth} className="receiver-diagram-pd" />
        <path d={`M${64 + pdWidth / 2} 70H119`} className="receiver-diagram-dimension" />
        <text x="130" y="73" textAnchor="middle">PD</text>
        <path d={`M202 ${sideTop - 10}V${sideBottom + 10}M${202 - width / 2 - 5} 72H${202 + width / 2 + 5}`} className="receiver-diagram-guide" />
        {isDrone ? (
          <>
            <path d={`M${202 - motorOffset} ${sideTop + 4}L202 72L${202 + motorOffset} ${sideTop + 4}`} className="receiver-diagram-arm" />
            {([-1, 1] as const).map((x) => (
              <g key={x}>
                <rect x={202 + x * motorOffset - 3} y={sideTop + 1} width="6" height={height * 0.4} rx="1" className="receiver-diagram-body" />
                <path d={`M${202 + x * motorOffset - rotorRadius} ${sideTop + 1}H${202 + x * motorOffset + rotorRadius}`} className="receiver-diagram-propeller-edge" />
              </g>
            ))}
            <rect x={202 - width / 6} y={sideTop} width={width / 3} height={height} rx="3" className="receiver-diagram-body" />
          </>
        ) : <rect x={202 - width / 2} y={sideTop} width={width} height={height} className="receiver-diagram-body" />}
        <rect x={202 - pdWidth / 2} y={sideTop - pdThickness} width={pdWidth} height={pdThickness} className="receiver-diagram-pd" />
        <path d={`M${64 - width / 2} 120V130M${64 + width / 2} 120V130M${64 - width / 2} 125H${64 + width / 2}M254 ${sideTop}H264M254 ${sideBottom}H264M259 ${sideTop}V${sideBottom}`} className="receiver-diagram-dimension" />
        <text x="64" y="145" textAnchor="middle">{isDrone ? '' : 'Ø '}{geometry.width * 1000} mm</text>
        <text x="276" y="72" textAnchor="middle" transform="rotate(-90 276 72)">{geometry.height * 1000} mm</text>
      </svg>
      <figcaption>{isDrone ? 'Quadrotor with a centred, upward-facing photodiode.' : 'Rotating cylinder with a top-mounted photodiode.'} Views at 0° yaw.</figcaption>
      <div className="receiver-diagram-legend">
        <span><i className="receiver-legend-pd" aria-hidden="true" />Photodiode</span>
        {isDrone && <span><i className="receiver-legend-rotor" aria-hidden="true" />Propeller sweep</span>}
      </div>
    </figure>
  )
}

export default function ReceiverPanel({ config, onUpdate }: ReceiverPanelProps) {
  const { receiver, room } = config
  const isDrone = receiver.platform === 'drone'
  const bounds = getReceiverBounds(room, receiver.platform, receiver.yaw)
  const photodiodePosition = getPhotodiodePosition(receiver)
  const geometry = getReceiverGeometry(receiver.platform)
  const width = geometry.width * 1000
  const depth = geometry.depth * 1000
  const height = geometry.height * 1000
  const pdWidth = geometry.pdWidth * 1000
  const pdDepth = geometry.pdDepth * 1000

  function setPosition(axis: 0 | 1 | 2, value: number) {
    onUpdate((previous) => {
      const position: WorldPosition = [...previous.receiver.position]
      position[axis] = value
      return { ...previous, receiver: { ...previous.receiver, position } }
    })
  }

  return (
    <>
      <section className="control-section receiver-platform">
        <Choice<ReceiverPlatform> label="PD platform" value={receiver.platform} options={[
          { value: 'cylinder', label: 'Cylinder', icon: <Circle size={20} /> },
          { value: 'drone', label: 'Drone', icon: <Drone size={20} /> },
        ]} onChange={(platform) => onUpdate((previous) => ({ ...previous, receiver: { ...previous.receiver, platform } }))} />
        {isDrone && (
          <>
            <Toggle label="Spinning propellers" description="Visual flight effect only; precise pose controls remain available. No flight dynamics." checked={receiver.rotorsSpinning} onChange={(rotorsSpinning) => onUpdate((previous) => ({ ...previous, receiver: { ...previous.receiver, rotorsSpinning } }))} />
            <p className="helper">Propeller animation respects reduced-motion settings.</p>
          </>
        )}
      </section>
      <section className="control-section receiver-pose">
        <div className="section-title"><h3>Receiver pose</h3><span>{RECEIVER_ID}</span></div>
        <p className="section-description">Position is the body centre, relative to the floor centre. World coordinates in metres; Z points up.</p>
        <RangeField label="Receiver position · X" value={receiver.position[0]} min={bounds.x[0]} max={bounds.x[1]} step={0.01} digits={3} unit="m" onChange={(value) => setPosition(0, value)} />
        <RangeField label="Receiver position · Y" value={receiver.position[1]} min={bounds.y[0]} max={bounds.y[1]} step={0.01} digits={3} unit="m" onChange={(value) => setPosition(1, value)} />
        <RangeField label="Receiver position · Z" value={receiver.position[2]} min={bounds.z[0]} max={bounds.z[1]} step={0.01} digits={3} unit="m" onChange={(value) => setPosition(2, value)} />
        <RangeField label="Platform rotation · Z" value={receiver.yaw} min={0} max={359} step={1} digits={0} unit="°" onChange={(yaw) => onUpdate((previous) => ({ ...previous, receiver: { ...previous.receiver, yaw } }))} />
        <p className="helper">Drag {RECEIVER_ID} to move in X/Y. Double-click it for X/Y/Z controls. Centre receiver returns to Z = 0.30 m.</p>
        <button className="secondary-button receiver-centre" onClick={() => onUpdate((previous) => ({ ...previous, receiver: { ...previous.receiver, position: createReceiver(previous.room, previous.receiver.platform).position } }))}><Crosshair size={14} />Centre receiver</button>
      </section>
      <section className="control-section receiver-assembly">
        <div className="section-title"><h3>Receiver assembly</h3><span>FIXED GEOMETRY</span></div>
        <ReceiverDiagram platform={receiver.platform} />
        <dl className="receiver-specs">
          <div><dt>{isDrone ? 'Platform footprint · 0°' : 'Platform diameter'}</dt><dd>{isDrone ? `${width} × ${depth}` : width} mm</dd></div>
          <div><dt>Platform height</dt><dd>{height} mm</dd></div>
          <div><dt>Photodiode</dt><dd>{pdWidth} × {pdDepth} mm</dd></div>
        </dl>
        <div className="receiver-pd-position">
          <div className="section-title"><h3>Photodiode centre</h3><span>WORLD · m</span></div>
          <dl className="receiver-pd-coordinates">
            {(['X', 'Y', 'Z'] as const).map((axis, index) => <div key={axis}><dt>{axis}</dt><dd>{photodiodePosition[index].toFixed(3)}</dd></div>)}
          </dl>
        </div>
      </section>
      <div className="info-card"><Ruler size={17} /><p><strong>Physical scale, visual prototype</strong>The assembly is modelled at its real dimensions. Photodiode response and channel physics are not simulated.</p></div>
    </>
  )
}
