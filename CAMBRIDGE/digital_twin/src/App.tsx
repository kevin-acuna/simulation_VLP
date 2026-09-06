import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Box, Camera, Grid2X2, Maximize, RotateCcw, Ruler, Square, Layers3, SlidersHorizontal } from 'lucide-react'
import type { CSSProperties } from 'react'
import { getFixtures } from './model/config'
import { getThemeVariables } from './theme/themes'
import { useTwinConfig } from './state/useTwinConfig'
import ControlPanel from './components/ControlPanel'
import SceneBoundary from './components/SceneBoundary'
import type { PanelTab } from './components/ControlPanel'
import type { CameraFraming, CameraView } from './model/types'

const TestbedScene = lazy(() => import('./scene/TestbedScene'))

export default function App() {
  const { config, updateConfig, saved, resetConfig } = useTwinConfig()
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [tab, setTab] = useState<PanelTab>('room')
  const [view, setView] = useState<CameraView>('isometric')
  const [cameraReset, setCameraReset] = useState(0)
  const [framing, setFraming] = useState<CameraFraming>('immersive')
  const [exported, setExported] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const settingsButton = useRef<HTMLButtonElement>(null)
  const fixtures = useMemo(() => getFixtures(config), [config])
  const activeId = fixtures.some((fixture) => fixture.id === selectedId) ? selectedId : null
  const closeSettings = useCallback(() => {
    setSettingsOpen(false)
    settingsButton.current?.focus({ preventScroll: true })
  }, [])

  useEffect(() => {
    if (!settingsOpen) return
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') closeSettings()
    }
    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [settingsOpen, closeSettings])

  function selectLed(id: string | null) {
    setSelectedId(id)
    if (id) {
      setTab('lighting')
      setSettingsOpen(true)
    }
  }
  function resetCamera(nextView: CameraView = view, nextFraming: CameraFraming = nextView === 'isometric' || nextView === 'perspective' ? 'immersive' : 'fit') {
    setView(nextView)
    setFraming(nextFraming)
    setCameraReset((previous) => previous + 1)
  }
  function exportScene() {
    const blob = new Blob([JSON.stringify({ schemaVersion: 1, coordinateSystem: 'right-handed, Z-up, metres', config }, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'cambridge-testbed.json'
    link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
    setExported(true)
    window.setTimeout(() => setExported(false), 2200)
  }
  function resetScene() {
    resetConfig()
    setSelectedId(null)
    resetCamera('isometric')
  }

  return (
    <div className="app-shell" data-theme={config.appearance.theme} style={getThemeVariables(config.appearance.theme) as CSSProperties}>
      <main className="main-layout">
        <section className="workspace" aria-label="Interactive 3D testbed">
          <div className="scene-viewport" data-testid="scene-viewport">
            <SceneBoundary><Suspense fallback={<div className="scene-loading"><Box size={28} /><span>Building your environment…</span></div>}><TestbedScene config={config} fixtures={fixtures} selectedId={activeId} onSelect={selectLed} view={view} cameraReset={cameraReset} framing={framing} /></Suspense></SceneBoundary>
          </div>
          <button ref={settingsButton} className={`settings-toggle${settingsOpen ? ' active' : ''}`} aria-label={settingsOpen ? 'Close settings' : 'Open settings'} title={settingsOpen ? 'Close settings' : 'Scene settings'} aria-expanded={settingsOpen} aria-controls="scene-settings" onClick={() => settingsOpen ? closeSettings() : setSettingsOpen(true)}><SlidersHorizontal size={19} /></button>
          <div className="workspace-bottom">
            <div className="viewport-toolbar" role="toolbar" aria-label="Camera and display controls">
              <div className="view-buttons">
                <button className={view === 'perspective' ? 'active' : ''} onClick={() => resetCamera('perspective')} title="Perspective · interior view" aria-label="Perspective view" aria-pressed={view === 'perspective'}><Camera size={17} /><span>Perspective</span></button>
                <button className={view === 'isometric' ? 'active' : ''} onClick={() => resetCamera('isometric')} title="Isometric view" aria-label="Isometric view" aria-pressed={view === 'isometric'}><Box size={17} /><span>Isometric</span></button>
                <button className={view === 'top' ? 'active' : ''} onClick={() => resetCamera('top')} title="Top view" aria-label="Top view" aria-pressed={view === 'top'}><Layers3 size={17} /></button>
                <button className={view === 'front' ? 'active' : ''} onClick={() => resetCamera('front')} title="Front view" aria-label="Front view" aria-pressed={view === 'front'}><Square size={16} /></button>
              </div>
              <span className="toolbar-divider" />
              <button aria-label="Toggle floor grid" title="Toggle floor grid" aria-pressed={config.display.grid} className={config.display.grid ? 'active' : ''} onClick={() => updateConfig((previous) => ({ ...previous, display: { ...previous.display, grid: !previous.display.grid } }))}><Grid2X2 size={17} /></button>
              <button aria-label="Toggle dimensions" title={view === 'perspective' ? 'Dimension guides are available in exterior views' : 'Toggle dimensions'} disabled={view === 'perspective'} aria-pressed={view !== 'perspective' && config.display.dimensions} className={view !== 'perspective' && config.display.dimensions ? 'active' : ''} onClick={() => updateConfig((previous) => ({ ...previous, display: { ...previous.display, dimensions: !previous.display.dimensions } }))}><Ruler size={17} /></button>
              <span className="toolbar-divider" />
              <button onClick={() => resetCamera(view, 'fit')} aria-label="Fit room to view" title="Fit room to view"><Maximize size={17} /></button>
              <button onClick={() => resetCamera(view)} aria-label="Reset camera" title="Reset current view"><RotateCcw size={16} /></button>
            </div>
          </div>
          {settingsOpen && <ControlPanel config={config} fixtures={fixtures} selectedId={activeId} tab={tab} onTab={setTab} onSelect={selectLed} onUpdate={updateConfig} onReset={resetScene} onClose={closeSettings} onExport={exportScene} exported={exported} saved={saved} interior={view === 'perspective'} />}
        </section>
      </main>
    </div>
  )
}
