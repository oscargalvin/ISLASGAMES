// Islas Rivals: a realistic first-person 1v1 arena duel, in the style of
// Roblox Rivals. Loadout: Primary, Secondary, Melee and Utility.
import * as THREE from 'three';
import { RoomEnvironment } from './RoomEnvironment.js';

const touch = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
if (touch) document.body.classList.add('touch');

// ---------- Renderer, scene, camera ----------
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, touch ? 1.5 : 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.9;
renderer.autoClear = false;
document.body.prepend(renderer.domElement);

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
const envMap = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environment = envMap;
scene.environmentIntensity = 0.35;
scene.fog = new THREE.Fog(0xb9c4cc, 45, 140);

const camera = new THREE.PerspectiveCamera(75, innerWidth / innerHeight, 0.05, 400);
camera.rotation.order = 'YXZ';

// The gun in your hands is drawn on top of the world, so it never clips into walls.
const viewScene = new THREE.Scene();
viewScene.environment = envMap;
const viewCam = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.01, 10);
viewScene.add(new THREE.HemisphereLight(0xdfe8f0, 0x3a3630, 1.1));
const viewSun = new THREE.DirectionalLight(0xfff1dc, 1.6);
viewSun.position.set(2, 3, 1);
viewScene.add(viewSun);

addEventListener('resize', () => {
  renderer.setSize(innerWidth, innerHeight);
  camera.aspect = viewCam.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  viewCam.updateProjectionMatrix();
});

// ---------- Procedural textures ----------
const rand = (a = 0, b = 1) => a + Math.random() * (b - a);

function makeCanvas(size, draw) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  draw(c.getContext('2d'), size);
  return c;
}

/** Smooth grayscale value noise, layered at a few scales. */
function noise(size, layers = [[8, 0.5], [32, 0.3], [128, 0.2]]) {
  return makeCanvas(size, (g) => {
    g.fillStyle = '#808080';
    g.fillRect(0, 0, size, size);
    for (const [cells, amount] of layers) {
      const small = makeCanvas(cells, (s) => {
        const img = s.createImageData(cells, cells);
        for (let i = 0; i < img.data.length; i += 4) {
          const v = Math.random() * 255;
          img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
          img.data[i + 3] = 255;
        }
        s.putImageData(img, 0, 0);
      });
      g.globalAlpha = amount;
      g.imageSmoothingEnabled = true;
      g.drawImage(small, 0, 0, size, size);
    }
    g.globalAlpha = 1;
  });
}

function texture(canvas, repeat = 1, color = true) {
  const t = new THREE.CanvasTexture(canvas);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(repeat, repeat);
  t.anisotropy = renderer.capabilities.getMaxAnisotropy();
  if (color) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function concreteCanvas(size, base, joints = 0) {
  const n = noise(size);
  return makeCanvas(size, (g) => {
    g.fillStyle = base;
    g.fillRect(0, 0, size, size);
    g.globalCompositeOperation = 'overlay';
    g.drawImage(n, 0, 0);
    g.globalCompositeOperation = 'source-over';
    // Stains and grit.
    for (let i = 0; i < 18; i++) {
      const x = rand(0, size), y = rand(0, size), r = rand(10, size / 4);
      const gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, `rgba(30,28,24,${rand(0.05, 0.14)})`);
      gr.addColorStop(1, 'rgba(30,28,24,0)');
      g.fillStyle = gr;
      g.fillRect(x - r, y - r, r * 2, r * 2);
    }
    for (let i = 0; i < size * 6; i++) {
      g.fillStyle = Math.random() < 0.5 ? 'rgba(0,0,0,.18)' : 'rgba(255,255,255,.1)';
      g.fillRect(rand(0, size), rand(0, size), 1.5, 1.5);
    }
    // Hairline cracks.
    g.strokeStyle = 'rgba(20,20,20,.25)';
    g.lineWidth = 1;
    for (let i = 0; i < 4; i++) {
      let x = rand(0, size), y = rand(0, size);
      g.beginPath();
      g.moveTo(x, y);
      for (let k = 0; k < 8; k++) { x += rand(-14, 14); y += rand(-14, 14); g.lineTo(x, y); }
      g.stroke();
    }
    if (joints) {
      g.strokeStyle = 'rgba(25,25,25,.55)';
      g.lineWidth = 3;
      for (let k = 0; k <= joints; k++) {
        const p = (k * size) / joints;
        g.beginPath(); g.moveTo(p, 0); g.lineTo(p, size); g.stroke();
        g.beginPath(); g.moveTo(0, p); g.lineTo(size, p); g.stroke();
      }
    }
  });
}

function woodCanvas(size) {
  return makeCanvas(size, (g) => {
    const planks = 5;
    const h = size / planks;
    for (let p = 0; p < planks; p++) {
      const l = rand(-12, 12);
      g.fillStyle = `hsl(32, 38%, ${40 + l * 0.6}%)`;
      g.fillRect(0, p * h, size, h);
      for (let i = 0; i < 40; i++) {
        g.strokeStyle = `rgba(60,35,15,${rand(0.05, 0.25)})`;
        g.lineWidth = rand(0.5, 2);
        const y = p * h + rand(2, h - 2);
        g.beginPath();
        g.moveTo(0, y);
        g.bezierCurveTo(size / 3, y + rand(-4, 4), (2 * size) / 3, y + rand(-4, 4), size, y + rand(-3, 3));
        g.stroke();
      }
      g.fillStyle = 'rgba(30,18,8,.6)';
      g.fillRect(0, p * h, size, 2);
    }
    // Frame and cross brace, like a real shipping crate.
    const f = size * 0.09;
    g.fillStyle = 'hsl(30, 35%, 33%)';
    g.fillRect(0, 0, size, f); g.fillRect(0, size - f, size, f);
    g.fillRect(0, 0, f, size); g.fillRect(size - f, 0, f, size);
    g.save();
    g.translate(size / 2, size / 2);
    g.rotate(Math.PI / 4);
    g.fillRect(-size * 0.7, -f / 2, size * 1.4, f);
    g.restore();
    g.strokeStyle = 'rgba(20,10,4,.5)';
    g.lineWidth = 2;
    g.strokeRect(f, f, size - 2 * f, size - 2 * f);
    g.fillStyle = 'rgba(40,40,40,.85)';
    for (const [x, y] of [[f / 2, f / 2], [size - f / 2, f / 2], [f / 2, size - f / 2], [size - f / 2, size - f / 2]]) {
      g.beginPath(); g.arc(x, y, 3, 0, Math.PI * 2); g.fill();
    }
    g.globalCompositeOperation = 'overlay';
    g.drawImage(noise(size), 0, 0);
  });
}

function containerCanvas(size, hue) {
  return makeCanvas(size, (g) => {
    g.fillStyle = `hsl(${hue}, 45%, 34%)`;
    g.fillRect(0, 0, size, size);
    const ribs = 16, w = size / ribs;
    for (let i = 0; i < ribs; i++) {
      const gr = g.createLinearGradient(i * w, 0, (i + 1) * w, 0);
      gr.addColorStop(0, 'rgba(255,255,255,.12)');
      gr.addColorStop(0.5, 'rgba(0,0,0,.05)');
      gr.addColorStop(1, 'rgba(0,0,0,.28)');
      g.fillStyle = gr;
      g.fillRect(i * w, 0, w, size);
    }
    for (let i = 0; i < 30; i++) {
      const x = rand(0, size), y = rand(0, size), r = rand(3, 26);
      const gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, `rgba(110,55,25,${rand(0.2, 0.55)})`);
      gr.addColorStop(1, 'rgba(110,55,25,0)');
      g.fillStyle = gr;
      g.fillRect(x - r, y - r, r * 2, r * 2);
    }
    for (let i = 0; i < 25; i++) {
      g.fillStyle = `rgba(80,40,20,${rand(0.1, 0.3)})`;
      g.fillRect(rand(0, size), rand(0, size * 0.3), rand(1, 3), rand(20, 80));
    }
    g.globalCompositeOperation = 'overlay';
    g.drawImage(noise(size), 0, 0);
  });
}

function ribBump(size) {
  return makeCanvas(size, (g) => {
    const ribs = 16, w = size / ribs;
    for (let i = 0; i < ribs; i++) {
      const gr = g.createLinearGradient(i * w, 0, (i + 1) * w, 0);
      gr.addColorStop(0, '#202020'); gr.addColorStop(0.3, '#e0e0e0'); gr.addColorStop(0.7, '#e0e0e0'); gr.addColorStop(1, '#202020');
      g.fillStyle = gr;
      g.fillRect(i * w, 0, w, size);
    }
  });
}

const floorTex = concreteCanvas(1024, '#716e68', 4);
const mats = {
  floor: new THREE.MeshStandardMaterial({ map: texture(floorTex, 12), bumpMap: texture(noise(512), 12, false), bumpScale: 0.6, roughness: 0.92 }),
  wall: new THREE.MeshStandardMaterial({ map: texture(concreteCanvas(512, '#8a867d', 2), 1), bumpMap: texture(noise(512), 1, false), bumpScale: 0.8, roughness: 0.95 }),
  barrier: new THREE.MeshStandardMaterial({ map: texture(concreteCanvas(512, '#9c988d'), 1), bumpMap: texture(noise(256), 1, false), bumpScale: 1, roughness: 0.9 }),
  crate: new THREE.MeshStandardMaterial({ map: texture(woodCanvas(512), 1), bumpMap: texture(noise(256), 1, false), bumpScale: 0.5, roughness: 0.85 }),
  containers: [[2, 0], [205, 1], [140, 2], [28, 3]].map(([hue]) => new THREE.MeshStandardMaterial({
    map: texture(containerCanvas(512, hue), 1), bumpMap: texture(ribBump(512), 1, false), bumpScale: 2.5, roughness: 0.65, metalness: 0.35,
  })),
  steel: new THREE.MeshStandardMaterial({ color: 0x55585c, roughness: 0.45, metalness: 0.85 }),
  barrel: new THREE.MeshStandardMaterial({ color: 0x2f4a6b, roughness: 0.5, metalness: 0.6 }),
  stripe: new THREE.MeshStandardMaterial({ color: 0xd8a01c, roughness: 0.7 }),
};

// ---------- Arena ----------
const ARENA_X = 30, ARENA_Z = 22, WALL_H = 5;
/** Solid boxes for collisions: {x0,x1,z0,z1,top}. */
const solids = [];
/** Meshes bullets can hit. */
const hittable = [];

function box(w, h, d, mat, x, y, z, rotY = 0, solid = true) {
  const geo = new THREE.BoxGeometry(w, h, d);
  // Scale UVs to the box size so textures keep a real-world scale.
  const uv = geo.attributes.uv, n = geo.attributes.normal;
  for (let i = 0; i < uv.count; i++) {
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i));
    const [su, sv] = ax > 0.5 ? [d, h] : ay > 0.5 ? [w, d] : [w, h];
    if (mat === mats.crate) continue;
    uv.setXY(i, uv.getX(i) * su / 4, uv.getY(i) * sv / 4);
  }
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y + h / 2, z);
  m.rotation.y = rotY;
  m.castShadow = m.receiveShadow = true;
  scene.add(m);
  hittable.push(m);
  if (solid) {
    const c = Math.abs(Math.cos(rotY)), s = Math.abs(Math.sin(rotY));
    const hw = (w * c + d * s) / 2, hd = (w * s + d * c) / 2;
    solids.push({ x0: x - hw, x1: x + hw, z0: z - hd, z1: z + hd, top: y + h });
  }
  return m;
}

// Floor.
const floor = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), mats.floor);
floor.material.map.repeat.set(30, 30);
floor.material.bumpMap.repeat.set(30, 30);
floor.rotation.x = -Math.PI / 2;
floor.receiveShadow = true;
scene.add(floor);
hittable.push(floor);

// Outer walls with steel caps.
for (const [w, d, x, z] of [
  [ARENA_X * 2 + 1, 1, 0, -ARENA_Z - 0.5], [ARENA_X * 2 + 1, 1, 0, ARENA_Z + 0.5],
  [1, ARENA_Z * 2 + 1, -ARENA_X - 0.5, 0], [1, ARENA_Z * 2 + 1, ARENA_X + 0.5, 0],
]) {
  box(w, WALL_H, d, mats.wall, x, 0, z);
  box(w + 0.1, 0.15, d + 0.1, mats.steel, x, WALL_H, z, 0, false);
}

function crate(x, z, stack = 1, s = 1.4, rot = 0) {
  for (let i = 0; i < stack; i++) box(s, s, s, mats.crate, x, i * s, z, rot + (i ? rand(-0.15, 0.15) : 0));
}
function container(x, z, rotY, kind) {
  const m = box(6.1, 2.6, 2.45, mats.containers[kind], x, 0, z, rotY);
  return m;
}
function barrier(x, z, rotY = 0) {
  box(3, 1.05, 0.7, mats.barrier, x, 0, z, rotY);
}
function barrel(x, z) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 1.25, 24), mats.barrel);
  m.position.set(x, 0.625, z);
  m.castShadow = m.receiveShadow = true;
  scene.add(m);
  hittable.push(m);
  for (const y of [0.3, 0.95]) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.425, 0.025, 6, 24), mats.steel);
    ring.rotation.x = Math.PI / 2;
    ring.position.set(x, y, z);
    scene.add(ring);
  }
  solids.push({ x0: x - 0.42, x1: x + 0.42, z0: z - 0.42, z1: z + 0.42, top: 1.25 });
}
function pillar(x, z) {
  box(1.4, WALL_H, 1.4, mats.wall, x, 0, z);
  box(1.42, 0.25, 1.42, mats.stripe, x, 0.4, z, 0, false);
}

// A mirrored layout so both sides are fair.
for (const side of [1, -1]) {
  container(-14, side * 9, 0, side > 0 ? 0 : 1);
  container(14, side * 9, 0, side > 0 ? 2 : 3);
  container(side * 24, 0, Math.PI / 2, side > 0 ? 1 : 0);
  crate(-5, side * 12, 2);
  crate(-3.6, side * 12, 1);
  crate(6, side * 13, 1);
  crate(22, side * 15, 3, 1.3);
  crate(-22, side * 15, 1, 1.3, 0.3);
  barrier(0, side * 7);
  barrier(-9, side * 15.5, 0.5 * side);
  barrier(9, side * 15.5, -0.5 * side);
  barrel(side * 18, 4 * side);
  barrel(side * 18.9, 4.6 * side);
  barrel(-side * 6, 16.5 * side);
  pillar(side * 7, 0);
}
crate(0, 0, 1, 1.6);
crate(-0.2, 0.1, 1, 1.0);
pillar(-17, 0); pillar(17, 0);

// Light: a hazy afternoon sun.
scene.add(new THREE.HemisphereLight(0xcfdbe6, 0x5b5248, 0.55));
const sun = new THREE.DirectionalLight(0xfff0d8, 2.6);
sun.position.set(-30, 45, 20);
sun.castShadow = true;
sun.shadow.mapSize.set(touch ? 1024 : 2048, touch ? 1024 : 2048);
const sc = sun.shadow.camera;
sc.left = -40; sc.right = 40; sc.top = 32; sc.bottom = -32; sc.far = 120;
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.03;
scene.add(sun);

// Sky dome.
{
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(300, 32, 16),
    new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      vertexShader: 'varying vec3 p; void main(){ p = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: 'varying vec3 p; void main(){ float h = max(p.y, 0.0); vec3 c = mix(vec3(0.74,0.79,0.83), vec3(0.33,0.52,0.74), pow(h, 0.6)); gl_FragColor = vec4(c, 1.0); }',
    }),
  );
  scene.add(sky);
  // Distant buildings for a sense of place.
  const bmat = new THREE.MeshStandardMaterial({ color: 0x77818a, roughness: 1 });
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * Math.PI * 2, r = rand(70, 95), h = rand(10, 38);
    const b = new THREE.Mesh(new THREE.BoxGeometry(rand(8, 18), h, rand(8, 18)), bmat);
    b.position.set(Math.cos(a) * r, h / 2, Math.sin(a) * r);
    b.rotation.y = rand(0, Math.PI);
    scene.add(b);
  }
}

// ---------- Weapons ----------
const gunMetal = new THREE.MeshStandardMaterial({ color: 0x2b2d30, roughness: 0.38, metalness: 0.9 });
const polymer = new THREE.MeshStandardMaterial({ color: 0x1a1b1c, roughness: 0.75, metalness: 0.1 });
const tan = new THREE.MeshStandardMaterial({ color: 0x8c7a5b, roughness: 0.8 });
const glove = new THREE.MeshStandardMaterial({ color: 0x23241f, roughness: 0.9 });
const sleeve = new THREE.MeshStandardMaterial({ color: 0x4a4f3c, roughness: 0.95 });
const blade = new THREE.MeshStandardMaterial({ color: 0xc9ccd0, roughness: 0.2, metalness: 1 });
const olive = new THREE.MeshStandardMaterial({ color: 0x4d5536, roughness: 0.6, metalness: 0.2 });

function part(parent, geo, mat, x, y, z, rx = 0, ry = 0, rz = 0) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.rotation.set(rx, ry, rz);
  parent.add(m);
  return m;
}
const B = (w, h, d) => new THREE.BoxGeometry(w, h, d);
const C = (r, l, s = 16) => new THREE.CylinderGeometry(r, r, l, s);

function arms(g, rightAt, leftAt) {
  // Right hand on the grip, left hand forward.
  part(g, B(0.075, 0.09, 0.11), glove, ...rightAt);
  part(g, B(0.1, 0.1, 0.34), sleeve, rightAt[0] + 0.03, rightAt[1] - 0.06, rightAt[2] + 0.2, 0.25);
  if (leftAt) {
    part(g, B(0.08, 0.085, 0.11), glove, ...leftAt);
    part(g, B(0.1, 0.1, 0.36), sleeve, leftAt[0] - 0.1, leftAt[1] - 0.06, leftAt[2] + 0.2, 0.2, -0.5);
  }
}

function makeRifle() {
  const g = new THREE.Group();
  part(g, B(0.06, 0.08, 0.36), gunMetal, 0, 0, 0); // receiver
  part(g, B(0.065, 0.065, 0.3), tan, 0, -0.005, -0.32); // handguard
  part(g, C(0.012, 0.3), gunMetal, 0, 0.005, -0.6, Math.PI / 2); // barrel
  part(g, C(0.02, 0.07), gunMetal, 0, 0.005, -0.76, Math.PI / 2); // muzzle brake
  part(g, B(0.045, 0.14, 0.07), polymer, 0, -0.1, -0.06, 0.25); // magazine
  part(g, B(0.04, 0.11, 0.045), polymer, 0, -0.09, 0.12, -0.35); // grip
  part(g, B(0.05, 0.08, 0.24), tan, 0, -0.01, 0.3); // stock
  part(g, B(0.025, 0.012, 0.42), gunMetal, 0, 0.047, -0.15); // rail
  part(g, C(0.022, 0.12), polymer, 0, 0.085, -0.04, Math.PI / 2); // red dot sight
  part(g, B(0.03, 0.03, 0.03), polymer, 0, 0.06, -0.04);
  arms(g, [0.0, -0.06, 0.12], [0.0, -0.05, -0.32]);
  g.userData.muzzle = new THREE.Vector3(0, 0.005, -0.8);
  return g;
}
function makePistol() {
  const g = new THREE.Group();
  part(g, B(0.04, 0.045, 0.2), gunMetal, 0, 0.02, -0.03); // slide
  part(g, B(0.036, 0.035, 0.17), polymer, 0, -0.015, -0.02); // frame
  part(g, B(0.034, 0.11, 0.05), polymer, 0, -0.07, 0.05, -0.25); // grip
  part(g, B(0.008, 0.012, 0.01), gunMetal, 0, 0.05, -0.12);
  arms(g, [0.0, -0.08, 0.06], [-0.035, -0.085, 0.05]);
  g.userData.muzzle = new THREE.Vector3(0, 0.02, -0.14);
  return g;
}
function makeKnife() {
  const g = new THREE.Group();
  const b = part(g, B(0.006, 0.035, 0.2), blade, 0, 0.01, -0.13);
  b.geometry.translate(0, 0, 0);
  part(g, B(0.02, 0.05, 0.015), gunMetal, 0, 0.005, -0.03); // guard
  part(g, B(0.025, 0.035, 0.11), polymer, 0, 0.0, 0.03); // handle
  arms(g, [0.0, -0.01, 0.03]);
  g.rotation.z = -0.3;
  return g;
}
function makeGrenade() {
  const g = new THREE.Group();
  const body = part(g, new THREE.SphereGeometry(0.045, 20, 14), olive, 0, 0.02, -0.05);
  body.scale.set(1, 1.25, 1);
  part(g, C(0.018, 0.035), gunMetal, 0, 0.085, -0.05);
  part(g, B(0.012, 0.07, 0.02), gunMetal, 0.02, 0.06, -0.05, 0, 0, -0.3); // spoon
  part(g, new THREE.TorusGeometry(0.014, 0.003, 6, 14), blade, -0.025, 0.1, -0.05, 0, Math.PI / 2);
  arms(g, [0.0, -0.035, -0.02]);
  return g;
}

const WEAPONS = [
  { slot: 'Primary', name: 'Assault Rifle', key: '1', make: makeRifle, auto: true, rate: 0.1, dmg: 24, mag: 30, reload: 2.0, spread: 0.012, range: 200, kick: 0.035, sound: 'rifle' },
  { slot: 'Secondary', name: 'Handgun', key: '2', make: makePistol, auto: false, rate: 0.22, dmg: 34, mag: 12, reload: 1.4, spread: 0.008, range: 120, kick: 0.05, sound: 'pistol' },
  { slot: 'Melee', name: 'Knife', key: '3', make: makeKnife, auto: true, rate: 0.55, dmg: 60, melee: true, range: 2.6, sound: 'swing' },
  { slot: 'Utility', name: 'Grenade', key: '4', make: makeGrenade, auto: false, rate: 0.9, dmg: 110, grenades: 2, sound: 'throw' },
];
const holder = new THREE.Group();
viewScene.add(holder);
for (const w of WEAPONS) {
  w.model = w.make();
  w.model.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
  w.model.visible = false;
  holder.add(w.model);
}
const HOLD = new THREE.Vector3(0.2, -0.2, -0.62);
holder.scale.setScalar(0.75);

// Muzzle flash.
const flashMat = new THREE.SpriteMaterial({
  map: texture(makeCanvas(64, (g) => {
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,250,220,1)'); gr.addColorStop(0.3, 'rgba(255,190,90,.9)'); gr.addColorStop(1, 'rgba(255,120,30,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  })),
  blending: THREE.AdditiveBlending, depthWrite: false, transparent: true,
});
const flash = new THREE.Sprite(flashMat);
flash.scale.set(0.16, 0.16, 0.16);
flash.visible = false;
holder.add(flash);
const flashLight = new THREE.PointLight(0xffb060, 0, 8, 2);
scene.add(flashLight);

// ---------- Sound (made on the fly, no files) ----------
let audio;
function sfx(kind, vol = 1) {
  if (!audio) return;
  const t = audio.currentTime;
  const out = audio.createGain();
  out.gain.value = vol;
  out.connect(audio.destination);
  const noiseBuf = (len) => {
    const b = audio.createBuffer(1, audio.sampleRate * len, audio.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / d.length, 2);
    const s = audio.createBufferSource();
    s.buffer = b;
    return s;
  };
  const burst = (len, freq, q, gain, type = 'lowpass') => {
    const s = noiseBuf(len), f = audio.createBiquadFilter(), g = audio.createGain();
    f.type = type; f.frequency.value = freq; f.Q.value = q;
    g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + len);
    s.connect(f).connect(g).connect(out); s.start(t);
  };
  const thump = (f0, f1, len, gain) => {
    const o = audio.createOscillator(), g = audio.createGain();
    o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + len);
    g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + len);
    o.connect(g).connect(out); o.start(t); o.stop(t + len);
  };
  if (kind === 'rifle') { burst(0.25, 2400, 0.7, 0.9); thump(160, 40, 0.12, 0.8); }
  else if (kind === 'pistol') { burst(0.2, 3000, 0.8, 0.8); thump(200, 50, 0.1, 0.6); }
  else if (kind === 'enemy') { burst(0.22, 1500, 0.7, 0.5); thump(120, 40, 0.1, 0.35); }
  else if (kind === 'swing') burst(0.18, 1200, 2, 0.5, 'bandpass');
  else if (kind === 'stab') { burst(0.1, 800, 1, 0.6); thump(90, 50, 0.08, 0.6); }
  else if (kind === 'throw') burst(0.25, 600, 1.5, 0.4, 'bandpass');
  else if (kind === 'boom') { burst(1.4, 500, 0.5, 1.2); thump(90, 25, 0.8, 1.2); }
  else if (kind === 'hit') { const o = audio.createOscillator(), g = audio.createGain(); o.type = 'square'; o.frequency.value = 1800; g.gain.setValueAtTime(0.08, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.06); o.connect(g).connect(out); o.start(t); o.stop(t + 0.06); }
  else if (kind === 'head') { const o = audio.createOscillator(), g = audio.createGain(); o.type = 'triangle'; o.frequency.value = 2600; g.gain.setValueAtTime(0.2, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.12); o.connect(g).connect(out); o.start(t); o.stop(t + 0.12); }
  else if (kind === 'reload') { burst(0.06, 3000, 3, 0.4, 'bandpass'); setTimeout(() => sfx('click', 0.8), 350); }
  else if (kind === 'click') burst(0.05, 4000, 4, 0.5, 'bandpass');
  else if (kind === 'step') burst(0.07, 400, 1, 0.12);
}

// ---------- The rival (a bot) ----------
function makeSoldier() {
  const g = new THREE.Group();
  const cloth = new THREE.MeshStandardMaterial({ color: 0x3e4334, roughness: 0.95 });
  const vest = new THREE.MeshStandardMaterial({ color: 0x24262a, roughness: 0.85 });
  const skin = new THREE.MeshStandardMaterial({ color: 0xb98a6a, roughness: 0.7 });
  const helmet = new THREE.MeshStandardMaterial({ color: 0x2f342b, roughness: 0.6, metalness: 0.2 });
  const boots = new THREE.MeshStandardMaterial({ color: 0x1d1a17, roughness: 0.8 });
  const parts = {};
  const add = (name, geo, mat, x, y, z, hit) => {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    m.castShadow = true;
    m.userData.bot = true;
    m.userData.part = hit;
    g.add(m);
    parts[name] = m;
    return m;
  };
  const cap = (r, l) => new THREE.CapsuleGeometry(r, l, 4, 10);
  // Legs pivot at the hips so they can swing.
  for (const s of [-1, 1]) {
    const hip = new THREE.Group();
    hip.position.set(0.12 * s, 0.92, 0);
    g.add(hip);
    const leg = new THREE.Mesh(cap(0.085, 0.62), cloth);
    leg.position.y = -0.42; leg.castShadow = true; leg.userData = { bot: true, part: 'body' };
    hip.add(leg);
    const boot = new THREE.Mesh(B(0.13, 0.12, 0.26), boots);
    boot.position.set(0, -0.86, 0.04); boot.castShadow = true; boot.userData = { bot: true, part: 'body' };
    hip.add(boot);
    parts[s < 0 ? 'legL' : 'legR'] = hip;
  }
  add('hips', B(0.36, 0.18, 0.22), cloth, 0, 0.95, 0, 'body');
  add('torso', cap(0.2, 0.32), cloth, 0, 1.27, 0, 'body').scale.set(1, 1, 0.7);
  add('vest', B(0.42, 0.42, 0.3), vest, 0, 1.3, 0, 'body');
  for (let i = 0; i < 3; i++) add('pouch' + i, B(0.1, 0.12, 0.06), vest, (i - 1) * 0.12, 1.2, -0.17, 'body');
  add('neck', C(0.06, 0.1), skin, 0, 1.56, 0, 'head');
  add('head', new THREE.SphereGeometry(0.115, 20, 14), skin, 0, 1.68, 0, 'head').scale.set(0.9, 1.05, 1);
  add('helmet', new THREE.SphereGeometry(0.135, 20, 12, 0, Math.PI * 2, 0, Math.PI / 1.9), helmet, 0, 1.71, 0.01, 'head');
  add('goggles', B(0.2, 0.05, 0.04), new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 0.1, metalness: 0.6 }), 0, 1.7, -0.11, 'head');
  // Arms holding a rifle forward.
  add('armR', cap(0.065, 0.42), cloth, 0.2, 1.3, -0.18, 'body').rotation.set(-1.2, 0, 0.2);
  add('armL', cap(0.065, 0.42), cloth, -0.2, 1.3, -0.24, 'body').rotation.set(-1.3, 0, -0.35);
  const gun = makeRifle();
  gun.children.slice(-4).forEach((c) => (c.visible = false)); // no first-person arms
  gun.scale.setScalar(1.1);
  gun.position.set(0.08, 1.33, -0.45);
  gun.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.userData = { bot: true, part: 'body' }; } });
  g.add(gun);
  g.userData.parts = parts;
  g.userData.gun = gun;
  return g;
}

const bot = { obj: makeSoldier(), pos: new THREE.Vector3(), yaw: 0, hp: 100, goal: new THREE.Vector3(), cool: 0, see: 0, strafe: 1, think: 0, walk: 0, dead: false, nades: 1 };
scene.add(bot.obj);
bot.obj.traverse((o) => { if (o.isMesh) hittable.push(o); });

// ---------- Player ----------
const player = { pos: new THREE.Vector3(), vy: 0, yaw: 0, pitch: 0, hp: 100, onGround: true, weapon: 0, ammo: WEAPONS.map((w) => w.mag || 0), cool: 0, reloading: 0, swap: 0, recoil: 0, bob: 0, grenades: 2, dead: false };
const EYE = 1.65, RADIUS = 0.35;
const keys = {};
let firing = false;
let started = false;
const score = { you: 0, them: 0 };
let roundState = 'idle', roundTimer = 0;

function resetLoadout() {
  player.ammo = WEAPONS.map((w) => w.mag || 0);
  player.grenades = 2;
  player.reloading = 0;
}

// Collision: push a circle out of every solid box it overlaps.
function collide(p, r, feetY = 0) {
  for (const s of solids) {
    if (feetY >= s.top - 0.05) continue;
    const cx = Math.max(s.x0, Math.min(p.x, s.x1));
    const cz = Math.max(s.z0, Math.min(p.z, s.z1));
    const dx = p.x - cx, dz = p.z - cz, d2 = dx * dx + dz * dz;
    if (d2 < r * r) {
      if (d2 > 1e-8) {
        const d = Math.sqrt(d2);
        p.x = cx + (dx / d) * r;
        p.z = cz + (dz / d) * r;
      } else {
        // Inside the box: leave by the nearest side.
        const opts = [[p.x - s.x0, -1, 0], [s.x1 - p.x, 1, 0], [p.z - s.z0, 0, -1], [s.z1 - p.z, 0, 1]].sort((a, b) => a[0] - b[0]);
        const [, ox, oz] = opts[0];
        if (ox) p.x = ox < 0 ? s.x0 - r : s.x1 + r;
        else p.z = oz < 0 ? s.z0 - r : s.z1 + r;
      }
    }
  }
  p.x = Math.max(-ARENA_X + r, Math.min(ARENA_X - r, p.x));
  p.z = Math.max(-ARENA_Z + r, Math.min(ARENA_Z - r, p.z));
}
function groundAt(p, r, feetY) {
  let g = 0;
  for (const s of solids) {
    if (s.top > feetY + 0.45) continue;
    if (p.x > s.x0 - r * 0.5 && p.x < s.x1 + r * 0.5 && p.z > s.z0 - r * 0.5 && p.z < s.z1 + r * 0.5) g = Math.max(g, s.top);
  }
  return g;
}

const ray = new THREE.Raycaster();
function lineOfSight(a, b) {
  const dir = b.clone().sub(a);
  const dist = dir.length();
  ray.set(a, dir.normalize());
  ray.far = dist;
  const hits = ray.intersectObjects(hittable, false);
  for (const h of hits) if (!h.object.userData.bot) return false;
  return true;
}

// ---------- Effects ----------
const effects = [];
const sparkMat = new THREE.MeshBasicMaterial({ color: 0xffd28a });
const dustMat = new THREE.MeshBasicMaterial({ color: 0x8a857c, transparent: true, opacity: 0.6, depthWrite: false });
const holeMat = new THREE.MeshBasicMaterial({ color: 0x141210, transparent: true, opacity: 0.85, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 });
const holes = [];
function impact(point, normal, onBot) {
  const n = onBot ? 4 : 8;
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(onBot ? 0.03 : 0.02, 4, 3), onBot ? new THREE.MeshBasicMaterial({ color: 0x8a1010 }) : i < 3 ? sparkMat : dustMat);
    m.position.copy(point);
    const v = (normal ? normal.clone() : new THREE.Vector3(0, 1, 0)).multiplyScalar(rand(1, 3)).add(new THREE.Vector3(rand(-1.5, 1.5), rand(0, 2), rand(-1.5, 1.5)));
    scene.add(m);
    effects.push({ m, v, life: rand(0.2, 0.5), grav: 9 });
  }
  if (!onBot && normal) {
    const h = new THREE.Mesh(new THREE.CircleGeometry(0.04, 8), holeMat);
    h.position.copy(point).addScaledVector(normal, 0.005);
    h.lookAt(point.clone().add(normal));
    scene.add(h);
    holes.push(h);
    if (holes.length > 60) scene.remove(holes.shift());
  }
}
const tracerMat = new THREE.LineBasicMaterial({ color: 0xffe7a8, transparent: true, opacity: 0.7 });
function tracer(a, b) {
  const geo = new THREE.BufferGeometry().setFromPoints([a, b]);
  const l = new THREE.Line(geo, tracerMat.clone());
  scene.add(l);
  effects.push({ m: l, life: 0.06, fade: true });
}

// ---------- HUD ----------
const $ = (id) => document.getElementById(id);
const slotsEl = $('slots');
WEAPONS.forEach((w, i) => {
  const d = document.createElement('div');
  d.className = 'slot';
  d.innerHTML = `<b>${['AR', 'HG', 'KN', 'GR'][i]}</b>${w.slot}<i>${w.key}</i>`;
  const pick = (e) => { e.preventDefault(); e.stopPropagation(); selectWeapon(i); };
  d.addEventListener('touchstart', pick, { passive: false });
  d.addEventListener('mousedown', pick);
  slotsEl.appendChild(d);
});
let hitTimer = 0;
function showHit(head) {
  const h = $('hit');
  h.className = 'hud' + (head ? ' head' : '');
  h.style.opacity = 1;
  hitTimer = 0.18;
}
let bannerTimer = 0;
function banner(text, small = '', time = 1.6) {
  $('banner').innerHTML = `${text}${small ? `<small>${small}</small>` : ''}`;
  $('banner').style.opacity = 1;
  bannerTimer = time;
}
function updateHud() {
  const w = WEAPONS[player.weapon];
  $('hn').textContent = Math.max(0, Math.ceil(player.hp));
  $('hf').style.width = Math.max(0, player.hp) + '%';
  $('hf').style.background = player.hp > 50 ? 'linear-gradient(90deg,#3fb950,#7ee787)' : player.hp > 25 ? '#d29922' : '#f85149';
  $('ef').style.width = Math.max(0, bot.hp) + '%';
  $('an').textContent = w.melee ? '∞' : w.grenades ? player.grenades : `${player.ammo[player.weapon]} / ${w.mag}`;
  $('aw').textContent = w.name;
  $('sy').textContent = score.you;
  $('st').textContent = score.them;
  [...slotsEl.children].forEach((c, i) => c.classList.toggle('on', i === player.weapon));
  $('reload').style.opacity = player.reloading > 0 ? 1 : 0;
}

// ---------- Weapons in action ----------
function selectWeapon(i) {
  if (i === player.weapon || player.dead) return;
  player.weapon = i;
  player.swap = 0.35;
  player.reloading = 0;
  player.cool = Math.max(player.cool, 0.3);
  WEAPONS.forEach((w, k) => (w.model.visible = k === i));
  updateHud();
}
function nextWeapon() { selectWeapon((player.weapon + 1) % WEAPONS.length); }

function damageBot(amount, head) {
  if (bot.dead || roundState !== 'fight') return;
  bot.hp -= amount;
  bot.see = Math.max(bot.see, 0.6); // it knows where you are now
  showHit(head);
  sfx(head ? 'head' : 'hit');
  if (bot.hp <= 0) {
    bot.dead = true;
    score.you++;
    endRound(true);
  }
  updateHud();
}
function damagePlayer(amount) {
  if (player.dead || roundState !== 'fight') return;
  player.hp -= amount;
  $('hurt').style.boxShadow = `inset 0 0 140px rgba(200,0,0,${Math.min(0.85, 0.3 + amount / 40)})`;
  setTimeout(() => ($('hurt').style.boxShadow = 'inset 0 0 140px rgba(200,0,0,0)'), 120);
  if (player.hp <= 0) {
    player.dead = true;
    score.them++;
    endRound(false);
  }
  updateHud();
}

const tmp = new THREE.Vector3();
function eye() { return new THREE.Vector3(player.pos.x, player.pos.y + EYE, player.pos.z); }
function aimDir(spread = 0) {
  const d = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(player.pitch, player.yaw, 0, 'YXZ'));
  if (spread) d.add(new THREE.Vector3(rand(-spread, spread), rand(-spread, spread), rand(-spread, spread))).normalize();
  return d;
}

function shoot() {
  const w = WEAPONS[player.weapon];
  if (player.cool > 0 || player.swap > 0 || player.dead || roundState !== 'fight') return;
  if (w.melee) {
    player.cool = w.rate;
    player.recoil = 1;
    sfx('swing');
    ray.set(eye(), aimDir());
    ray.far = w.range;
    const h = ray.intersectObjects(hittable, false)[0];
    if (h && h.object.userData.bot) { damageBot(w.dmg, false); sfx('stab'); impact(h.point, null, true); }
    else if (h) impact(h.point, h.face && h.face.normal.clone().transformDirection(h.object.matrixWorld), false);
    return;
  }
  if (w.grenades) {
    if (player.grenades <= 0) return;
    player.grenades--;
    player.cool = w.rate;
    player.recoil = 1;
    sfx('throw');
    const d = aimDir();
    throwGrenade(eye().addScaledVector(d, 0.6), d.multiplyScalar(17).add(new THREE.Vector3(0, 4, 0)), true);
    updateHud();
    return;
  }
  if (player.reloading > 0) return;
  if (player.ammo[player.weapon] <= 0) { startReload(); return; }
  player.ammo[player.weapon]--;
  player.cool = w.rate;
  player.recoil = 1;
  player.pitch += w.kick * 0.25;
  player.yaw += rand(-1, 1) * w.kick * 0.08;
  sfx(w.sound, 0.6);
  flash.visible = true;
  flash.position.copy(w.model.userData.muzzle).applyMatrix4(w.model.matrix);
  flash.material.rotation = rand(0, Math.PI);
  flashLight.position.copy(eye()).addScaledVector(aimDir(), 1);
  flashLight.intensity = 6;
  const moving = Math.hypot(player.vx || 0, player.vz || 0) > 1;
  const dir = aimDir(w.spread * (moving ? 2.2 : 1) * (player.onGround ? 1 : 3));
  ray.set(eye(), dir);
  ray.far = w.range;
  const h = ray.intersectObjects(hittable, false)[0];
  const end = h ? h.point : eye().addScaledVector(dir, w.range);
  const muzzleWorld = camera.localToWorld(new THREE.Vector3(0.22, -0.16, -0.9));
  tracer(muzzleWorld, end);
  if (h) {
    if (h.object.userData.bot) {
      const head = h.object.userData.part === 'head';
      const falloff = h.distance > 30 ? 0.8 : 1;
      damageBot(w.dmg * (head ? 1.8 : 1) * falloff, head);
      impact(h.point, null, true);
    } else {
      impact(h.point, h.face && h.face.normal.clone().transformDirection(h.object.matrixWorld), false);
    }
  }
  if (player.ammo[player.weapon] === 0) setTimeout(startReload, 150);
  updateHud();
}
function startReload() {
  const w = WEAPONS[player.weapon];
  if (!w.mag || player.reloading > 0 || player.ammo[player.weapon] === w.mag) return;
  player.reloading = w.reload;
  sfx('reload');
  updateHud();
}

// Grenades bounce, then go off.
const grenades = [];
function throwGrenade(pos, vel, mine) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(0.07, 14, 10), olive);
  m.castShadow = true;
  m.position.copy(pos);
  scene.add(m);
  grenades.push({ m, vel, fuse: 1.7, mine });
}
function explode(g) {
  const p = g.m.position;
  scene.remove(g.m);
  sfx('boom', touch ? 0.8 : 1);
  const fire = new THREE.PointLight(0xff8a30, 40, 16, 2);
  fire.position.copy(p).add(new THREE.Vector3(0, 0.5, 0));
  scene.add(fire);
  effects.push({ m: fire, life: 0.25, light: true });
  const ball = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({ color: 0xffb35c, transparent: true, opacity: 0.9 }));
  ball.position.copy(p);
  scene.add(ball);
  effects.push({ m: ball, life: 0.35, grow: 9 });
  for (let i = 0; i < 14; i++) {
    const s = new THREE.Mesh(new THREE.SphereGeometry(rand(0.3, 0.7), 8, 6), new THREE.MeshStandardMaterial({ color: 0x3b3936, transparent: true, opacity: 0.75, roughness: 1, depthWrite: false }));
    s.position.copy(p);
    scene.add(s);
    effects.push({ m: s, v: new THREE.Vector3(rand(-3, 3), rand(1, 4), rand(-3, 3)), life: rand(0.9, 1.6), smoke: true });
  }
  const R = 6.5;
  const hurt = (target, eyeH, fn) => {
    const d = target.distanceTo(p);
    if (d < R && lineOfSight(p.clone().add(new THREE.Vector3(0, 0.3, 0)), target.clone().add(new THREE.Vector3(0, eyeH, 0)))) fn(110 * (1 - d / R) + 10);
  };
  hurt(bot.pos, 1.2, (n) => damageBot(n, false));
  hurt(player.pos, 1.2, (n) => damagePlayer(g.mine ? n * 0.6 : n));
}

// ---------- Bot brain ----------
function botThink(dt) {
  if (bot.dead || roundState !== 'fight') return;
  const head = new THREE.Vector3(bot.pos.x, bot.pos.y + 1.6, bot.pos.z);
  const me = eye();
  const canSee = !player.dead && lineOfSight(head, me);
  bot.see = canSee ? Math.min(bot.see + dt, 2) : Math.max(bot.see - dt * 0.5, 0);
  const toMe = me.clone().sub(head);
  const dist = toMe.length();

  bot.think -= dt;
  if (bot.think <= 0) {
    bot.think = rand(0.8, 2);
    bot.strafe = Math.random() < 0.5 ? -1 : 1;
    if (!canSee || dist > 22) {
      // Move toward where the player is, with some wander.
      bot.goal.set(player.pos.x + rand(-6, 6), 0, player.pos.z + rand(-6, 6));
    } else if (dist < 7) {
      bot.goal.set(bot.pos.x - toMe.x * 0.5 + rand(-3, 3), 0, bot.pos.z - toMe.z * 0.5 + rand(-3, 3));
    } else {
      bot.goal.set(bot.pos.x + rand(-5, 5), 0, bot.pos.z + rand(-5, 5));
    }
    // Sometimes throw a grenade at a hiding player.
    if (!canSee && bot.see > 0 && bot.nades > 0 && dist < 20 && Math.random() < 0.25) {
      bot.nades--;
      const dir = new THREE.Vector3(player.pos.x - bot.pos.x, 0, player.pos.z - bot.pos.z);
      const flat = dir.length();
      dir.normalize().multiplyScalar(Math.min(16, flat * 0.9));
      throwGrenade(head.clone(), dir.add(new THREE.Vector3(0, 5, 0)), false);
      sfx('throw', 0.5);
    }
  }

  // Walk.
  const move = new THREE.Vector3(bot.goal.x - bot.pos.x, 0, bot.goal.z - bot.pos.z);
  if (canSee && dist < 22) {
    const side = new THREE.Vector3(-toMe.z, 0, toMe.x).normalize().multiplyScalar(bot.strafe * 2);
    move.multiplyScalar(0.3).add(side);
  }
  const speed = canSee ? 3.6 : 4.6;
  if (move.length() > 0.3) {
    move.normalize().multiplyScalar(speed * dt);
    const before = bot.pos.clone();
    bot.pos.add(move);
    collide(bot.pos, 0.38);
    if (bot.pos.distanceTo(before) < speed * dt * 0.3) bot.think = 0; // stuck, pick another way
    bot.walk += dt * 9;
  }
  bot.pos.y = groundAt(bot.pos, 0.38, bot.pos.y);

  // Face and shoot.
  const want = canSee ? Math.atan2(-toMe.x, -toMe.z) : Math.atan2(-move.x, -move.z) || bot.yaw;
  let dy = want - bot.yaw;
  while (dy > Math.PI) dy -= Math.PI * 2;
  while (dy < -Math.PI) dy += Math.PI * 2;
  bot.yaw += dy * Math.min(1, dt * 8);
  bot.cool -= dt;
  if (canSee && bot.see > 0.45 && bot.cool <= 0 && Math.abs(dy) < 0.4) {
    bot.cool = rand(0.11, 0.16);
    if (Math.random() < 0.12) bot.cool = rand(0.4, 0.8); // short bursts
    sfx('enemy', Math.max(0.15, 1 - dist / 50));
    const moving = (keys.KeyW || keys.KeyA || keys.KeyS || keys.KeyD || joy.active) ? 1 : 0;
    const chance = Math.max(0.08, 0.42 - dist * 0.008 - moving * 0.12 - (player.onGround ? 0 : 0.15));
    const gun = bot.obj.userData.gun;
    const from = gun.localToWorld(new THREE.Vector3(0, 0, -0.85));
    let to;
    if (Math.random() < chance) {
      damagePlayer(rand(7, 10));
      to = me.clone().add(new THREE.Vector3(rand(-0.2, 0.2), -0.3, rand(-0.2, 0.2)));
    } else {
      to = me.clone().add(new THREE.Vector3(rand(-1.2, 1.2), rand(-0.8, 0.8), rand(-1.2, 1.2)));
      const d = to.clone().sub(from).normalize();
      ray.set(from, d); ray.far = 80;
      const h = ray.intersectObjects(hittable, false).find((x) => !x.object.userData.bot);
      if (h) { to = h.point; impact(h.point, h.face && h.face.normal.clone().transformDirection(h.object.matrixWorld), false); }
    }
    tracer(from, to);
    flashLight.position.copy(from);
    flashLight.intensity = 4;
  }
}

function poseBot(dt) {
  const o = bot.obj, p = o.userData.parts;
  o.position.copy(bot.pos);
  o.rotation.y = bot.yaw;
  const s = Math.sin(bot.walk) * 0.5;
  p.legL.rotation.x = s;
  p.legR.rotation.x = -s;
  if (bot.dead) {
    o.rotation.x = Math.max(o.rotation.x - dt * 4, -Math.PI / 2);
    o.position.y = 0.15;
  } else o.rotation.x = 0;
}

// ---------- Rounds ----------
const SPAWN_ME = new THREE.Vector3(0, 0, 18.5), SPAWN_BOT = new THREE.Vector3(0, 0, -18.5);
function startRound() {
  player.pos.copy(SPAWN_ME);
  player.pos.x = rand(-8, 8);
  player.vy = 0;
  player.yaw = 0;
  player.pitch = 0;
  player.hp = 100;
  player.dead = false;
  resetLoadout();
  bot.pos.copy(SPAWN_BOT);
  bot.pos.x = rand(-8, 8);
  bot.yaw = Math.PI;
  bot.hp = 100;
  bot.dead = false;
  bot.see = 0;
  bot.nades = 1;
  bot.think = 0;
  bot.obj.rotation.x = 0;
  for (const g of grenades.splice(0)) scene.remove(g.m);
  roundState = 'countdown';
  roundTimer = 2.5;
  const n = score.you + score.them + 1;
  banner(`ROUND ${n}`, score.you === 4 && score.them === 4 ? 'Final round!' : 'Get ready', 2.3);
  updateHud();
}
function endRound(won) {
  roundState = 'over';
  roundTimer = 2.8;
  if (score.you >= 5 || score.them >= 5) {
    roundState = 'match';
    roundTimer = 4.5;
    banner(score.you >= 5 ? 'YOU WIN! 🏆' : 'DEFEAT', `${score.you} – ${score.them}`, 4.4);
  } else {
    banner(won ? 'ROUND WON' : 'ROUND LOST', `${score.you} – ${score.them}`, 2.6);
  }
  updateHud();
}

// ---------- Input ----------
const canvas = renderer.domElement;
let pointerLocked = false;
document.addEventListener('pointerlockchange', () => { pointerLocked = document.pointerLockElement === canvas; });
addEventListener('keydown', (e) => {
  keys[e.code] = true;
  if (!started) return;
  if (e.code === 'Enter' || e.code === 'NumpadEnter') { firing = true; shoot(); e.preventDefault(); }
  if (e.code === 'KeyR' && !e.repeat) nextWeapon();
  if (/^Digit[1-4]$/.test(e.code)) selectWeapon(+e.code.slice(5) - 1);
  if (e.code === 'Space') e.preventDefault();
});
addEventListener('keyup', (e) => {
  keys[e.code] = false;
  if (e.code === 'Enter' || e.code === 'NumpadEnter') firing = false;
});
canvas.addEventListener('mousedown', (e) => {
  if (!started || touch) return;
  if (!pointerLocked) { canvas.requestPointerLock?.(); return; }
  if (e.button === 0) { firing = true; shoot(); }
});
addEventListener('mouseup', () => { if (!touch) firing = false; });
addEventListener('mousemove', (e) => {
  if (!pointerLocked) return;
  player.yaw -= e.movementX * 0.0022;
  player.pitch -= e.movementY * 0.0022;
});
addEventListener('wheel', (e) => { if (started) selectWeapon((player.weapon + (e.deltaY > 0 ? 1 : 3)) % 4); });

// Touch: left stick to move, drag on the right to look, tap to shoot.
const joy = { active: false, id: null, x: 0, y: 0, ox: 0, oy: 0 };
const looks = new Map();
const joyEl = $('joy'), knob = joyEl.querySelector('.knob');
let jumpPressed = false;
$('jump').addEventListener('touchstart', (e) => { e.preventDefault(); e.stopPropagation(); jumpPressed = true; }, { passive: false });
addEventListener('touchstart', (e) => {
  if (!started) return;
  for (const t of e.changedTouches) {
    const r = joyEl.getBoundingClientRect();
    if (!joy.active && t.clientX < innerWidth * 0.4 && t.clientY > innerHeight * 0.35) {
      joy.active = true; joy.id = t.identifier;
      joy.ox = r.left + r.width / 2; joy.oy = r.top + r.height / 2;
      joy.x = joy.y = 0;
    } else {
      looks.set(t.identifier, { x: t.clientX, y: t.clientY, sx: t.clientX, sy: t.clientY, t: performance.now(), moved: 0 });
    }
  }
  e.preventDefault();
}, { passive: false });
addEventListener('touchmove', (e) => {
  for (const t of e.changedTouches) {
    if (joy.active && t.identifier === joy.id) {
      let dx = t.clientX - joy.ox, dy = t.clientY - joy.oy;
      const l = Math.hypot(dx, dy), max = 50;
      if (l > max) { dx *= max / l; dy *= max / l; }
      joy.x = dx / max; joy.y = dy / max;
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
    } else if (looks.has(t.identifier)) {
      const L = looks.get(t.identifier);
      player.yaw -= (t.clientX - L.x) * 0.006;
      player.pitch -= (t.clientY - L.y) * 0.006;
      L.moved += Math.abs(t.clientX - L.x) + Math.abs(t.clientY - L.y);
      L.x = t.clientX; L.y = t.clientY;
    }
  }
  e.preventDefault();
}, { passive: false });
function touchEnd(e) {
  for (const t of e.changedTouches) {
    if (joy.active && t.identifier === joy.id) {
      joy.active = false; joy.x = joy.y = 0;
      knob.style.transform = '';
    } else if (looks.has(t.identifier)) {
      const L = looks.get(t.identifier);
      looks.delete(t.identifier);
      // A quick tap shoots.
      if (L.moved < 14 && performance.now() - L.t < 300) shoot();
    }
  }
}
addEventListener('touchend', touchEnd);
addEventListener('touchcancel', touchEnd);

$('keys').textContent = touch
  ? 'Left stick to move · Drag to look · TAP the screen to shoot · Tap a weapon to switch'
  : 'WASD move · Mouse look · ENTER or click to shoot · R switch weapon · 1–4 pick weapon · Space jump · Shift sprint';

$('play').addEventListener('click', () => {
  audio = audio || new (window.AudioContext || window.webkitAudioContext)();
  audio.resume?.();
  $('menu').style.display = 'none';
  started = true;
  score.you = score.them = 0;
  player.weapon = 0;
  WEAPONS.forEach((w, k) => (w.model.visible = k === 0));
  startRound();
  if (!touch) canvas.requestPointerLock?.();
});

// ---------- Main loop ----------
let last = performance.now();
let stepTimer = 0;
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;

  if (started) {
    // Round flow.
    if (roundState === 'countdown') { roundTimer -= dt; if (roundTimer <= 0) { roundState = 'fight'; banner('FIGHT!', '', 0.8); } }
    else if (roundState === 'over') { roundTimer -= dt; if (roundTimer <= 0) startRound(); }
    else if (roundState === 'match') {
      roundTimer -= dt;
      if (roundTimer <= 0) {
        started = false;
        roundState = 'idle';
        $('menu').style.display = 'flex';
        $('play').textContent = 'PLAY AGAIN';
        document.exitPointerLock?.();
      }
    }

    // Move.
    player.pitch = Math.max(-1.45, Math.min(1.45, player.pitch));
    let fx = 0, fz = 0;
    if (!player.dead && roundState !== 'countdown') {
      if (keys.KeyW || keys.ArrowUp) fz -= 1;
      if (keys.KeyS || keys.ArrowDown) fz += 1;
      if (keys.KeyA || keys.ArrowLeft) fx -= 1;
      if (keys.KeyD || keys.ArrowRight) fx += 1;
      if (joy.active) { fx += joy.x; fz += joy.y; }
    }
    const len = Math.hypot(fx, fz);
    if (len > 1) { fx /= len; fz /= len; }
    const sprint = keys.ShiftLeft || keys.ShiftRight || (joy.active && Math.hypot(joy.x, joy.y) > 0.95);
    const speed = (sprint ? 7.2 : 5) * (WEAPONS[player.weapon].melee ? 1.15 : 1);
    const sin = Math.sin(player.yaw), cos = Math.cos(player.yaw);
    player.vx = (fx * cos + fz * sin) * speed;
    player.vz = (-fx * sin + fz * cos) * speed;
    player.pos.x += player.vx * dt;
    player.pos.z += player.vz * dt;
    collide(player.pos, RADIUS, player.pos.y);
    const ground = groundAt(player.pos, RADIUS, player.pos.y);
    if ((keys.Space || jumpPressed) && player.onGround && !player.dead) { player.vy = 6.2; player.onGround = false; }
    jumpPressed = false;
    player.vy -= 18 * dt;
    player.pos.y += player.vy * dt;
    if (player.pos.y <= ground) { player.pos.y = ground; player.vy = 0; player.onGround = true; }
    else if (player.pos.y > ground + 0.05) player.onGround = false;
    const moving = len > 0.1 && player.onGround;
    if (moving) {
      player.bob += dt * speed * 1.6;
      stepTimer -= dt * speed;
      if (stepTimer <= 0) { stepTimer = 2.6; sfx('step', 0.5); }
    }

    // Shooting.
    player.cool -= dt;
    player.swap = Math.max(0, player.swap - dt);
    if (player.reloading > 0) {
      player.reloading -= dt;
      if (player.reloading <= 0) { player.reloading = 0; player.ammo[player.weapon] = WEAPONS[player.weapon].mag; updateHud(); }
    }
    if (firing && WEAPONS[player.weapon].auto) shoot();

    botThink(dt);
    poseBot(dt);

    // Grenades.
    for (let i = grenades.length - 1; i >= 0; i--) {
      const g = grenades[i];
      g.vel.y -= 18 * dt;
      const next = g.m.position.clone().addScaledVector(g.vel, dt);
      const probe = { x: next.x, z: next.z };
      collide(probe, 0.07, next.y);
      if (probe.x !== next.x) g.vel.x *= -0.5;
      if (probe.z !== next.z) g.vel.z *= -0.5;
      next.x = probe.x; next.z = probe.z;
      const gy = groundAt(next, 0.07, g.m.position.y) + 0.07;
      if (next.y < gy) { next.y = gy; g.vel.y = Math.abs(g.vel.y) * 0.35; g.vel.x *= 0.7; g.vel.z *= 0.7; }
      g.m.position.copy(next);
      g.m.rotation.x += dt * 8;
      g.fuse -= dt;
      if (g.fuse <= 0) { grenades.splice(i, 1); explode(g); }
    }
  }

  // Camera.
  camera.position.set(player.pos.x, player.pos.y + EYE + Math.sin(player.bob * 2) * 0.035, player.pos.z);
  camera.rotation.set(player.pitch, player.yaw, Math.sin(player.bob) * 0.006);
  if (!started && roundState === 'idle') {
    // Slow fly-over behind the menu.
    const t = now / 1000;
    camera.position.set(Math.sin(t * 0.08) * 26, 9, Math.cos(t * 0.08) * 26);
    camera.lookAt(0, 1, 0);
  }

  // Gun sway, recoil and switching.
  player.recoil = Math.max(0, player.recoil - dt * 9);
  const w = WEAPONS[player.weapon];
  const r = player.recoil;
  holder.position.set(
    HOLD.x + Math.sin(player.bob) * 0.012,
    HOLD.y + Math.abs(Math.cos(player.bob)) * 0.012 - player.swap * 0.9 - (player.reloading > 0 ? 0.08 : 0),
    HOLD.z + (w.melee ? -r * 0.25 : r * 0.06),
  );
  holder.rotation.set(
    (w.melee ? -r * 0.6 : r * 0.12) + (player.reloading > 0 ? -0.5 : 0),
    w.melee ? r * 0.5 : 0,
    player.reloading > 0 ? 0.4 : 0,
  );
  holder.visible = started && !player.dead;
  if (flash.visible && player.recoil < 0.6) flash.visible = false;
  flashLight.intensity = Math.max(0, flashLight.intensity - dt * 80);

  // Effects.
  for (let i = effects.length - 1; i >= 0; i--) {
    const e = effects[i];
    e.life -= dt;
    if (e.v) { e.m.position.addScaledVector(e.v, dt); if (e.grav) e.v.y -= e.grav * dt; }
    if (e.grow) { const s = e.m.scale.x + e.grow * dt; e.m.scale.setScalar(s); e.m.material.opacity = Math.max(0, e.life * 2.5); }
    if (e.smoke) { e.m.scale.multiplyScalar(1 + dt * 1.2); e.m.material.opacity = Math.max(0, e.life * 0.5); e.v.multiplyScalar(1 - dt * 2); }
    if (e.fade) e.m.material.opacity = Math.max(0, e.life * 12);
    if (e.light) e.m.intensity = Math.max(0, e.life * 160);
    if (e.life <= 0) { scene.remove(e.m); effects.splice(i, 1); }
  }

  if (hitTimer > 0) { hitTimer -= dt; if (hitTimer <= 0) $('hit').style.opacity = 0; }
  if (bannerTimer > 0) { bannerTimer -= dt; if (bannerTimer <= 0) $('banner').style.opacity = 0; }

  renderer.clear();
  renderer.render(scene, camera);
  renderer.clearDepth();
  if (holder.visible) renderer.render(viewScene, viewCam);
  requestAnimationFrame(frame);
}
updateHud();
requestAnimationFrame(frame);

// For automated checks.
window.__rivals = { player, bot, score, shoot, selectWeapon, get round() { return roundState; }, skip() { roundTimer = 0; } };
