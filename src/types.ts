export type DateValue={toMillis():number;toDate():Date};
export type Profile={uid:string;playerId:number;email:string;username:string;usernameLower:string;usernameChangedAt?:string|null;avatarColor:string;avatarUrl?:string|null;useGoogleAvatar?:boolean;level:number;xp:number;green:number;red:number;greenStreakCurrent:number;greenStreakMax:number;dailyStreakCurrent:number;dailyStreakMax:number;lastPlayedDate:string|null;lastPlayedPrediction?:string|null;balance:number;rankPosition?:number|null;rankChange?:number};
export type PublicProfile={uid:string;playerId:number;username:string;avatarColor:string;avatarUrl?:string|null;useGoogleAvatar?:boolean;green:number;red?:number;level?:number;xp?:number;greenStreakCurrent?:number;greenStreakMax?:number;dailyStreakCurrent?:number;dailyStreakMax?:number;lastPlayedPrediction?:string|null;rankPosition?:number|null;rankChange?:number};
export type Prediction={dayId:string;title:string;description:string;options:{id:string;label:string}[];closesAt:DateValue;status:'open'|'settling'|'settled';winningOptionId?:string};
export type Pick={dayId:string;optionId:string;status:'pending'|'green'|'red'};
export type Session={dayId:string;serverTime:number;admin:boolean};
export const avatarColors=['#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308'];
export const colorNames=['Azul','Verde','Rosa','Roxo','Vermelho','Laranja','Amarelo'];
