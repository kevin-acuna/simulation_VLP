import { useEffect, useRef } from 'react'
import { Circle, Grid2X2, Rows3, Square, Box, Lightbulb, ScanEye, X, RotateCcw, Check, Download } from 'lucide-react'
import { Choice, RangeField, Stepper, Toggle } from './Controls'
import CeilingPlan from './CeilingPlan'
import ThemePicker from './ThemePicker'
import { getTotalPower } from '../model/config'
import type { DisplayConfig, LedFixture, LightingConfig, RoomConfig, TwinConfig } from '../model/types'

export type PanelTab = 'room' | 'lighting' | 'view'

interface ControlPanelProps {
  config: TwinConfig
  fixtures: LedFixture[]
  selectedId: string | null
  tab: PanelTab
  onTab: (tab: PanelTab) => void
  onSelect: (id: string | null) => void
  onUpdate: (update: (previous: TwinConfig) => TwinConfig) => void
  onReset: () => void
  onClose: () => void
  onExport: () => void
  exported: boolean
  saved: boolean
  interior: boolean
}

export default function ControlPanel({ config, fixtures, selectedId, tab, onTab, onSelect, onUpdate, onReset, onClose, onExport, exported, saved, interior }: ControlPanelProps) {
  const { room, lighting, display } = config
  const selected = fixtures.find((led) => led.id === selectedId)
  const closeButton = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    closeButton.current?.focus({ preventScroll: true })
  }, [])

  function setRoom(key: keyof RoomConfig, value: number) {
    onUpdate((previous) => ({ ...previous, room: { ...previous.room, [key]: value } }))
  }
  function setLighting<K extends keyof LightingConfig>(key: K, value: LightingConfig[K]) {
    onUpdate((previous) => ({ ...previous, lighting: { ...previous.lighting, [key]: value }, positions: ['count', 'layout', 'spacing'].includes(key) ? {} : previous.positions }))
  }
  function setDisplay(key: keyof DisplayConfig, value: boolean) {
    onUpdate((previous) => ({ ...previous, display: { ...previous.display, [key]: value } }))
  }
  function setPosition(axis: 0 | 1, value: number) {
    if (!selected) return
    const position: [number, number] = [selected.position[0], selected.position[1]]
    position[axis] = value
    onUpdate((previous) => ({ ...previous, positions: { ...previous.positions, [selected.id]: position } }))
  }
  return (
    <aside id="scene-settings" className="control-panel" aria-label="Scene configuration">
      <div className="panel-heading"><div><span className="eyebrow">SETTINGS</span><h2>Scene configuration</h2></div><button ref={closeButton} className="icon-button panel-close" onClick={onClose} aria-label="Close configuration panel" title="Close settings (Esc)"><X size={18} /></button></div>
      <div className="panel-tabs" role="tablist" aria-label="Configuration sections">
        {([{ id: 'room', icon: Box, label: 'Room' }, { id: 'lighting', icon: Lightbulb, label: 'Lighting' }, { id: 'view', icon: ScanEye, label: 'View' }] as const).map(({ id, icon: Icon, label }) => (
          <button key={id} id={`tab-${id}`} role="tab" aria-selected={tab === id} aria-controls={`panel-${id}`} className={tab === id ? 'active' : ''} onClick={() => onTab(id)}><Icon size={15} />{label}</button>
        ))}
      </div>
      <div className="scene-summary"><div className="summary-icon"><Lightbulb size={17} /></div><div><strong>{String(fixtures.length).padStart(2, '0')} emitters</strong><span>{lighting.layout === 'grid' ? 'Grid' : lighting.layout === 'ring' ? 'Ring' : 'Linear'} arrangement <span className="inline-dot">·</span> {lighting.shape === 'circular' ? 'Circular' : 'Square'}</span></div><div className="summary-divider" /><div><strong>{getTotalPower(config).toFixed(3)} <small>W</small></strong><span>Total optical power</span></div></div>
      <div className="panel-body" role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`}>
        {tab === 'room' && <>
          <section className="control-section">
            <div className="section-title"><h3>Room dimensions</h3><span>METRES</span></div>
            <p className="section-description">A clean space. Built around your testbed.</p>
            <RangeField label="Width · X" value={room.width} min={2} max={10} step={0.1} unit="m" onChange={(value) => setRoom('width', value)} />
            <RangeField label="Depth · Y" value={room.depth} min={2} max={10} step={0.1} unit="m" onChange={(value) => setRoom('depth', value)} />
            <RangeField label="Height · Z" value={room.height} min={1.8} max={5} step={0.1} unit="m" onChange={(value) => setRoom('height', value)} />
            <div className="room-metrics"><div><span>FLOOR AREA</span><strong>{(room.width * room.depth).toFixed(1)} <small>m²</small></strong></div><div><span>VOLUME</span><strong>{(room.width * room.depth * room.height).toFixed(1)} <small>m³</small></strong></div></div>
          </section>
          <CeilingPlan room={room} fixtures={fixtures} selectedId={selectedId} onSelect={onSelect} />
          <div className="info-card"><Box size={17} /><p><strong>{interior ? 'Interior perspective' : 'Cutaway view'}</strong>{interior ? 'An eye-level view with a solid ceiling. Drag to orbit and scroll to move closer.' : 'Near walls are hidden automatically as you orbit. The room remains fully defined.'}</p></div>
        </>}
        {tab === 'lighting' && <>
          <section className="control-section">
            <div className="section-title"><h3>Emitter arrangement</h3><span>CEILING</span></div>
            <Stepper value={lighting.count} onChange={(value) => setLighting('count', value)} />
            <Choice label="Layout" value={lighting.layout} options={[{ value: 'grid', label: 'Grid', icon: <Grid2X2 size={19} /> }, { value: 'ring', label: 'Ring', icon: <Circle size={19} /> }, { value: 'line', label: 'Line', icon: <Rows3 size={19} /> }]} onChange={(value) => setLighting('layout', value)} />
            <Choice label="Luminaire shape" value={lighting.shape} options={[{ value: 'circular', label: 'Circular', icon: <Circle size={19} /> }, { value: 'square', label: 'Square', icon: <Square size={19} /> }]} onChange={(value) => setLighting('shape', value)} />
            <RangeField label="Layout spacing" value={lighting.spacing} min={0.2} max={0.8} step={0.05} digits={2} onChange={(value) => setLighting('spacing', value)} />
            <p className="helper">Count, layout and spacing changes reset custom positions.</p>
          </section>
          <section className="control-section">
            <div className="section-title"><h3>Light properties</h3><span>ALL EMITTERS</span></div>
            <RangeField label="Optical power / LED" value={lighting.power} min={0} max={2} step={0.005} digits={3} unit="W" onChange={(value) => setLighting('power', value)} />
            <RangeField label="Colour temperature" value={lighting.temperature} min={2700} max={6500} step={100} digits={0} unit="K" onChange={(value) => setLighting('temperature', value)} />
            <div className="temperature-spectrum"><span>Warm</span><span>Cool</span></div>
          </section>
          {selected ? <section className="control-section selected-section">
            <div className="section-title"><h3><span className="status-dot" />{selected.id}</h3><button className="icon-button" aria-label="Deselect LED" onClick={() => onSelect(null)}><X size={15} /></button></div>
            <p className="section-description">Position relative to the floor centre.</p>
            <RangeField label="LED position · X" value={selected.position[0]} min={-room.width / 2 + 0.22} max={room.width / 2 - 0.22} step={0.01} digits={2} unit="m" onChange={(value) => setPosition(0, value)} />
            <RangeField label="LED position · Y" value={selected.position[1]} min={-room.depth / 2 + 0.22} max={room.depth / 2 - 0.22} step={0.01} digits={2} unit="m" onChange={(value) => setPosition(1, value)} />
            <div className="ceiling-height"><span>Ceiling attachment · Z</span><strong>{room.height.toFixed(2)} m</strong></div>
            <button className="text-button" onClick={() => onUpdate((previous) => ({ ...previous, positions: Object.fromEntries(Object.entries(previous.positions).filter(([id]) => id !== selected.id)) }))}><RotateCcw size={12} />Reset this position</button>
          </section> : <CeilingPlan room={room} fixtures={fixtures} selectedId={selectedId} onSelect={onSelect} />}
        </>}
        {tab === 'view' && <>
          <ThemePicker value={config.appearance.theme} onChange={(theme) => onUpdate((previous) => ({ ...previous, appearance: { ...previous.appearance, theme } }))} />
          <section className="control-section">
            <div className="section-title"><h3>Scene overlays</h3><span>DISPLAY</span></div>
            <Toggle label="Dimension guides" description={interior ? 'Available in exterior views' : 'Room measurements in metres'} checked={!interior && display.dimensions} disabled={interior} onChange={(value) => setDisplay('dimensions', value)} />
            <Toggle label="LED labels" description="Clickable emitter identifiers" checked={display.labels} onChange={(value) => setDisplay('labels', value)} />
            <Toggle label="Floor grid" description="Spatial reference on the floor" checked={display.grid} onChange={(value) => setDisplay('grid', value)} />
            <Toggle label="Emission guides" description="Schematic, not a calibrated beam" checked={display.beams} onChange={(value) => setDisplay('beams', value)} />
            <Toggle label="Ghost ceiling" description={interior ? 'Perspective uses a solid ceiling' : 'Show the translucent ceiling plane'} checked={!interior && display.ceiling} disabled={interior} onChange={(value) => setDisplay('ceiling', value)} />
          </section>
          <section className="control-section"><div className="section-title"><h3>Navigation</h3></div><div className="shortcut"><span>Orbit the room</span><kbd>Drag</kbd></div><div className="shortcut"><span>Zoom in / out</span><kbd>Scroll</kbd></div><div className="shortcut"><span>Pan the view</span><kbd>Right drag</kbd></div><div className="shortcut"><span>Select an LED</span><kbd>Click</kbd></div></section>
          <div className="info-card"><ScanEye size={17} /><p><strong>Visualisation, not measurement</strong>Rendered brightness is illustrative. Optical power is stored in watts for the future channel model.</p></div>
          <button className="reset-button" onClick={onReset}><RotateCcw size={14} />Restore default scene</button>
        </>}
      </div>
      <div className="panel-actions"><span className="save-status"><span className={saved ? 'status-dot' : 'status-dot unsaved'} />{saved ? 'Saved locally' : 'Session only'}</span><button className="export-button" onClick={onExport}>{exported ? <Check size={15} /> : <Download size={15} />}{exported ? 'Exported' : 'Export scene'}</button></div>
    </aside>
  )
}
