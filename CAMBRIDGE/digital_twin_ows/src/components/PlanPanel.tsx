import { X } from 'lucide-react'
import type { LedFixture, ReceiverConfig, RoomConfig, WorldPosition } from '../model/types'
import { channelStyle } from './chartSeries'

export interface PlanPanelProps {
  room: RoomConfig
  fixtures: LedFixture[]
  receiver: ReceiverConfig
  path: readonly WorldPosition[]
  onClose: () => void
  estimatedPositions?: readonly { id: string; position: WorldPosition; label?: string }[]
}

const PLAN = { width: 432, height: 222, left: 44, right: 20, top: 18, bottom: 36 }

function formatMetres(value: number): string {
  return Number(value.toFixed(2)).toString()
}

export default function PlanPanel({ room, fixtures, receiver, path, onClose, estimatedPositions = [] }: PlanPanelProps) {
  const plotWidth = PLAN.width - PLAN.left - PLAN.right
  const plotHeight = PLAN.height - PLAN.top - PLAN.bottom
  const scale = Math.min(plotWidth / room.width, plotHeight / room.depth)
  const centreX = PLAN.left + plotWidth / 2
  const centreY = PLAN.top + plotHeight / 2
  const x = (value: number) => centreX + value * scale
  const y = (value: number) => centreY - value * scale
  const left = x(-room.width / 2)
  const right = x(room.width / 2)
  const top = y(room.depth / 2)
  const bottom = y(-room.depth / 2)
  const ticks = [-0.5, -0.25, 0, 0.25, 0.5]
  const rxX = x(receiver.position[0])
  const rxY = y(receiver.position[1])
  const hasRoute = path.length > 1

  return (
    <aside id="xy-plan" className="plan-panel" aria-label="X-Y plan" onKeyDown={(event) => { if (event.key === 'Escape') { event.stopPropagation(); onClose() } }}>
      <div className="plan-heading">
        <h2>X-Y plan</h2>
        <button className="icon-button plan-close" aria-label="Close X-Y plan" title="Close X-Y plan" onClick={onClose}><X size={17} /></button>
      </div>
      <figure className="plan-figure">
        <svg className="plan-chart-svg" viewBox={`0 0 ${PLAN.width} ${PLAN.height}`} preserveAspectRatio="xMidYMid meet" role="img" aria-label="X-Y position map">
          <title>X-Y position map</title>
          <rect className="plan-room" x={left} y={top} width={room.width * scale} height={room.depth * scale} />
          {ticks.map((fraction) => {
            const worldX = fraction * room.width
            const worldY = fraction * room.depth
            const labelled = fraction === -0.5 || fraction === 0 || fraction === 0.5
            return <g key={fraction}>
              {Math.abs(fraction) < 0.5 && <>
                <line className={fraction === 0 ? 'plan-axis' : 'plan-gridline'} x1={x(worldX)} x2={x(worldX)} y1={top} y2={bottom} />
                <line className={fraction === 0 ? 'plan-axis' : 'plan-gridline'} x1={left} x2={right} y1={y(worldY)} y2={y(worldY)} />
              </>}
              {labelled && <>
                <line className="plan-tick-mark" x1={x(worldX)} x2={x(worldX)} y1={bottom} y2={bottom + 4} />
                <text className="plan-tick" x={x(worldX)} y={bottom + 15} textAnchor="middle">{formatMetres(worldX)}</text>
                <line className="plan-tick-mark" x1={left - 4} x2={left} y1={y(worldY)} y2={y(worldY)} />
                <text className="plan-tick" x={left - 8} y={y(worldY) + 3} textAnchor="end">{formatMetres(worldY)}</text>
              </>}
            </g>
          })}
          <text className="plan-axis-label" x={centreX} y={bottom + 30} textAnchor="middle">X (m)</text>
          <text className="plan-axis-label" transform={`translate(${left - 33} ${centreY}) rotate(-90)`} textAnchor="middle">Y (m)</text>
          {hasRoute && <path className="plan-route" aria-label="Planned route" d={path.map((position, index) => `${index === 0 ? 'M' : 'L'}${x(position[0])} ${y(position[1])}`).join(' ')} />}
          {fixtures.map((fixture) => {
            const [worldX, worldY, worldZ] = fixture.position
            return <g key={fixture.id} className="plan-led-marker" style={channelStyle(fixture.id)} data-led-id={fixture.id} data-world-x={worldX} data-world-y={worldY} data-world-z={worldZ} role="img" aria-label={`${fixture.id} ground truth`}>
              <title>{fixture.id}: X {formatMetres(worldX)} m, Y {formatMetres(worldY)} m</title>
              {fixture.shape === 'square'
                ? <rect className="plan-led-point" x={x(worldX) - 3.5} y={y(worldY) - 3.5} width={7} height={7} rx={1} />
                : <circle className="plan-led-point" cx={x(worldX)} cy={y(worldY)} r={4} />}
              <text className="plan-marker-label" x={x(worldX) + (worldX > 0 ? -9 : 9)} y={y(worldY) - 7} textAnchor={worldX > 0 ? 'end' : 'start'}>{fixture.id}</text>
            </g>
          })}
          {estimatedPositions.map(({ id, position, label }) => <g key={id} className="plan-estimate-marker" style={channelStyle(id)} data-estimate-id={id} data-world-x={position[0]} data-world-y={position[1]} data-world-z={position[2]} role="img" aria-label={`Estimated ${label ?? id}`}>
            <title>Estimated {label ?? id}: X {formatMetres(position[0])} m, Y {formatMetres(position[1])} m</title>
            <path className="plan-estimate-point" d={`M${x(position[0]) - 4} ${y(position[1]) - 4}l8 8m0 -8l-8 8`} />
            <text className="plan-marker-label" x={x(position[0]) + 9} y={y(position[1]) - 7}>{label ?? id}</text>
          </g>)}
          <g className="plan-receiver-marker" data-world-x={receiver.position[0]} data-world-y={receiver.position[1]} data-world-z={receiver.position[2]} role="img" aria-label="RX ground truth">
            <title>RX centre: X {formatMetres(receiver.position[0])} m, Y {formatMetres(receiver.position[1])} m, Z {formatMetres(receiver.position[2])} m</title>
            <path className="plan-receiver-point" d={`M${rxX} ${rxY - 6}l6 6l-6 6l-6 -6Z`} />
            <text className="plan-marker-label plan-rx-label" x={rxX + (receiver.position[0] > 0 ? -11 : 11)} y={rxY + 13} textAnchor={receiver.position[0] > 0 ? 'end' : 'start'}>RX</text>
          </g>
        </svg>
        <figcaption className="plan-caption">
          <span>Ground truth</span>
          {hasRoute && <span className="plan-route-key"><i aria-hidden="true" />Planned route</span>}
          <output aria-label="Receiver centre Z">RX z = {receiver.position[2].toFixed(2)} m</output>
        </figcaption>
        {estimatedPositions.length > 0 && <ul className="plan-estimate-legend" aria-label="Estimated positions">
          {estimatedPositions.map(({ id, label }) => <li key={id} style={channelStyle(id)}><span aria-hidden="true">×</span>Estimated {label ?? id}</li>)}
        </ul>}
      </figure>
    </aside>
  )
}
