import { createClient, type User } from '@supabase/supabase-js';
import type { Pick, Prediction } from './types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'placeholder-key';
export const backendConfigured = Boolean(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY);

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
});

export type AppUser = { uid: string; email: string | null; raw: User };
export function toAppUser(user: User): AppUser { return { uid: user.id, email: user.email ?? null, raw: user }; }

export async function login() {
  if (!backendConfigured) throw Object.assign(new Error('Conecte o projeto Supabase para concluir a migração.'), { code: 'app/not-configured' });
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: `${location.origin}/`, queryParams: { prompt: 'select_account' } },
  });
  if (error) throw error;
}

export async function logout() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export class AppTimestamp {
  constructor(private readonly value: string) {}
  toMillis() { return Date.parse(this.value); }
  toDate() { return new Date(this.value); }
}

function prediction(value: unknown): Prediction | null {
  if (!value || typeof value !== 'object') return null;
  const row = value as Record<string, unknown>;
  return {
    dayId: String(row.dayId), slot: Number(row.slot ?? 0), title: String(row.title), description: String(row.description ?? ''),
    options: row.options as Prediction['options'], closesAt: new AppTimestamp(String(row.closesAt)),
    status: row.status as Prediction['status'],
    ...(row.winningOptionId ? { winningOptionId: String(row.winningOptionId) } : {}),
    ...(row.myPickStatus === 'green' || row.myPickStatus === 'red' ? { myPickStatus: row.myPickStatus } : {}),
  };
}

function predictions(value: unknown): Prediction[] {
  return Array.isArray(value) ? value.map(prediction).filter((item): item is Prediction => Boolean(item)) : [];
}

let currentPredictionsRequest: Promise<Prediction[]> | null = null;
function currentPredictions(): Promise<Prediction[]> {
  if (currentPredictionsRequest) return currentPredictionsRequest;
  const request = rpc<unknown>('get_current_predictions').then(predictions);
  currentPredictionsRequest = request;
  const clear = () => { if (currentPredictionsRequest === request) currentPredictionsRequest = null; };
  void request.then(clear, clear);
  return request;
}

async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  if (!backendConfigured) throw Object.assign(new Error('Conecte o projeto Supabase para concluir a migração.'), { code: 'app/not-configured' });
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw error;
  return data as T;
}

export async function call<T = unknown>(name: string, payload: unknown = {}): Promise<T> {
  const data = payload as Record<string, unknown>;
  switch (name) {
    case 'getPlayerBootstrap': return rpc<T>('get_player_bootstrap');
    case 'getSession': return rpc<T>('get_session');
    case 'getProfile': return rpc<T>('get_or_claim_profile');
    case 'createAccount': return rpc<T>('claim_or_create_profile', { p_username: data.username, p_avatar_color: data.avatarColor });
    case 'checkUsername': return rpc<T>('check_username', { p_username: data.username });
    case 'updateProfile': return rpc<T>('update_profile_with_avatar', { p_username: data.username, p_avatar_color: data.avatarColor, p_use_google_avatar: data.useGoogleAvatar });
    case 'getCurrentPredictions': return currentPredictions() as T;
    case 'getRecentResults': return predictions(await rpc('get_recent_results')) as T;
    case 'getPick': return rpc<T>('get_pick_for_game', { p_day_id: data.dayId, p_slot: data.slot });
    case 'getPicksForDay': return rpc<T>('get_picks_for_day', { p_day_id: data.dayId });
    case 'getLastClosedPrediction': return rpc<T>('get_last_closed_prediction');
    case 'submitPick': return rpc<T>('submit_pick_for_game', { p_day_id: data.dayId, p_slot: data.slot, p_option_id: data.optionId });
    case 'getRankingTop10': return rpc<T>('get_ranking_top10');
    case 'getGlobalRankTop10': return rpc<T>('get_global_rank_top10');
    case 'getMyGlobalRank': return rpc<T>('get_my_global_rank');
    case 'getGlobalRankingPage': return rpc<T>('get_global_ranking_page');
    case 'getArena': return rpc<T>('get_arena');
    case 'getArenaHistory': return rpc<T>('get_arena_history', { p_before_day: data.beforeDay ?? null });
    case 'getArenaKing': return rpc<T>('get_arena_king', { p_profile_id: data.uid });
    case 'getMyDailyBattle': return rpc<T>('get_my_daily_battle_with_ranks');
    case 'getMyPreviousDailyBattle': return rpc<T>('get_my_previous_daily_battle');
    case 'getProfileDailyBattles': return rpc<T>('get_profile_daily_battles', { p_profile_id: data.uid });
    case 'getBattleProfileStats': return rpc<T>('get_battle_profile_stats', { p_profile_id: data.uid });
    case 'getProfileOverviewMeta': return rpc<T>('get_profile_overview_meta', { p_profile_id: data.uid });
    case 'getMyRank': return rpc<T>('get_my_rank');
    case 'getTournamentRankingPage': return rpc<T>('get_tournament_ranking_page');
    case 'getPublicProfile': return rpc<T>('get_public_profile', { p_profile_id: data.uid });
    case 'getPassStatus': return rpc<T>('get_pass_status');
    case 'setUsernameFont': return rpc<T>('set_username_font', { p_font: data.font });
    case 'setPassStyles': return rpc<T>('set_pass_styles', { p_border_style: data.borderStyle, p_name_style: data.nameStyle });
    case 'getHalloweenBoxState': return rpc<T>('get_halloween_box_state');
    case 'getBoxState': return rpc<T>('get_box_state');
    case 'openBox': return rpc<T>('open_box', { p_request_id: data.requestId });
    case 'openHalloweenBox': return rpc<T>('open_halloween_box', { p_request_id: data.requestId });
    case 'getAdminBoxBalance': return rpc<T>('admin_get_box_balance', { p_profile_id: data.uid });
    case 'grantBoxes': return rpc<T>('admin_grant_boxes', { p_profile_id: data.uid, p_quantity: data.quantity });
    case 'getAdminState': {
      const state = await rpc<{ registrationsOpen: boolean; predictions: unknown[] }>('get_admin_state');
      return { ...state, predictions: predictions(state.predictions) } as T;
    }
    case 'setRegistrations': return rpc<T>('set_registrations', { p_open: data.open });
    case 'publishPrediction': return rpc<T>('publish_prediction_ranked', { p_day_id: data.dayId, p_slot: data.slot, p_title: data.title, p_description: data.description, p_options: data.options, p_rank_points: data.rankPoints, p_closes_at: data.closesAt });
    case 'setOpenPredictionRankPoints': return rpc<T>('set_open_prediction_rank_points', { p_day_id: data.dayId, p_slot: data.slot, p_rank_points: data.rankPoints });
    case 'settlePrediction': return rpc<T>('settle_prediction_for_slot', { p_day_id: data.dayId, p_slot: data.slot, p_winning_option_id: data.winningOptionId });
    case 'getAdminProfile': return rpc<T>('get_admin_profile', { p_search: data.search });
    case 'getAdminPlayers': return rpc<T>('get_admin_players', { p_search: data.search, p_page: data.page });
    case 'getAdminPicksForDay': return rpc<T>('get_admin_picks_for_day', { p_profile_id: data.uid, p_day_id: data.day });
    case 'adminAddPick': return rpc<T>('admin_add_pick', { p_profile_id: data.uid, p_day_id: data.dayId, p_slot: data.slot, p_option_id: data.optionId });
    case 'adminCorrectPick': return rpc<T>('admin_correct_pick', { p_profile_id: data.uid, p_day_id: data.dayId, p_slot: data.slot, p_option_id: data.optionId });
    case 'getAdminPassGrant': return rpc<T>('admin_get_pass_grant', { p_profile_id: data.uid });
    case 'setAdminPassGrant': return rpc<T>('admin_set_pass_grant', { p_profile_id: data.uid, p_days: data.days });
    case 'adminRemoveProfilePhoto': return rpc<T>('admin_remove_profile_photo', { p_profile_id: data.uid });
    case 'adminUpdateProfile': return rpc<T>('admin_update_profile_ranked', {
      p_profile_id: data.uid, p_username: data.username, p_avatar_color: data.avatarColor,
      p_level: data.level, p_xp: data.xp, p_rank_points: data.rankPoints, p_green: data.green, p_red: data.red,
      p_green_streak_current: data.greenStreakCurrent, p_green_streak_max: data.greenStreakMax,
    });
    default: throw Object.assign(new Error('Operação não encontrada.'), { code: 'app/validation' });
  }
}

export async function passRedirect(destination: 'pass-checkout' | 'pass-portal' | 'pass-pix' | 'box-checkout', body?: { quantity: number; requestId: string; theme?: 'classic'|'halloween' }) {
  const { data, error } = await supabase.functions.invoke<{ url?: string; error?: string }>(destination, body ? { body } : undefined);
  if (error) {
    const response = (error as { context?: unknown }).context;
    if (response instanceof Response) {
      const body = await response.clone().json().catch(() => null) as { error?: unknown } | null;
      if (typeof body?.error === 'string') throw new Error(body.error);
      throw new Error(`Não foi possível abrir a assinatura (HTTP ${response.status}).`);
    }
    throw error;
  }
  if (!data?.url) throw new Error(data?.error || 'Não foi possível abrir a assinatura.');
  const target = new URL(data.url);
  if (target.protocol !== 'https:' || (target.hostname !== 'checkout.stripe.com' && target.hostname !== 'billing.stripe.com')) {
    throw new Error('Destino de pagamento inválido.');
  }
  window.location.assign(target.href);
}

export function errorMessage(error: unknown): string {
  const value = error as { code?: string; message?: string };
  const known: Record<string, string> = {
    'app/not-configured': 'A conexão com o novo banco ainda precisa ser configurada.',
    'over_email_send_rate_limit': 'Muitas tentativas de acesso. Aguarde alguns minutos.',
    'validation_failed': 'Confira os dados e tente novamente.',
    'PGRST121': 'Muitas requisições. Aguarde um minuto e tente novamente.',
    'PT429': 'Muitas requisições. Aguarde um minuto e tente novamente.',
  };
  if (known[value.code ?? '']) return known[value.code ?? ''];
  if (value.message && !/jwt|postgres|relation|schema|permission denied for/i.test(value.message)) return value.message;
  return 'Não foi possível concluir. Tente novamente.';
}

export type { Pick };
