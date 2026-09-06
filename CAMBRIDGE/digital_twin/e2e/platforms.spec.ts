import { expect, test } from '@playwright/test'
import type { Page } from '@playwright/test'
import type { Box3, Light, Mesh, Object3D, Scene } from 'three'
import { getPhotodiodePosition, getReceiverBounds } from '../src/model/receiver'
import { toScenePosition } from '../src/model/config'

const fiberModules = new WeakMap<Page, string>()

async function inspectScene(page: Page) {
  let moduleUrl = fiberModules.get(page)
  if (!moduleUrl) {
    const source = await (await page.request.get('/src/scene/TestbedScene.tsx')).text()
    moduleUrl = source.match(/from\s*["']([^"']*@react-three_fiber[^"']*)["']/)?.[1]
    expect(moduleUrl).toBeTruthy()
    fiberModules.set(page, moduleUrl!)
  }
  return page.evaluate(async (url) => {
    const { _roots } = await import(url)
    const state = _roots.get(document.querySelector('canvas')).store.getState()
    const scene = state.scene as Scene
    scene.updateMatrixWorld(true)
    const objects: Object3D[] = []
    scene.traverse((object) => objects.push(object))
    const receiver = scene.getObjectByName('RX-01')
    const pd = scene.getObjectByName('receiver-photodiode')
    let receiverShadowMeshes = 0
    receiver?.traverse((object) => { if ((object as Mesh).isMesh && object.castShadow) receiverShadowMeshes += 1 })
    const boxes: Box3[] = []
    for (const platform of objects.filter((object) => /^receiver-platform-/.test(object.name))) {
      platform.traverse((object) => {
        const mesh = object as Mesh
        if (!mesh.isMesh) return
        mesh.geometry.computeBoundingBox()
        const vertices = mesh.geometry.getAttribute('position')
        if (!mesh.geometry.boundingBox || !vertices) return
        const bounds = mesh.geometry.boundingBox.clone().makeEmpty()
        const point = mesh.position.clone()
        for (let index = 0; index < vertices.count; index += 1) {
          point.set(vertices.getX(index), vertices.getY(index), vertices.getZ(index)).applyMatrix4(mesh.matrixWorld)
          bounds.expandByPoint(point)
        }
        boxes.push(bounds)
      })
    }
    const bounds = boxes.length ? boxes.reduce((total, box) => total.union(box)) : null
    return {
      shadowLights: objects.filter((object) => (object as Light).isLight && object.castShadow && (object as Light).intensity > 0)
        .map((object) => ({ type: object.type, position: object.getWorldPosition(object.position.clone()).toArray() })),
      platforms: objects.filter((object) => /^receiver-platform-/.test(object.name)).map((object) => object.name),
      rotors: objects.filter((object) => /^drone-rotor-\d$/.test(object.name)).map((object) => ({ name: object.name, angle: object.rotation.y })),
      pd: pd ? pd.getWorldPosition(pd.position.clone()).toArray() : null,
      receiver: receiver ? receiver.getWorldPosition(receiver.position.clone()).toArray() : null,
      bounds: bounds ? { min: bounds.min.toArray(), max: bounds.max.toArray() } : null,
      receiverShadowMeshes,
      frame: state.gl.info.render.frame as number,
    }
  }, moduleUrl!)
}

async function readConfig(page: Page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('cambridge-digital-twin:v1') ?? '{}'))
}

async function openReceiverSettings(page: Page) {
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await page.getByRole('tab', { name: 'Receiver', exact: true }).click()
}

function captureErrors(page: Page) {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()) })
  return errors
}

test('only the configured LED casts shadows, not the studio fill', async ({ page }, testInfo) => {
  const errors = captureErrors(page)
  await page.addInitScript(() => localStorage.setItem('cambridge-digital-twin:v1', JSON.stringify({ lighting: { count: 1 }, receiver: { position: [0.4, -0.3, 0.3], yaw: 0 } })))
  await page.goto('/')
  await expect(page.locator('.led-tag')).toHaveCount(1)
  const lighting = await inspectScene(page)
  expect(lighting.shadowLights.map((light) => light.type)).toEqual(['SpotLight'])
  expect(lighting.receiverShadowMeshes).toBeGreaterThan(0)
  await page.screenshot({ path: testInfo.outputPath('single-led-shadow.png'), fullPage: true })
  await page.getByRole('button', { name: 'Perspective view', exact: true }).click()
  await expect.poll(async () => (await inspectScene(page)).shadowLights.map((light) => light.type)).toEqual(['SpotLight'])
  await page.getByRole('button', { name: 'Open settings', exact: true }).click()
  await page.getByRole('tab', { name: 'Lighting', exact: true }).click()
  const power = page.getByRole('spinbutton', { name: 'Optical power / LED value', exact: true })
  await power.fill('0')
  await power.press('Enter')
  await expect.poll(async () => (await inspectScene(page)).shadowLights.length).toBe(0)
  expect(errors).toEqual([])
})

test('drone rotors animate without moving the PD and stop when paused or unmounted', async ({ page }, testInfo) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await page.setViewportSize({ width: 1024, height: 720 })
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expect(page.locator('.receiver-tag')).toBeVisible()
  const original = await readConfig(page)
  await openReceiverSettings(page)
  await page.getByRole('button', { name: 'Drone', exact: true }).click()
  await expect.poll(async () => (await inspectScene(page)).platforms).toEqual(['receiver-platform-drone'])
  await expect(page.getByRole('switch', { name: 'Spinning propellers' })).toBeChecked()
  const drone = await readConfig(page)
  expect(drone.receiver.platform).toBe('drone')
  expect(drone.receiver.position).toEqual(original.receiver.position)
  expect(drone.receiver.yaw).toBe(original.receiver.yaw)
  const before = await inspectScene(page)
  expect(before.rotors).toHaveLength(4)
  await expect.poll(async () => (await inspectScene(page)).rotors.map((rotor) => rotor.angle)).not.toEqual(before.rotors.map((rotor) => rotor.angle))
  const moving = await inspectScene(page)
  expect(moving.receiver).toEqual(before.receiver)
  expect(moving.pd).toEqual(before.pd)
  toScenePosition(getPhotodiodePosition(drone.receiver)).forEach((value, axis) => expect(moving.pd![axis]).toBeCloseTo(value, 10))
  await page.getByRole('switch', { name: 'Spinning propellers' }).uncheck()
  await page.waitForTimeout(350)
  const paused = await inspectScene(page)
  await page.waitForTimeout(250)
  expect((await inspectScene(page)).rotors).toEqual(paused.rotors)
  await page.getByRole('switch', { name: 'Spinning propellers' }).check()
  await expect.poll(async () => (await inspectScene(page)).rotors.map((rotor) => rotor.angle)).not.toEqual(paused.rotors.map((rotor) => rotor.angle))
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.waitForTimeout(350)
  const reduced = await inspectScene(page)
  await page.waitForTimeout(250)
  expect((await inspectScene(page)).rotors).toEqual(reduced.rotors)
  expect((await readConfig(page)).receiver.rotorsSpinning).toBe(true)
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await expect.poll(async () => (await inspectScene(page)).rotors.map((rotor) => rotor.angle)).not.toEqual(reduced.rotors.map((rotor) => rotor.angle))
  await page.screenshot({ path: testInfo.outputPath('drone-platform.png'), fullPage: true })
  await page.getByRole('button', { name: 'Cylinder', exact: true }).click()
  await expect.poll(async () => (await inspectScene(page)).platforms).toEqual(['receiver-platform-cylinder'])
  expect((await inspectScene(page)).rotors).toHaveLength(0)
  await page.waitForTimeout(350)
  const stoppedFrame = (await inspectScene(page)).frame
  await page.waitForTimeout(250)
  expect((await inspectScene(page)).frame).toBe(stoppedFrame)
  expect(errors).toEqual([])
})

test('platform changes and drone dragging preserve geometry bounds, metadata and saved preferences', async ({ page }) => {
  test.setTimeout(90000)
  const errors = captureErrors(page)
  await page.addInitScript(() => {
    if (!localStorage.getItem('cambridge-digital-twin:v1')) {
      localStorage.setItem('cambridge-digital-twin:v1', JSON.stringify({ room: { width: 2, depth: 2, height: 2 }, receiver: { position: [0.94, 0.94, 0.3], yaw: 45 } }))
    }
  })
  await page.goto('/')
  await expect(page.locator('.receiver-tag')).toBeVisible()
  await openReceiverSettings(page)
  await page.getByRole('button', { name: 'Drone', exact: true }).click()
  await page.getByRole('switch', { name: 'Spinning propellers' }).uncheck()
  const drone = await readConfig(page)
  const limits = getReceiverBounds(drone.room, 'drone', 45)
  expect(drone.receiver.position[0]).toBeCloseTo(limits.x[1])
  expect(drone.receiver.position[1]).toBeCloseTo(limits.y[1])
  expect(drone.receiver.yaw).toBe(45)
  const physical = (await inspectScene(page)).bounds!
  expect(physical.max[0]).toBeLessThanOrEqual(1 - 0.01 + 0.000001)
  expect(physical.min[2]).toBeGreaterThanOrEqual(-1 + 0.01 - 0.000001)
  const x = page.getByRole('spinbutton', { name: 'Receiver position · X value', exact: true })
  await x.fill('0')
  await x.press('Enter')
  await page.getByRole('button', { name: 'Close configuration panel' }).click()
  const tag = page.getByRole('button', { name: 'Move receiver in X and Y', exact: true })
  await tag.dblclick()
  const axis = page.getByRole('button', { name: 'Move receiver along X', exact: true })
  await axis.hover()
  const handle = (await axis.elementHandle())!
  const rect = (await handle.boundingBox())!
  await page.mouse.move(rect.x + rect.width / 2, rect.y + rect.height / 2)
  await page.mouse.down()
  await expect.poll(() => handle.getAttribute('data-dragging')).toBe('true')
  await page.mouse.move(rect.x + rect.width / 2 + 800, rect.y + rect.height / 2, { steps: 4 })
  await expect.poll(async () => (await inspectScene(page)).receiver![0]).toBeCloseTo(limits.x[1], 8)
  expect((await readConfig(page)).receiver.position[0]).toBe(0)
  await page.mouse.up()
  await expect.poll(() => handle.getAttribute('data-dragging')).toBe('false')
  expect((await readConfig(page)).receiver.position[0]).toBeCloseTo(limits.x[1])
  await openReceiverSettings(page)
  const downloadEvent = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export scene' }).click()
  const stream = await (await downloadEvent).createReadStream()
  let text = ''
  for await (const chunk of stream!) text += chunk.toString()
  const exported = JSON.parse(text)
  expect(exported.receiverGeometry).toMatchObject({ width: 0.28, depth: 0.28, height: 0.06, pdWidth: 0.01, pdDepth: 0.01 })
  expect(exported.config.receiver).toMatchObject({ platform: 'drone', rotorsSpinning: false, yaw: 45 })
  await page.reload()
  await expect(page.locator('.receiver-tag')).toBeVisible()
  await expect.poll(async () => (await inspectScene(page)).platforms).toEqual(['receiver-platform-drone'])
  expect((await readConfig(page)).receiver).toMatchObject({ platform: 'drone', rotorsSpinning: false, yaw: 45 })
  expect(errors).toEqual([])
})
