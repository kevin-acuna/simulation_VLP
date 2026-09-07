import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'
import { THEMES } from '../src/theme/themes'

async function readConfig(page: Page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('cambridge-digital-twin:v1') ?? '{}'))
}

async function editNumber(page: Page, label: string, value: string) {
  const field = page.getByRole('spinbutton', { name: `${label} value`, exact: true })
  await field.fill(value)
  await field.press('Enter')
}

async function openSettings(page: Page) {
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await expect(page.getByRole('complementary', { name: 'Scene configuration' })).toBeVisible()
}

async function expectFullViewport(page: Page) {
  const size = page.viewportSize()!
  for (const locator of [page.getByTestId('scene-viewport'), page.locator('canvas')]) {
    const bounds = await locator.boundingBox()
    expect(bounds).not.toBeNull()
    expect(bounds!.x).toBeCloseTo(0)
    expect(bounds!.y).toBeCloseTo(0)
    expect(bounds!.width).toBeCloseTo(size.width)
    expect(bounds!.height).toBeCloseTo(size.height)
  }
  expect(await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight }))).toEqual(size)
}

for (const viewport of [{ width: 1440, height: 1000 }, { width: 390, height: 844 }, { width: 844, height: 390 }]) {
  test(`full-window scene with collapsible settings at ${viewport.width}x${viewport.height}`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport)
    await page.goto('/')
    await expect(page.locator('.led-tag')).toHaveCount(4)
    await expectFullViewport(page)
    await expect(page.getByRole('banner')).toHaveCount(0)
    await expect(page.getByRole('contentinfo')).toHaveCount(0)
    await expect(page.getByRole('complementary', { name: 'Scene configuration' })).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Export scene' })).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Open settings', exact: true })).toHaveAttribute('aria-expanded', 'false')
    await expect(page.getByRole('toolbar')).toBeInViewport()
    await expect(page.locator('.workspace-bottom')).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)')
    await expect(page.locator('.workspace-bottom')).toHaveCSS('pointer-events', 'none')
    await page.locator('canvas').evaluate((canvas) => canvas.setAttribute('data-original-canvas', 'true'))
    await page.screenshot({ path: testInfo.outputPath('full-window.png'), fullPage: true })
    const toggleBounds = (await page.getByRole('button', { name: 'Open settings', exact: true }).boundingBox())!
    expect(toggleBounds.x).toBeLessThanOrEqual(24)
    expect(toggleBounds.y).toBeLessThanOrEqual(24)
    await openSettings(page)
    await expectFullViewport(page)
    const panelBounds = (await page.getByRole('complementary').boundingBox())!
    expect(panelBounds.x).toBeLessThanOrEqual(72)
    expect(panelBounds.y).toBeLessThanOrEqual(24)
    if (viewport.width > 900) {
      expect(viewport.height - panelBounds.y - panelBounds.height).toBeCloseTo(panelBounds.y)
      expect(panelBounds.x).toBeGreaterThan(toggleBounds.x + toggleBounds.width)
    }
    await expect(page.getByRole('button', { name: 'Close settings', exact: true })).toHaveAttribute('aria-expanded', 'true')
    await expect(page.getByRole('complementary').getByRole('button', { name: 'Export scene' })).toBeInViewport()
    await editNumber(page, 'Width · X', '4.2')
    await page.getByRole('button', { name: 'Close configuration panel' }).click()
    await expect(page.getByRole('complementary')).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Open settings', exact: true })).toBeFocused()
    await expectFullViewport(page)
    await openSettings(page)
    await expect(page.getByRole('spinbutton', { name: 'Width · X value', exact: true })).toHaveValue('4.2')
    await page.keyboard.press('Escape')
    await expect(page.getByRole('complementary')).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Open settings', exact: true })).toBeFocused()
    await expect(page.locator('canvas')).toHaveAttribute('data-original-canvas', 'true')
    await openSettings(page)
    await page.getByRole('button', { name: 'Close settings', exact: true }).click()
    await expect(page.getByRole('complementary')).toHaveCount(0)
    await page.reload()
    await expect(page.getByRole('complementary')).toHaveCount(0)
    await expect(page.getByRole('button', { name: 'Open settings', exact: true })).toBeVisible()
  })
}

async function perspectiveDepthRatio(page: Page) {
  return page.locator('.led-tag').evaluateAll((labels) => {
    const centers = new Map(labels.map((label) => {
      const rect = label.getBoundingClientRect()
      return [label.textContent?.trim(), rect.x + rect.width / 2]
    }))
    return Math.abs(centers.get('LED-02')! - centers.get('LED-01')!) / Math.abs(centers.get('LED-04')! - centers.get('LED-03')!)
  })
}

test('perspective view has real depth, interior navigation and restores orthographic cameras', async ({ page }, testInfo) => {
  test.setTimeout(90000)
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  const initialConfig = await readConfig(page)
  await expect.poll(() => perspectiveDepthRatio(page)).toBeCloseTo(1, 2)
  await page.locator('canvas').evaluate((canvas) => canvas.setAttribute('data-original-canvas', 'true'))
  await page.getByRole('button', { name: 'Perspective view', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Perspective view', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await expect.poll(() => perspectiveDepthRatio(page)).toBeGreaterThan(1.15)
  for (const label of await page.locator('.led-tag').all()) await expect(label).toBeInViewport()
  await expect(page.getByRole('button', { name: 'Toggle dimensions' })).toBeDisabled()
  await expect(page.locator('.dimension-label')).toHaveCount(0)
  await expectFullViewport(page)
  const entryRatio = await perspectiveDepthRatio(page)
  await page.screenshot({ path: testInfo.outputPath('perspective-interior.png'), fullPage: true })
  await page.getByRole('button', { name: 'Select LED-04, 0.405 optical watts', exact: true }).click()
  await expect(page.getByRole('tab', { name: 'Lighting' })).toHaveAttribute('aria-selected', 'true')
  await page.getByRole('tab', { name: 'View', exact: true }).click()
  await expect(page.getByRole('switch', { name: 'Ghost ceiling' })).toBeDisabled()
  await expect(page.getByRole('switch', { name: 'Dimension guides' })).toBeDisabled()
  await page.getByRole('button', { name: 'Mist palette', exact: true }).click()
  await expect.poll(async () => Math.abs(await perspectiveDepthRatio(page) - entryRatio)).toBeLessThan(0.03)
  await page.getByRole('button', { name: 'Chalk palette', exact: true }).click()
  await expect.poll(async () => Math.abs(await perspectiveDepthRatio(page) - entryRatio)).toBeLessThan(0.03)
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  const beforeOrbit = await page.locator('.led-tag').last().boundingBox()
  await page.mouse.move(950, 650)
  await page.mouse.down()
  await page.mouse.move(1010, 630, { steps: 8 })
  await page.mouse.up()
  await expect.poll(async () => {
    const after = (await page.locator('.led-tag').last().boundingBox())!
    return Math.hypot(after.x - beforeOrbit!.x, after.y - beforeOrbit!.y)
  }).toBeGreaterThan(4)
  await page.getByRole('button', { name: 'Reset camera', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Perspective view', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await expect.poll(async () => Math.abs(await perspectiveDepthRatio(page) - entryRatio)).toBeLessThan(0.03)
  await page.mouse.move(950, 650)
  await page.mouse.wheel(0, -160)
  await expect.poll(() => perspectiveDepthRatio(page)).toBeGreaterThan(entryRatio + 0.02)
  const beforePan = (await page.locator('.led-tag').last().boundingBox())!
  await page.mouse.down({ button: 'right' })
  await page.mouse.move(920, 660, { steps: 6 })
  await page.mouse.up({ button: 'right' })
  await expect.poll(async () => {
    const after = (await page.locator('.led-tag').last().boundingBox())!
    return Math.hypot(after.x - beforePan.x, after.y - beforePan.y)
  }).toBeGreaterThan(4)
  await page.getByRole('button', { name: 'Reset camera', exact: true }).click()
  await expect.poll(async () => Math.abs(await perspectiveDepthRatio(page) - entryRatio)).toBeLessThan(0.03)
  await page.getByRole('button', { name: 'Fit room to view', exact: true }).click()
  await expect.poll(() => perspectiveDepthRatio(page)).toBeGreaterThan(1)
  await page.getByRole('button', { name: 'Reset camera', exact: true }).click()
  await expect.poll(async () => Math.abs(await perspectiveDepthRatio(page) - entryRatio)).toBeLessThan(0.03)
  for (const name of ['Isometric view', 'Top view', 'Front view', 'Isometric view']) {
    await page.getByRole('button', { name, exact: true }).click()
    await expect(page.getByRole('button', { name, exact: true })).toHaveAttribute('aria-pressed', 'true')
    await expect.poll(() => perspectiveDepthRatio(page)).toBeCloseTo(1, 2)
    await expect(page.locator('.dimension-label')).toHaveCount(3)
    await page.getByRole('button', { name: 'Perspective view', exact: true }).click()
    await expect.poll(() => perspectiveDepthRatio(page)).toBeGreaterThan(1.15)
  }
  expect(await readConfig(page)).toEqual(initialConfig)
  await expect(page.locator('canvas')).toHaveAttribute('data-original-canvas', 'true')
  expect(errors).toEqual([])
})

test('perspective view remains usable on narrow screens and after room edits', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await page.getByRole('button', { name: 'Perspective view', exact: true }).click()
  await expect.poll(() => perspectiveDepthRatio(page)).toBeGreaterThan(1.05)
  await expectFullViewport(page)
  await expect(page.getByRole('toolbar')).toBeInViewport()
  await openSettings(page)
  await editNumber(page, 'Width · X', '8')
  await editNumber(page, 'Depth · Y', '2')
  await editNumber(page, 'Height · Z', '5')
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  await expect(page.getByRole('button', { name: 'Perspective view', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await expectFullViewport(page)
  await page.setViewportSize({ width: 1024, height: 526 })
  await page.getByRole('button', { name: 'Fit room to view', exact: true }).click()
  await expectFullViewport(page)
  await page.getByRole('button', { name: 'Isometric view', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Toggle dimensions' })).toBeEnabled()
  expect(errors).toEqual([])
})

test('starts close to the room with Chalk and retains a separate full-room fit', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1024, height: 526 })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'chalk')
  const spread = () => page.locator('.led-tag').evaluateAll((labels) => {
    const centers = labels.map((label) => {
      const rect = label.getBoundingClientRect()
      return rect.x + rect.width / 2
    })
    return Math.max(...centers) - Math.min(...centers)
  })
  await expect.poll(spread).toBeGreaterThan(200)
  const initialSpread = await spread()
  await page.screenshot({ path: testInfo.outputPath('immersive-room.png'), fullPage: true })
  await page.getByRole('button', { name: 'Fit room to view', exact: true }).click()
  await expect.poll(spread).toBeLessThan(initialSpread / 1.4)
  const fittedSpread = await spread()
  await page.getByRole('button', { name: 'Reset camera', exact: true }).click()
  await expect.poll(async () => Math.abs(await spread() - initialSpread)).toBeLessThan(1)
  await page.getByRole('button', { name: 'Fit room to view', exact: true }).click()
  await expect.poll(async () => Math.abs(await spread() - fittedSpread)).toBeLessThan(1)
  await page.getByRole('button', { name: 'Isometric view', exact: true }).click()
  await expect.poll(async () => Math.abs(await spread() - initialSpread)).toBeLessThan(1)
  await page.reload()
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await expect.poll(async () => Math.abs(await spread() - initialSpread)).toBeLessThan(1)
  await openSettings(page)
  await page.getByRole('tab', { name: 'View', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Chalk palette' })).toHaveAttribute('aria-pressed', 'true')
  await expect(page.getByRole('button', { name: 'Lavender palette' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Pure White palette' }).click()
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'white')
  for (const token of ['--bg-center', '--bg-mid', '--bg-edge']) {
    expect(await page.locator('.workspace').evaluate((element, key) => getComputedStyle(element).getPropertyValue(key).trim(), token)).toBe('#ffffff')
  }
  await page.reload()
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'white')
})

test('pastel palettes coordinate the scene UI and persist without changing the testbed', async ({ page }, testInfo) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  const initial = await readConfig(page)
  await page.locator('canvas').evaluate((canvas) => canvas.setAttribute('data-original-canvas', 'true'))
  await openSettings(page)
  await page.getByRole('tab', { name: 'View', exact: true }).click()
  const renderedPalettes: Record<string, string>[] = []
  for (const theme of THEMES) {
    const choice = page.getByRole('button', { name: `${theme.name} palette`, exact: true })
    await choice.click()
    await expect(choice).toHaveAttribute('aria-pressed', 'true')
    await expect(page.locator('.theme-option[aria-pressed="true"]')).toHaveCount(1)
    await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', theme.id)
    await expect(page.locator('.theme-current code')).toHaveText(theme.colors['bg-edge'].toUpperCase())
    const colors = await page.evaluate(() => {
      const background = (selector: string) => getComputedStyle(document.querySelector(selector)!).backgroundColor
      return {
        background: getComputedStyle(document.querySelector('.workspace')!).backgroundImage,
        labels: background('.led-tag'),
        dimensions: background('.dimension-label'),
        activeButton: background('.viewport-toolbar button.active'),
        panel: background('.control-panel'),
        inheritedAccent: getComputedStyle(document.querySelector('.led-tag')!).getPropertyValue('--accent').trim(),
      }
    })
    expect(colors.inheritedAccent).toBe(theme.colors.accent)
    renderedPalettes.push(colors)
    const current = await readConfig(page)
    expect(current.appearance.theme).toBe(theme.id)
    expect(current.room).toEqual(initial.room)
    expect(current.lighting).toEqual(initial.lighting)
    expect(current.positions).toEqual(initial.positions)
    expect(current.display).toEqual(initial.display)
    await expectFullViewport(page)
    await expect(page.locator('canvas')).toHaveAttribute('data-original-canvas', 'true')
  }
  for (const [key, token] of [['background', 'bg-mid'], ['labels', 'surface'], ['dimensions', 'bg-mid'], ['activeButton', 'accent-soft'], ['panel', 'surface']] as const) {
    const expectedColors = new Set(THEMES.map((theme) => theme.colors[token])).size
    expect(new Set(renderedPalettes.map((palette) => palette[key])).size).toBe(expectedColors)
  }
  await page.screenshot({ path: testInfo.outputPath('rose-palette.png'), fullPage: true })
  const downloadEvent = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export scene' }).click()
  const stream = await (await downloadEvent).createReadStream()
  let exported = ''
  for await (const chunk of stream!) exported += chunk.toString()
  expect(JSON.parse(exported).config.appearance.theme).toBe('rose')
  await page.reload()
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'rose')
  await expect(page.getByRole('complementary')).toHaveCount(0)
  await openSettings(page)
  await page.getByRole('tab', { name: 'View', exact: true }).click()
  const chalk = page.getByRole('button', { name: 'Chalk palette', exact: true })
  await chalk.focus()
  await page.keyboard.press('Space')
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'chalk')
  await page.getByRole('button', { name: 'Restore default scene' }).click()
  await expect(page.locator('.app-shell')).toHaveAttribute('data-theme', 'chalk')
  expect(errors).toEqual([])
})

test('renders the default room, four selectable LEDs and exports SI configuration', async ({ page }, testInfo) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  await page.goto('/')
  await expect(page.locator('canvas')).toBeVisible()
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await expect(page.getByRole('complementary', { name: 'Scene configuration' })).toHaveCount(0)
  await page.waitForTimeout(1800)
  await page.screenshot({ path: testInfo.outputPath('default-room.png'), fullPage: true })
  await page.locator('.led-tag').first().click()
  await expect(page.getByText('04 emitters')).toBeVisible()
  await expect(page.getByText('1.620')).toBeVisible()
  await expect(page.getByRole('tab', { name: 'Lighting' })).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('spinbutton', { name: 'LED position · X value', exact: true })).toBeVisible()
  const downloadEvent = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export scene' }).click()
  const download = await downloadEvent
  expect(download.suggestedFilename()).toBe('cambridge-testbed.json')
  const stream = await download.createReadStream()
  let text = ''
  for await (const chunk of stream!) text += chunk.toString()
  const exported = JSON.parse(text)
  expect(exported.schemaVersion).toBe(1)
  expect(exported.config.lighting.count).toBe(4)
  expect(exported.config.room).toEqual({ width: 3, depth: 3, height: 2 })
  expect(errors).toEqual([])
})

test('updates room, layouts, shape, count, positions and survives reload', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await openSettings(page)
  await editNumber(page, 'Width · X', '4.2')
  await editNumber(page, 'Depth · Y', '3.6')
  await editNumber(page, 'Height · Z', '2.8')
  await expect(page.getByText('15.1')).toBeVisible()
  await page.getByRole('tab', { name: 'Lighting' }).click()
  await page.getByRole('button', { name: 'Square', exact: true }).click()
  await page.getByRole('button', { name: 'Ring', exact: true }).click()
  for (let index = 4; index < 9; index += 1) await page.getByRole('button', { name: 'Add one LED' }).click()
  await expect(page.getByRole('button', { name: 'Add one LED' })).toBeDisabled()
  await expect(page.locator('.led-tag')).toHaveCount(9)
  await expect(page.getByText('09 emitters')).toBeVisible()
  await editNumber(page, 'Optical power / LED', '0')
  await expect(page.getByText('0.000', { exact: false }).first()).toBeVisible()
  await page.getByRole('button', { name: 'Select LED-01 in ceiling plan', exact: true }).click()
  await editNumber(page, 'LED position · X', '-1.2')
  await editNumber(page, 'LED position · Y', '1.1')
  const config = await readConfig(page)
  expect(config.room).toEqual({ width: 4.2, depth: 3.6, height: 2.8 })
  expect(config.lighting.shape).toBe('square')
  expect(config.lighting.layout).toBe('ring')
  expect(config.lighting.count).toBe(9)
  expect(config.lighting.power).toBe(0)
  expect(config.positions['LED-01'][0]).toBeCloseTo(-1.2)
  expect(config.positions['LED-01'][1]).toBeCloseTo(1.1)
  await page.reload()
  await openSettings(page)
  await expect(page.getByText('09 emitters')).toBeVisible()
  await expect(page.locator('.led-tag')).toHaveCount(9)
  expect((await readConfig(page)).positions['LED-01'][0]).toBeCloseTo(-1.2)
  await page.getByRole('tab', { name: 'Lighting' }).click()
  await page.getByRole('button', { name: 'Line', exact: true }).click()
  expect((await readConfig(page)).positions).toEqual({})
  expect(errors).toEqual([])
})

test('camera presets, overlays and reset remain usable', async ({ page }, testInfo) => {
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await page.getByRole('button', { name: 'Top view', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Top view', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('button', { name: 'Front view', exact: true }).click()
  await page.getByRole('button', { name: 'Reset camera', exact: true }).click()
  await page.getByRole('button', { name: 'Toggle floor grid' }).click()
  await openSettings(page)
  await page.getByRole('tab', { name: 'View', exact: true }).click()
  await expect(page.getByRole('switch', { name: 'Floor grid' })).toBeChecked()
  await page.getByRole('switch', { name: 'LED labels' }).uncheck()
  await expect(page.locator('.led-tag')).toHaveCount(0)
  await page.getByRole('switch', { name: 'Ghost ceiling' }).check()
  await page.getByRole('switch', { name: 'Emission guides' }).check()
  expect((await readConfig(page)).display).toMatchObject({ labels: false, grid: true, ceiling: true, beams: true })
  await page.screenshot({ path: testInfo.outputPath('overlays.png'), fullPage: true })
  await page.getByRole('button', { name: 'Restore default scene' }).click()
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await expect(page.getByRole('switch', { name: 'Floor grid' })).not.toBeChecked()
  await expect(page.getByRole('switch', { name: 'Ghost ceiling' })).not.toBeChecked()
})

test('recovers from malformed storage and validates number inputs', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('cambridge-digital-twin:v1', '{broken'))
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await openSettings(page)
  await editNumber(page, 'Width · X', '100')
  await expect(page.getByRole('spinbutton', { name: 'Width · X value', exact: true })).toHaveValue('10.0')
  await editNumber(page, 'Height · Z', '')
  await expect(page.getByRole('spinbutton', { name: 'Height · Z value', exact: true })).toHaveValue('2.0')
})

test('mobile layout keeps the scene and panel accessible without overflow', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(4)
  await openSettings(page)
  await page.getByRole('tab', { name: 'Lighting' }).click()
  await page.getByRole('button', { name: 'Square', exact: true }).click()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
  await page.evaluate(() => window.scrollTo(0, 0))
  await page.screenshot({ path: testInfo.outputPath('mobile-room.png'), fullPage: true })
})
