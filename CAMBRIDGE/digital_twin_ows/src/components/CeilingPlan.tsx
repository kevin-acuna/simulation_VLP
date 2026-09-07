import type { LedFixture, RoomConfig } from '../model/types'

export default function CeilingPlan({ room, fixtures, selectedId, onSelect }: {
  room: RoomConfig
  fixtures: LedFixture[]
  selectedId: string | null
  onSelect: (id: string) => void
}) {
  return (
    <div className="ceiling-plan-section">
      <div className="section-title"><h3>Ceiling plan</h3><span>TOP VIEW</span></div>
      <div className="plan-wrap">
        <div className="ceiling-plan" style={{ aspectRatio: `${room.width} / ${room.depth}`, width: `${Math.min(182, 156 * room.width / room.depth)}px` }}>
          <div className="plan-cross horizontal" /><div className="plan-cross vertical" />
          <span className="plan-origin">0</span>
          {fixtures.map((led) => (
            <button
              key={led.id}
              title={`Select ${led.id}`}
              aria-label={`Select ${led.id} in ceiling plan`}
              aria-pressed={selectedId === led.id}
              className={`plan-led ${led.shape} ${selectedId === led.id ? 'selected' : ''}`}
              style={{ left: `${(led.position[0] / room.width + 0.5) * 100}%`, top: `${(0.5 - led.position[1] / room.depth) * 100}%` }}
              onClick={() => onSelect(led.id)}
            ><span>{led.id.slice(-2)}</span></button>
          ))}
        </div>
        <span className="plan-width">{room.width.toFixed(1)} m</span>
      </div>
      <p className="helper">Select an emitter to adjust its position.</p>
    </div>
  )
}
