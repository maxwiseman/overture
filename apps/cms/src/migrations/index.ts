import * as migration_20260812_011606 from './20260812_011606';

export const migrations = [
  {
    up: migration_20260812_011606.up,
    down: migration_20260812_011606.down,
    name: '20260812_011606'
  },
];
