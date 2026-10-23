import type { PublicProfile } from './types';

export type TournamentMetric = 'shots' | 'cards' | 'classic' | 'mixed';
export type TournamentSummary = { id: string; name: string };
export type TournamentOption = 'home' | 'draw' | 'away';
export const tournamentOptions: { id: TournamentOption; label: string }[] = [
  { id: 'home', label: 'Casa' }, { id: 'draw', label: 'Empate' }, { id: 'away', label: 'Fora' },
];
const classicTournamentOptions = tournamentOptions.map(option => ({ ...option, label: option.id === 'draw' ? 'X' : option.label }));
export const tournamentOptionsFor = (metric?: TournamentMetric, game?: Pick<TournamentPrediction, 'options'> | null) => game?.options ?? (metric === 'classic' ? classicTournamentOptions : tournamentOptions);
export type TournamentPrediction = {
  slot: number; dayId: string; title: string; homeTeam: string; awayTeam: string; competition: string;
  closesAt: string; status: 'open' | 'settled'; winningOptionId: TournamentOption | null;
  homeShots: number | null; awayShots: number | null; myOptionId: TournamentOption | null;
  myResult: 'correct' | 'incorrect' | null;
  options?: { id: TournamentOption; label: string }[] | null;
  rules?: string | null;
};
export type TournamentPlayer = PublicProfile & { position: number; correctAnswers: number };
export type FinishingTournamentState = {
  id: string; name: string; startsAt: string; endsAt: string; entryCents: number; prizeCents: number;
  metric?: TournamentMetric; availableTournaments?: TournamentSummary[]; matchDays?: string[]; predictionsPublished?: boolean;
  predictionCount: number; serverTime: number; clientReceivedAt?: number; enrolled: boolean; registrationOpen: boolean;
  participants: number; winners?: TournamentPlayer[]; players: TournamentPlayer[]; ownRank: TournamentPlayer | null; predictions: TournamentPrediction[];
};
export type AdminFinishingTournamentState = { id: string; name: string; metric?: TournamentMetric; availableTournaments?: TournamentSummary[]; matchDays?: string[]; serverTime: number; predictions: TournamentPrediction[] };
export const tournamentTime = (value: string) => new Date(value).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', timeZone: 'America/Sao_Paulo' });
export const tournamentDay = (day: string) => new Date(`${day}T12:00:00-03:00`).toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: '2-digit', timeZone: 'America/Sao_Paulo' }).replace('-feira', '');
