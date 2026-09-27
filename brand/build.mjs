// derives every kru brand file from the hand-drawn masters in this directory.
// run from the repo root: node brand/build.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const dir = dirname(fileURLToPath(import.meta.url));
const read = (f) => readFileSync(join(dir, f), 'utf8');
const inner = (f) => read(f).replace(/^\s*<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const write = (f, s) => writeFileSync(join(dir, f), s.trim() + '\n');
const paint = (s, c) => s.replaceAll('currentColor', c);

const INK = '#16181D';
const LIGHT = '#F7F6F2';

const mark = inner('kru-mark.svg');
const tile = inner('kru-tile.svg');
const word = inner('kru-wordmark.svg');
const tagline = inner('kru-tagline.svg');

// mark in fixed colours: -light sits on light ground, -dark on dark ground
write('kru-mark-light.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">${paint(mark, INK)}</svg>`);
write('kru-mark-dark.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">${paint(mark, LIGHT)}</svg>`);

// horizontal lockup: mark height = ascender top (y4) to baseline (y28)
const WORD_X = 30.8;
const markInLockup = `<g transform="translate(-2.4 3.2) scale(0.8)">${mark}</g>`;
const wordInLockup = `<g transform="translate(${WORD_X} 0)">${word}</g>`;
write('kru-lockup.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 81.8 32">${markInLockup}${wordInLockup}</svg>`);

// readme header: the lime tile in place of the bare mark, same 24-unit height
const tileInLockup = `<g transform="translate(0 4) scale(0.75)">${tile}</g>`;
const header = (c) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="246" height="96" viewBox="-0.1 0 82 32">${tileInLockup}${paint(wordInLockup, c)}</svg>`;
write('kru-header-light.svg', header(INK));
write('kru-header-dark.svg', header(LIGHT));

// social preview 1280x640: tile lockup + tagline on a flat ink field
const S = 7; // lockup units -> px
const LEFT = 112;
const TOP = 184; // tile top edge
const lockupY = TOP - 4 * S;
const baseline = lockupY + 28 * S;
const tagSize = 40; // px; tagline paths are drawn at 100
const tagBaseline = baseline + 64 + Math.round(0.728 * tagSize);
const social = `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="640" viewBox="0 0 1280 640">
<rect width="1280" height="640" fill="${INK}"/>
<g transform="translate(${LEFT} ${lockupY}) scale(${S})">${tileInLockup}${paint(wordInLockup, LIGHT)}</g>
<g transform="translate(${LEFT} ${tagBaseline}) scale(${tagSize / 100})">${paint(tagline, LIGHT)}</g>
</svg>`;
await sharp(Buffer.from(social)).png({ compressionLevel: 9 }).toFile(join(dir, 'kru-social-preview.png'));

// square mark, tile version
await sharp(Buffer.from(read('kru-tile.svg')), { density: (72 * 512) / 32 })
  .resize(512, 512)
  .png({ compressionLevel: 9 })
  .toFile(join(dir, 'kru-mark-512.png'));
