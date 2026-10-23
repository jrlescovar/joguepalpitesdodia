import { createClient, type User } from '@supabase/supabase-js';
import type { Pick, Prediction } from './types';
import { ReadRequests } from './readRequests';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'placeholder-key';
export const backendConfigured = Boolean(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY);

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
});

const reads = new ReadRequests();
export function invalidateReads() { reads.clear(); }
let readUser: string | null = null;
supabase.auth.onAuthStateChange((_event, session) => {
  const uid = session?.user.id ?? null;
  if (uid !== readUser) { readUser = uid; invalidateReads(); }
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

function currentPredictions(): Promise<Prediction[]> {
  return rpc<unknown>('get_current_predictions').then(predictions);
}

async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  if (!backendConfigured) throw Object.assign(new Error('Conecte o projeto Supabase para concluir a migração.'), { code: 'app/not-configured' });
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw error;
  return data as T;
}

// Settlement/claim RPCs are deliberately excluded: they can perform writes.
const sharedReads = new Set([
  'getPassStatus', 'getCurrentPredictions', 'getRecentResults', 'getPick', 'getPicksForDay',
  'getRankingTop10', 'getGlobalRankTop10', 'getMyGlobalRank', 'getGlobalRankingPage',
  'getArenaHistory', 'getArenaKing', 'getBattlePickComparison', 'getBattleProfileStats',
  'getProfileOverviewMeta', 'getMyRank', 'getTournamentRankingPage',
  'getPublicProfile', 'getFontBoxState', 'getNameBoxState', 'getFrameBoxState',
  'getHalloweenBoxState', 'getBoxState',
  'getFinishingTournament',
]);

export async function call<T = unknown>(name: string, payload: unknown = {}): Promise<T> {
  if (sharedReads.has(name)) {
    return reads.run(`${name}:${JSON.stringify(payload)}`, () => dispatch<T>(name, payload), name === 'getPassStatus' ? 15000 : name === 'getFinishingTournament' ? 30000 : 0);
  }
  const mutation = !name.startsWith('get') && name !== 'checkUsername';
  if (mutation) invalidateReads();
  try { return await dispatch<T>(name, payload); }
  finally { if (mutation) invalidateReads(); }
}

async function dispatch<T = unknown>(name: string, payload: unknown = {}): Promise<T> {
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
    case 'getLigaWeekHistory': return rpc<T>('get_liga_week_history');
    case 'getArena': return rpc<T>('get_arena');
    case 'getArenaHistory': return rpc<T>('get_arena_history', { p_before_day: data.beforeDay ?? null });
    case 'getArenaKing': return rpc<T>('get_arena_king', { p_profile_id: data.uid });
    case 'getMyDailyBattle': return rpc<T>('get_my_daily_battle_with_ranks');
    case 'getMyPreviousDailyBattle': return rpc<T>('get_my_previous_daily_battle');
    case 'getBattlePickComparison': return rpc<T>('get_battle_pick_comparison', { p_day_id: data.dayId, p_profile_id: data.uid });
    case 'getProfileDailyBattles': return rpc<T>('get_profile_daily_battles', { p_profile_id: data.uid });
    case 'getBattleProfileStats': return rpc<T>('get_battle_profile_stats', { p_profile_id: data.uid });
    case 'getProfileOverviewMeta': return rpc<T>('get_profile_overview_meta', { p_profile_id: data.uid });
    case 'getMyRank': return rpc<T>('get_my_rank');
    case 'getTournamentRankingPage': return rpc<T>('get_tournament_ranking_page');
    case 'getFinishingTournament': return rpc<Record<string, unknown> | null>('get_finishing_tournament', { p_tournament_id: data.tournamentId ?? null })
      .then(state => (state ? { ...state, clientReceivedAt: Date.now() } : null) as T);
    case 'submitTournamentPick': return rpc<Record<string, unknown>>('submit_finishing_tournament_pick', { p_tournament_id: data.tournamentId, p_slot: data.slot, p_option_id: data.optionId })
      .then(state => ({ ...state, clientReceivedAt: Date.now() }) as T);
    case 'getAdminFinishingTournament': return rpc<T>('get_admin_finishing_tournament', { p_tournament_id: data.tournamentId ?? null });
    case 'getAdminPlayerTournamentPicks': return rpc<T>('get_admin_player_tournament_picks', { p_profile_id: data.uid, p_tournament_id: data.tournamentId ?? null });
    case 'adminSaveTournamentPick': return rpc<T>('admin_save_tournament_pick', { p_profile_id: data.uid, p_tournament_id: data.tournamentId, p_slot: data.slot, p_option_id: data.optionId, p_expected_option_id: data.expectedOptionId });
    case 'getAutomaticResultsStatus': return rpc<T>('get_automatic_results_status');
    case 'settleTournamentPrediction': return rpc<T>('settle_finishing_tournament_prediction', { p_tournament_id: data.tournamentId, p_slot: data.slot, p_home_shots: data.homeShots, p_away_shots: data.awayShots });
    case 'settleTournamentWinner': return rpc<T>('settle_finishing_tournament_winner', { p_tournament_id: data.tournamentId, p_slot: data.slot, p_winning_option_id: data.winningOptionId });
    case 'getPublicProfile': return rpc<T>('get_public_profile', { p_profile_id: data.uid });
    case 'getPassStatus': return rpc<T>('get_pass_status');
    case 'getCoinWallet': return rpc<T>('get_coin_wallet');
    case 'buyBoxesWithCoins': return rpc<T>('buy_boxes_with_coins', { p_theme: data.theme, p_quantity: data.quantity, p_request_id: data.requestId });
    case 'setUsernameFont': return rpc<T>('set_username_font', { p_font: data.font });
    case 'setPassStyles': return rpc<T>('set_pass_styles', { p_border_style: data.borderStyle, p_name_style: data.nameStyle });
    case 'getFontBoxState': return rpc<T>('get_font_box_state');
    case 'getNameBoxState': return rpc<T>('get_name_box_state');
    case 'getFrameBoxState': return rpc<T>('get_frame_box_state');
    case 'openNameBox': return rpc<T>('open_name_box', { p_request_id: data.requestId });
    case 'openFrameBox': return rpc<T>('open_frame_box', { p_request_id: data.requestId });
    case 'getDailyWheelState': return rpc<T>('get_daily_wheel_state');
    case 'spinDailyWheel': return rpc<T>('spin_daily_wheel', { p_request_id: data.requestId });
    case 'openFontBox': return rpc<T>('open_font_box', { p_request_id: data.requestId });
    case 'getHalloweenBoxState': return rpc<T>('get_halloween_box_state');
    case 'getMailbox': return rpc<T>('get_mailbox');
      case 'receiveMail': return rpc<T>('receive_mail',{p_kind:data.kind});
      case 'receiveAllLevelDrops': return rpc<T>('receive_all_level_drops');
      case 'receiveLevelDrop': return rpc<T>('receive_level_drop',{p_drop_id:data.dropId});
      case 'grantLegendaryDrops': return rpc<T>('admin_grant_legendary_drops',{p_profile_id:data.uid,p_quantity:data.quantity});
      case 'getLevelDrops': return rpc<T>('get_level_drops');
    case 'interactLevelDrop': return rpc<T>('interact_level_drop',{p_drop_id:data.dropId,p_request_id:data.requestId,p_open:data.open});
    case 'getBoxState': return rpc<T>('get_box_state');
    case 'openBox': return rpc<T>('open_box', { p_request_id: data.requestId });
    case 'openHalloweenBox': return rpc<T>('open_halloween_box', { p_request_id: data.requestId });
    case 'getAdminBoxBalance': return rpc<T>('admin_get_box_balance', { p_profile_id: data.uid });
    case 'grantBoxes': return rpc<T>('admin_grant_boxes', { p_profile_id: data.uid, p_quantity: data.quantity });
    case 'getAdminFontBoxBalance': return rpc<T>('admin_get_font_box_balance', { p_profile_id: data.uid });
    case 'grantFontBoxes': return rpc<T>('admin_grant_font_boxes', { p_profile_id: data.uid, p_quantity: data.quantity });
    case 'getAdminHalloweenBoxBalance': return rpc<T>('admin_get_halloween_box_balance', { p_profile_id: data.uid });
    case 'grantHalloweenBoxes': return rpc<T>('admin_grant_halloween_boxes', { p_profile_id: data.uid, p_quantity: data.quantity });
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
    case 'getAdminDailyBots': return rpc<T>('get_admin_daily_bots');
    case 'setAdminDailyBotsEnabled': return rpc<T>('admin_set_daily_bots_enabled', { p_enabled: data.enabled });
    case 'runAdminDailyBotsNow': return rpc<T>('admin_run_daily_bots_now', {});
    case 'runAdminBotPickBatch': return rpc<T>('admin_run_bot_pick_batch', {p_first:Boolean(data.first)});
    case 'addAdminDailyBot': return rpc<T>('admin_add_daily_bot', { p_profile_id: data.uid });
    case 'removeAdminDailyBot': return rpc<T>('admin_remove_daily_bot', { p_profile_id: data.uid });
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

export async function passRedirect(destination: 'infinitepay-checkout', body?: { quantity: number; requestId: string; theme?: 'classic'|'halloween'|'font'; kind?: 'classic'|'halloween'|'font'|'supporter'|'tournament'|'coins'; tournamentId?: string }) {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), 20000);
  let response;
  try {
    response = await supabase.functions.invoke<{ url?: string; error?: string }>(destination, { ...(body ? { body } : {}), signal: controller.signal });
    if (controller.signal.aborted) throw new Error('A conexão com o pagamento demorou. Tente novamente.');
  } catch (cause) {
    if (controller.signal.aborted) throw new Error('A conex\u00e3o com o pagamento demorou. Tente novamente.');
    throw cause;
  } finally { window.clearTimeout(timer); }
  const { data, error } = response;
  if (error) {
    const response = (error as { context?: unknown }).context;
    if (response instanceof Response) {
      const body = await response.clone().json().catch(() => null) as { error?: unknown } | null;
      if (typeof body?.error === 'string') throw new Error(body.error);
      throw new Error(`Não foi possível abrir o pagamento (HTTP ${response.status}).`);
    }
    throw error;
  }
  if (!data?.url) throw new Error(data?.error || 'Não foi possível abrir o pagamento.');
  const target = new URL(data.url);
  const hosts = ['checkout.infinitepay.io','buy.infinitepay.io'];
  if (target.protocol !== 'https:' || target.username || target.password || target.port || !hosts.includes(target.hostname)) {
    throw new Error('Destino de pagamento inválido.');
  }
  window.location.assign(target.href);
}

export async function infinitePayStatus(body: { order_nsu: string; transaction_nsu?: string; slug?: string }) {
  const { data, error } = await supabase.functions.invoke<{ paid?: boolean; kind?: string; error?: string }>('infinitepay-status', { body, signal: AbortSignal.timeout(15000) });
  if (error) {
    const context = (error as { context?: unknown }).context;
    if (context instanceof Response) {
      const response = await context.clone().json().catch(() => null);
      if (typeof response?.error === 'string') throw new Error(response.error);
    }
    throw error;
  }
  if (data?.error) throw new Error(data.error);
  return { paid: Boolean(data?.paid), kind: data?.kind };
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
