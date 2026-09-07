import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'
import { buildMotionRoute } from '../src/model/motion'
import type { MotionRoute } from '../src/model/motion'

async function config(page: Page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('cambridge-digital-twin:v1') ?? '{}'))
}

async function livePosition(page: Page) {
  return page.locator('.plan-receiver-marker').evaluate((marker) => ['x', 'y', 'z'].map((axis) => Number(marker.getAttribute(`data-world-${axis}`))))
}

function distance(a: number[], b: number[]) {
  return Math.hypot(...a.map((value, index) => value - b[index]))
}

function positionOnRoute(route: MotionRoute, position: number[]) {
  let best = { distanceM: 0, error: Infinity }
  for (let index = 1; index < route.points.length; index += 1) {
    const start = route.points[index - 1]
    const delta = route.points[index].map((value, axis) => value - start[axis])
    const lengthSquared = delta.reduce((sum, value) => sum + value * value, 0)
    if (lengthSquared === 0) continue
    const projection = Math.max(0, Math.min(1, delta.reduce((sum, value, axis) => sum + value * (position[axis] - start[axis]), 0) / lengthSquared))
    const error = distance(position, start.map((value, axis) => value + projection * delta[axis]))
    if (error < best.error) best = { error, distanceM: route.cumulativeDistances[index - 1] + projection * Math.sqrt(lengthSquared) }
  }
  return best
}

function errorsIn(page: Page) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  return errors
}

async function seedDrone(page: Page, speedMps = 0.2) {
  await page.addInitScript((speed) => {
    if (!localStorage.getItem('cambridge-digital-twin:v1')) {
      localStorage.setItem('cambridge-digital-twin:v1', JSON.stringify({ lighting: { count: 1 }, receiver: { platform: 'drone', position: [0, 0, 0.3], rotorsSpinning: false }, motion: { pattern: 'figure-eight', speedMps: speed } }))
    }
  }, speedMps)
  await page.goto('/')
  await expect(page.locator('.receiver-tag')).toBeVisible()
  await page.getByRole('button', { name: 'Open X-Y plan', exact: true }).click()
}

test('play updates drone, X-Y position and RSS; pause and resume preserve the live pose', async ({ page }, testInfo) => {
  test.setTimeout(90000)
  const errors = errorsIn(page)
  await seedDrone(page)
  await page.getByRole('button', { name: 'Open RSS chart', exact: true }).click()
  await page.getByRole('button', { name: 'Show RSS details' }).click()
  const rss = page.getByLabel('LED-01 ideal received power', { exact: true })
  await expect(rss).toBeAttached()
  const initialPower = Number(await rss.getAttribute('data-ideal-power-w'))
  const start = await livePosition(page)
  const initialConfig = await config(page)
  const route = buildMotionRoute(initialConfig.room, initialConfig.receiver, initialConfig.motion)
  const toolbar = page.getByRole('toolbar', { name: 'Camera and display controls' })
  const began = Date.now()
  await toolbar.getByRole('button', { name: 'Play drone route', exact: true }).click()
  await expect(toolbar.getByRole('button', { name: 'Pause drone route', exact: true })).toBeVisible()
  const early = await livePosition(page)
  expect(distance(early, start)).toBeLessThanOrEqual((Date.now() - began) / 1000 * 0.2 + 0.03)
  await expect.poll(async () => distance(await livePosition(page), start)).toBeGreaterThan(0.08)
  expect((await config(page)).receiver.position).toEqual(start)
  expect((await config(page)).receiver.rotorsSpinning).toBe(true)
  await expect.poll(async () => Number(await rss.getAttribute('data-ideal-power-w'))).toBeLessThan(initialPower * 0.999)
  await toolbar.getByRole('button', { name: 'Pause drone route', exact: true }).click()
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeVisible()
  const paused = await livePosition(page)
  await expect.poll(async () => (await config(page)).receiver.position).toEqual(paused)
  await page.waitForTimeout(200)
  expect(await livePosition(page)).toEqual(paused)
  const pausedPhase = positionOnRoute(route, paused)
  expect(pausedPhase.error).toBeLessThan(1e-7)
  const resumedAt = Date.now()
  await toolbar.getByRole('button', { name: 'Play drone route', exact: true }).click()
  await expect.poll(async () => distance(await livePosition(page), paused)).toBeGreaterThan(0.03)
  const resumedPhase = positionOnRoute(route, await livePosition(page))
  expect(resumedPhase.error).toBeLessThan(1e-7)
  const advance = (resumedPhase.distanceM - pausedPhase.distanceM + route.loopLengthM) % route.loopLengthM
  expect(advance).toBeGreaterThan(0)
  expect(advance).toBeLessThanOrEqual((Date.now() - resumedAt) / 1000 * initialConfig.motion.speedMps + 0.03)
  await toolbar.getByRole('button', { name: 'Pause drone route', exact: true }).click()
  const final = await livePosition(page)
  await page.screenshot({ path: testInfo.outputPath('route-and-analysis.png'), fullPage: true })
  await page.reload()
  await expect(page.locator('.receiver-tag')).toBeVisible()
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeVisible()
  expect((await config(page)).receiver.position).toEqual(final)
  expect(errors).toEqual([])
})

test('manual dragging takes over an active route without fighting playback', async ({ page }) => {
  test.setTimeout(90000)
  const errors = errorsIn(page)
  await seedDrone(page, 0.05)
  await page.getByRole('button', { name: 'Top view', exact: true }).click()
  const toolbar = page.getByRole('toolbar', { name: 'Camera and display controls' })
  await toolbar.getByRole('button', { name: 'Play drone route', exact: true }).click()
  await expect.poll(async () => distance(await livePosition(page), [0, 0, 0.3])).toBeGreaterThan(0.05)
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  const rect = (await tag.boundingBox())!
  await page.mouse.move(rect.x + rect.width / 2, rect.y + rect.height / 2)
  await page.mouse.down()
  await expect(tag).toHaveAttribute('data-dragging', 'true')
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeDisabled()
  const stopped = (await config(page)).receiver.position
  expect(distance(await livePosition(page), stopped)).toBeLessThan(0.001)
  await page.mouse.move(rect.x + rect.width / 2 + 40, rect.y + rect.height / 2 - 20, { steps: 4 })
  await expect.poll(async () => distance(await livePosition(page), stopped)).toBeGreaterThan(0.04)
  expect((await config(page)).receiver.position).toEqual(stopped)
  await page.keyboard.press('Escape')
  await page.mouse.up()
  await expect.poll(async () => livePosition(page)).toEqual(stopped)
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeEnabled()
  await page.waitForTimeout(200)
  expect(await livePosition(page)).toEqual(stopped)
  await tag.hover()
  const start = (await tag.boundingBox())!
  await page.mouse.move(start.x + start.width / 2, start.y + start.height / 2)
  await page.mouse.down()
  await page.mouse.move(start.x + start.width / 2 - 30, start.y + start.height / 2, { steps: 4 })
  await page.mouse.up()
  await expect(tag).toHaveAttribute('data-dragging', 'false')
  const placed = await livePosition(page)
  expect(distance(placed, stopped)).toBeGreaterThan(0.02)
  await page.waitForTimeout(200)
  expect(await livePosition(page)).toEqual(placed)
  expect(errors).toEqual([])
})

test('all three configured routes finish safely and editing pose pauses before coordinate changes', async ({ page }) => {
  test.setTimeout(90000)
  const errors = errorsIn(page)
  await page.goto('/')
  await expect(page.locator('.receiver-tag')).toBeVisible()
  const toolbar = page.getByRole('toolbar', { name: 'Camera and display controls' })
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeDisabled()
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  const settings = page.getByRole('complementary', { name: 'Scene configuration' })
  await settings.getByRole('tab', { name: 'Receiver', exact: true }).click()
  await settings.getByRole('button', { name: 'Drone', exact: true }).click()
  for (const [label, value] of [['Route size', '0.1'], ['Flight speed', '1'], ['Flight altitude', '0.4']]) {
    const input = settings.getByRole('spinbutton', { name: `${label} value`, exact: true })
    await input.fill(value)
    await input.press('Enter')
  }
  await settings.getByRole('switch', { name: 'Repeat route' }).uncheck()
  for (const [name, pattern] of [['Circle', 'circle'], ['Figure eight', 'figure-eight'], ['Raster scan', 'raster']]) {
    await settings.getByRole('button', { name, exact: true }).click()
    const current = await config(page)
    expect(current.motion.pattern).toBe(pattern)
    const endpoint = buildMotionRoute(current.room, current.receiver, current.motion).points.at(-1)!
    const play = toolbar.getByRole('button', { name: 'Play drone route', exact: true })
    await play.evaluate((element) => {
      element.setAttribute('data-route-started', 'false')
      element.setAttribute('data-route-completed', 'false')
      const observer = new MutationObserver(() => {
        if (element.getAttribute('aria-pressed') === 'true') element.setAttribute('data-route-started', 'true')
        else if (element.getAttribute('data-route-started') === 'true') {
          element.setAttribute('data-route-completed', 'true')
          observer.disconnect()
        }
      })
      observer.observe(element, { attributes: true, attributeFilter: ['aria-pressed'] })
    })
    await play.click()
    await expect(toolbar.locator('.motion-play')).toHaveAttribute('data-route-completed', 'true', { timeout: 15000 })
    await expect.poll(async () => (await config(page)).receiver.position).toEqual(endpoint)
  }
  await settings.getByRole('switch', { name: 'Repeat route' }).check()
  await toolbar.getByRole('button', { name: 'Play drone route', exact: true }).click()
  const x = settings.getByRole('spinbutton', { name: 'Receiver position · X value', exact: true })
  await x.focus()
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeVisible()
  const beforeEdit = (await config(page)).receiver.position
  await x.fill('0.5')
  await x.press('Enter')
  const afterEdit = (await config(page)).receiver.position
  expect(afterEdit[0]).toBe(0.5)
  expect(afterEdit[1]).toBeCloseTo(beforeEdit[1])
  expect(afterEdit[2]).toBeCloseTo(beforeEdit[2])
  const savedMotion = (await config(page)).motion
  await page.reload()
  await expect(page.locator('.receiver-tag')).toBeVisible()
  expect((await config(page)).motion).toEqual(savedMotion)
  await expect(toolbar.getByRole('button', { name: 'Play drone route', exact: true })).toBeVisible()
  expect(errors).toEqual([])
})
