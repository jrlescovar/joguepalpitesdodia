import {describe,expect,it} from 'vitest';
import {arenaWeekOpening} from '../src/arenaSchedule';

describe('Coroa da Semana opening by the server Brasilia day',()=>{
 it.each(['2026-10-05','2026-10-06','2026-10-07','2026-10-08','2026-10-12'])(
  'opens Melhores 8 on qualifying day %s',day=>{
   expect(arenaWeekOpening(day)).toEqual({view:'standings',stage:0});
  });
 it.each([
  ['2026-10-09',0],['2026-10-10',1],['2026-10-11',2],
  ['2026-10-16',0],['2026-10-17',1],['2026-10-18',2],
 ] as const)('opens the knockout stage for %s', (day,stage)=>{
  expect(arenaWeekOpening(day)).toEqual({view:'bracket',stage});
 });
});
