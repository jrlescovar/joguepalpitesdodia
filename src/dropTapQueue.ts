type DropProgress={id:string;clicks_left:number;status:'playing'|'ready'|'claimed';reward:unknown};
export type DropTapRequest={dropId:string;requestId:string;open:boolean};
type Ticket=DropTapRequest&{attempted:boolean};

/** Keep rapid taps in order without running concurrent reward mutations. */
export class DropTapQueue<T extends DropProgress>{
 private tickets:Ticket[]=[];
 private current:T|null=null;
 private running=false;
 private failed=false;
 private disposed=false;
 constructor(private callbacks:{send:(request:DropTapRequest)=>Promise<T>;result:(drop:T)=>void;pending:(count:number)=>void;busy:(value:boolean)=>void;error:(cause:unknown)=>void}){}
 tap(drop:T,open=false){
  if(this.disposed)return false;
  if(this.current?.id!==drop.id){if(this.running||this.tickets.length)return false;this.current=drop;}
  if(this.current?.reward||this.current?.status==='claimed')return false;
  if(this.failed&&this.tickets.length){this.failed=false;void this.drain();return true;}
  const progress=this.current!;
  const opening=open||progress.status==='ready';
  if(opening&&this.tickets.length)return false;
  if(!opening&&this.tickets.length>=progress.clicks_left)return false;
  this.tickets.push({dropId:drop.id,requestId:crypto.randomUUID(),open:opening,attempted:false});
  this.publishPending();void this.drain();return true;
 }
 dispose(){this.disposed=true;this.tickets=[];}
 private publishPending(){this.callbacks.pending(this.tickets.filter(ticket=>!ticket.open).length);}
 private async drain(){
  if(this.running||this.disposed)return;
  this.running=true;this.callbacks.busy(true);
  try{
   while(this.tickets.length&&!this.disposed){
    const ticket=this.tickets[0];
    // Upgrading to Legendary can reduce the remaining budget to one tap.
    // Convert only unsent tickets; retries must keep the exact original request.
    if(!ticket.attempted&&this.current?.status==='ready')ticket.open=true;
    ticket.attempted=true;
    const next=await this.callbacks.send({dropId:ticket.dropId,requestId:ticket.requestId,open:ticket.open});
    if(this.disposed)return;
    this.current=next;this.tickets.shift();
    if(next.reward||next.status==='claimed')this.tickets=[];
    this.publishPending();this.callbacks.result(next);
   }
  }catch(cause){if(!this.disposed){this.failed=true;this.callbacks.error(cause);}}
  finally{this.running=false;if(!this.disposed)this.callbacks.busy(false);}
 }
}
