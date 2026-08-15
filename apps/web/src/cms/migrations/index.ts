import * as migration_20260812_011606 from './20260812_011606';
import * as migration_20260812_225138 from './20260812_225138';

export const migrations = [
  {
    up: migration_20260812_011606.up,
    down: migration_20260812_011606.down,
    name: '20260812_011606',
  },
  {
    up: migration_20260812_225138.up,
    down: migration_20260812_225138.down,
    name: '20260812_225138'
  },
];
