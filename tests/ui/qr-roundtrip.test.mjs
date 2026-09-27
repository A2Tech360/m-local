import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

// Uses the exact runtime-installed libraries; run setup/build before this test.
const require = createRequire(fileURLToPath(new URL('../../.jac/client/package.json', import.meta.url)));
const React = require('react');
const {renderToStaticMarkup} = require('react-dom/server');
const {QRCodeSVG} = require('qrcode.react');
const {RGBLuminanceSource, BinaryBitmap, HybridBinarizer, QRCodeReader} = require('@zxing/library');

test('qrcode.react QRCodeSVG pixels decode with the ZXing reader', () => {
  const payload = 'mlocal:v1:' + Buffer.from(Array.from({length:32},(_,i)=>i*7%256)).toString('base64url');
  const svg = renderToStaticMarkup(React.createElement(QRCodeSVG, {value:payload,size:240,level:'M',marginSize:4}));
  const modules = Number(svg.match(/viewBox="0 0 (\d+) \d+"/)[1]);
  const path = svg.match(/fill="#000000" d="([^"]+)"/)[1];
  // QRCodeSVG emits horizontal unit-height black rectangles. Rasterize those
  // actual SVG paths, preserving its four-module quiet zone, without a DOM mock.
  const rects = [...path.matchAll(/M(\d+)[ ,]+(\d+)\s*h(\d+)v1H\d+z/g)];
  assert.ok(rects.length > 50);
  assert.equal(rects.map(r=>r[0]).join('').replace(/\s/g,''),path.replace(/\s/g,''), 'all emitted paths must be understood');
  const scale = 6, size = modules*scale, pixels = new Uint8ClampedArray(size*size).fill(255);
  for (const rect of rects) {
    const x=Number(rect[1])*scale,y=Number(rect[2])*scale,width=Number(rect[3])*scale;
    for(let row=y;row<y+scale;row++) pixels.fill(0,row*size+x,row*size+x+width);
  }
  const bitmap = new BinaryBitmap(new HybridBinarizer(new RGBLuminanceSource(pixels,size,size)));
  assert.equal(new QRCodeReader().decode(bitmap).getText(),payload);
});
