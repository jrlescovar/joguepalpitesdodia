export const OWNER_EMAIL = 'admin@example.invalid';
export const COLORS = ['#3b82f6', '#22c55e', '#ec4899', '#a855f7', '#ef4444', '#f97316', '#eab308'];
export const RESERVED = new Set(['admin','administrador','suporte','support','firebase','apostadodia','moderador','root','system','oficial']);
export function validUsername(name: unknown): name is string {
  return typeof name === 'string' && /^[a-zA-Z0-9_]{3,12}$/.test(name) && !RESERVED.has(name.toLowerCase());
}
export function dayAt(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone:'America/Sao_Paulo', year:'numeric', month:'2-digit', day:'2-digit' }).formatToParts(date);
  const get = (type: string) => parts.find(p => p.type === type)!.value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
export function previousDay(day: string): string {
  const date = new Date(`${day}T12:00:00Z`); date.setUTCDate(date.getUTCDate()-1); return date.toISOString().slice(0,10);
}
export function xpAfter(level: number, xp: number, reward: number) {
  let nextLevel = level; let nextXp = xp + reward;
  while (nextXp >= nextLevel * 15) { nextXp -= nextLevel * 15; nextLevel += 1; }
  return {level:nextLevel, xp:nextXp};
}
export function dailyAfter(lastPrediction: string|null, previousPrediction: string|null, current: number, max: number, day: string) {
  const next = lastPrediction !== null && lastPrediction === previousPrediction ? current + 1 : 1;
  return {dailyStreakCurrent:next, dailyStreakMax:Math.max(max,next),lastPlayedDate:day};
}
export function visibleDaily(current: number, lastPrediction: string|null|undefined, lastClosedPrediction: string|null) {
  return lastClosedPrediction === null || (lastPrediction !== null && lastPrediction !== undefined && lastPrediction >= lastClosedPrediction) ? current : 0;
}
export function firstPlayableGameIndex(games: { status: string; closesAt: { toMillis(): number } }[], now: number): number {
  const index = games.findIndex(game => game.status === 'open' && game.closesAt.toMillis() > now);
  return index >= 0 ? index : 0;
}
export const GREEN_MEDAL_THRESHOLDS = [1, 10, 25, 50, 100] as const;
export function hitRate(greens: number, reds: number | undefined): number | null {
  if (typeof reds !== 'number' || greens + reds === 0) return null;
  return Math.round(greens / (greens + reds) * 100);
}
export function greenMedalProgress(greens: number) {
  const level = GREEN_MEDAL_THRESHOLDS.filter(threshold => greens >= threshold).length;
  const next = GREEN_MEDAL_THRESHOLDS[level] ?? null;
  return {
    level,
    next,
    remaining: next === null ? 0 : next - greens,
    percent: next === null ? 100 : Math.min(100, Math.round(greens / next * 100)),
  };
}
export const SEASON_END_DAY = '2026-10-11';
export const SEASON_END_AT = '2026-10-12T02:59:59Z';
export function seasonTimeRemaining(now: Date) {
  const seconds = Math.max(0,Math.floor((Date.parse(SEASON_END_AT)-now.getTime())/1000));
  return {days:Math.floor(seconds/86400),hours:Math.floor(seconds%86400/3600),minutes:Math.floor(seconds%3600/60),seconds:seconds%60};
}
export function seasonDaysRemaining(now: Date): number {
  const today = Date.parse(`${dayAt(now)}T12:00:00Z`);
  const end = Date.parse(`${SEASON_END_DAY}T12:00:00Z`);
  return Math.max(0, Math.round((end - today) / 86400000));
}
export function resultAfter(profile: {level:number;xp:number;green:number;red:number;greenStreakCurrent:number;greenStreakMax:number}, won:boolean) {
  const streak = won ? profile.greenStreakCurrent+1 : 0;
  return {...xpAfter(profile.level,profile.xp,won ? 25 : 0),green:profile.green+(won ? 1 : 0),red:profile.red+(won ? 0 : 1),greenStreakCurrent:streak,greenStreakMax:Math.max(profile.greenStreakMax,streak)};
}
