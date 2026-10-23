export type BotPickBatch={batchCreated:number;hasMore:boolean};

// Each request commits independently. A retry only fills picks still missing.
export async function runBotPickBatches<T extends BotPickBatch>(
 next:(first:boolean)=>Promise<T>,active:()=>boolean,onBatch:(state:T,total:number)=>void,
){
 let first=true,total=0;
 while(active()){
  const state=await next(first);
  if(!active())return;
  total+=state.batchCreated;
  onBatch(state,total);
  if(!state.hasMore)return total;
  if(state.batchCreated<=0)throw new Error('Não foi possível avançar os palpites. Tente novamente.');
  first=false;
 }
}
