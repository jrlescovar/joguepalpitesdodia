import { describe,it,expect } from 'vitest';
import { xpAfter,dayAt,previousDay,dailyAfter,visibleDaily,resultAfter,validUsername,seasonDaysRemaining,hitRate,greenMedalProgress,firstPlayableGameIndex } from '../src/domain';
describe('regras do jogo',()=>{
  it('primeiro green chega ao nível 2 com 10/30 XP',()=>expect(xpAfter(1,0,25)).toEqual({level:2,xp:10}));
  it('transfere XP por vários níveis',()=>expect(xpAfter(1,0,100)).toEqual({level:4,xp:10}));
  it('não dá XP a um red e interrompe somente a sequência de greens',()=>expect(resultAfter({level:2,xp:10,green:1,red:0,greenStreakCurrent:1,greenStreakMax:1},false)).toEqual({level:2,xp:10,green:1,red:1,greenStreakCurrent:0,greenStreakMax:1}));
  it('usa o calendário de Brasília na virada de UTC',()=>{expect(dayAt(new Date('2026-09-22T02:59:59Z'))).toBe('2026-09-21');expect(dayAt(new Date('2026-09-22T03:00:00Z'))).toBe('2026-09-22');});
  it('trata meses, anos e dias bissextos',()=>{expect(previousDay('2028-03-01')).toBe('2028-02-29');expect(previousDay('2027-01-01')).toBe('2026-12-31');});
  it('conta somente palpites principais em dias corridos',()=>{
    expect(dailyAfter('2026-09-21',1,1,'2026-09-22')).toEqual({dailyStreakCurrent:2,dailyStreakMax:2,lastPlayedDate:'2026-09-22'});
    expect(dailyAfter('2026-09-21',1,1,'2026-09-23')).toEqual({dailyStreakCurrent:1,dailyStreakMax:1,lastPlayedDate:'2026-09-23'});
    expect(dailyAfter('2026-09-22',2,2,'2026-09-24')).toEqual({dailyStreakCurrent:1,dailyStreakMax:2,lastPlayedDate:'2026-09-24'});
  });
  it('zera a sequência visível após um dia perdido ou o prazo de hoje',()=>{
    expect(visibleDaily(2,'2026-09-22','2026-09-22','2026-09-23')).toBe(2);
    expect(visibleDaily(2,'2026-09-21','2026-09-21','2026-09-23')).toBe(0);
    expect(visibleDaily(2,'2026-09-22','2026-09-23','2026-09-23')).toBe(0);
    expect(visibleDaily(1,'2026-09-23','2026-09-23','2026-09-23')).toBe(1);
  });
  it('mostra 19 dias em 22 de setembro até o fim da temporada',()=>{
    expect(seasonDaysRemaining(new Date('2026-09-22T15:00:00Z'))).toBe(19);
    expect(seasonDaysRemaining(new Date('2026-10-11T15:00:00Z'))).toBe(0);
    expect(seasonDaysRemaining(new Date('2026-10-12T15:00:00Z'))).toBe(0);
  });
  it('valida comprimento, caracteres e nomes reservados',()=>{for(const n of ['ab','nome-muito-longo','João','a b','ADMIN','suporte','a'.repeat(13)]) expect(validUsername(n)).toBe(false);for(const n of ['AbC','joao_1','a'.repeat(12)]) expect(validUsername(n)).toBe(true);});
  it('calcula acertos apenas sobre palpites resolvidos',()=>{expect(hitRate(1,1)).toBe(50);expect(hitRate(2,1)).toBe(67);expect(hitRate(0,0)).toBeNull();expect(hitRate(1,undefined)).toBeNull();});
  it('desbloqueia e evolui a medalha de Greens nos cinco marcos',()=>{
    for (const [greens,level,next] of [[0,0,1],[1,1,10],[9,1,10],[10,2,25],[25,3,50],[50,4,100],[100,5,null],[150,5,null]] as const) {
      const medal=greenMedalProgress(greens);
      expect([medal.level,medal.next]).toEqual([level,next]);
    }
  });
  it('abre o carrossel na primeira aposta que ainda aceita palpites',()=>{
    const at=(time:number)=>({toMillis:()=>time});
    expect(firstPlayableGameIndex([
      {status:'settled',closesAt:at(100)},
      {status:'open',closesAt:at(100)},
      {status:'open',closesAt:at(300)},
      {status:'open',closesAt:at(400)},
    ],200)).toBe(2);
    expect(firstPlayableGameIndex([{status:'settled',closesAt:at(100)}],200)).toBe(0);
  });
  it('abre no jogo sem resultado quando todos os prazos fecharam',()=>{
    const at=(time:number)=>({toMillis:()=>time});
    expect(firstPlayableGameIndex([
      {status:'settled',closesAt:at(100)},
      {status:'settled',closesAt:at(100)},
      {status:'open',closesAt:at(100)},
    ],200)).toBe(2);
    expect(firstPlayableGameIndex([
      {status:'settled',closesAt:at(100)},
      {status:'settling',closesAt:at(100)},
    ],200)).toBe(1);
    expect(firstPlayableGameIndex([],200)).toBe(0);
  });
});
