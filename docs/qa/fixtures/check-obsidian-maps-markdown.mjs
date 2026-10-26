// Run with a bundled, unchanged 0.7.15 markdown-parser module as argv[2].
// See the accompanying QA record for the release revision and build command.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const parserURL = pathToFileURL(resolve(process.argv[2])).href;
const { parseExportMarkdown } = await import(parserURL);
const sampleURL = new URL('../../../marketing/public/samples/synthetic-obsidian-export.md', import.meta.url);
const bytes = readFileSync(sampleURL);
const source = bytes.toString('utf8');
assert.equal(createHash('sha256').update(bytes).digest('hex'),
  '2d8798387dfebaaa479a6c961895c85aa8ad54f61c2e86d27d45006d6e487220');
const parsed = parseExportMarkdown(source);
assert.equal(parsed.visits.length, 2);
assert.equal(parsed.points, null);
assert.deepEqual(parsed.visits.map(v => [v.latitude, v.longitude]), [[0, 0], [0.0002, 0.0001]]);
assert.deepEqual(parsed.visits.map(v => v.locationName), ['Synthetic stop A', 'Synthetic stop B']);
assert.deepEqual(parsed.visits.map(v => v.durationMinutes), [15, 15]);
assert.ok(parsed.visits.every(v => v.notes === 'Invented documentation example; not a real visit.'));

// A derived negative control, not a new native app export.
const noCoordinates = source.split('\n').map(line => {
  if (!line.startsWith('|')) return line;
  const cells = line.split('|');
  cells.splice(4, 2);
  return cells.join('|');
}).join('\n');
assert.equal(parseExportMarkdown(noCoordinates).visits.length, 0);

const readInTimezone = tz => JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e',
  `import {readFileSync} from 'node:fs';
   import {parseExportMarkdown} from ${JSON.stringify(parserURL)};
   console.log(JSON.stringify(parseExportMarkdown(readFileSync(${JSON.stringify(sampleURL.pathname)},'utf8'))));`],
  { env: { ...process.env, TZ: tz }, encoding: 'utf8' }));
const utc = readInTimezone('UTC');
const puertoRico = readInTimezone('America/Puerto_Rico');
assert.equal(utc.visits[0].arrivedAt, '2000-01-01T11:45:00.000Z');
assert.equal(puertoRico.visits[0].arrivedAt, '2000-01-01T15:45:00.000Z');
assert.deepEqual(utc.visits.map(v => [v.latitude, v.longitude]),
  puertoRico.visits.map(v => [v.latitude, v.longitude]));
console.log(JSON.stringify({
  sample_sha256: createHash('sha256').update(bytes).digest('hex'),
  parsed_visits: parsed.visits.length, parsed_points: parsed.points,
  coordinates: parsed.visits.map(v => [v.latitude, v.longitude]),
  no_coordinate_control_visits: 0,
  first_arrival_when_host_utc: utc.visits[0].arrivedAt,
  first_arrival_when_host_puerto_rico: puertoRico.visits[0].arrivedAt,
  scope: 'Released parser only; not Obsidian plugin rendering, mobile, or scheduled delivery.'
}, null, 2));
