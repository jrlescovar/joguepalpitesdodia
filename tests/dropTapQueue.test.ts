import {describe,it,expect,vi} from 'vitest';
import {DropTapQueue,type DropTapRequest} from '../src/dropTapQueue';
type Progress={id:string;clicks_left:number;status:'playing'|'ready'|'claimed';reward:object|null};
const drop=(clicks=5):Progress=>({id:'drop-1',clicks_left:clicks,status:'playing',reward:null});
const tick=()=>new Promise<void>(resolve=>setTimeout(resolve,0));
function setup(){
 const waiting:{resolve:(value:Progress)=>void;reject:(cause:unknown)=>void}[]=[];
 const requests:DropTapRequest[]=[];
 const callbacks={send:vi.fn((request:DropTapRequest)=>{requests.push(request);return new Promise<Progress>((resolve,reject)=>waiting.push({resolve,reject}));}),result:vi.fn(),pending:vi.fn(),busy:vi.fn(),error:vi.fn()};
 return {queue:new DropTapQueue<Progress>(callbacks),waiting,requests,callbacks};
}
describe('rapid drop taps',()=>{
 it('accepts five rapid taps, gives immediate progress and sends only one mutation at a time',async()=>{
  const {queue,waiting,requests,callbacks}=setup();
  for(let index=0;index<5;index++)expect(queue.tap(drop())).toBe(true);
  expect(queue.tap(drop())).toBe(false);expect(requests).toHaveLength(1);expect(callbacks.pending).toHaveBeenLastCalledWith(5);
  for(let left=4;left>=0;left--){waiting.shift()!.resolve({...drop(left),status:left===0?'ready':'playing'});await tick();}
  expect(requests).toHaveLength(5);expect(new Set(requests.map(request=>request.requestId)).size).toBe(5);
  expect(callbacks.pending).toHaveBeenLastCalledWith(0);expect(callbacks.busy).toHaveBeenLastCalledWith(false);
 });
 it('keeps the original UUID and payload when retrying an uncertain response',async()=>{
  const {queue,waiting,requests,callbacks}=setup();queue.tap(drop());queue.tap(drop());
  waiting.shift()!.reject(new Error('Connection lost'));await tick();expect(callbacks.error).toHaveBeenCalled();
  queue.tap(drop());expect(requests[1]).toEqual(requests[0]);
  waiting.shift()!.resolve(drop(4));await tick();expect(requests).toHaveLength(3);
  waiting.shift()!.resolve(drop(3));await tick();expect(callbacks.result).toHaveBeenLastCalledWith(drop(3));
 });
 it('handles an upgrade to one-click Legendary, claims once and stops surplus taps',async()=>{
  const {queue,waiting,requests,callbacks}=setup();for(let index=0;index<5;index++)queue.tap(drop());
  waiting.shift()!.resolve(drop(1));await tick();
  waiting.shift()!.resolve({...drop(0),status:'ready'});await tick();expect(requests[2].open).toBe(true);
  const reward={...drop(0),status:'claimed' as const,reward:{style:'prize'}};
  waiting.shift()!.resolve(reward);await tick();
  expect(requests).toHaveLength(3);expect(callbacks.result).toHaveBeenLastCalledWith(reward);expect(queue.tap(reward,true)).toBe(false);
 });
 it('cannot mix two drops while an interaction is pending',()=>{
  const {queue}=setup();queue.tap(drop());expect(queue.tap({...drop(),id:'other-drop'})).toBe(false);queue.dispose();
 });
 it('does not send queued requests or update the UI after unmount',async()=>{
  const {queue,waiting,requests,callbacks}=setup();queue.tap(drop());queue.tap(drop());queue.dispose();
  waiting.shift()!.resolve(drop(4));await tick();expect(requests).toHaveLength(1);expect(callbacks.result).not.toHaveBeenCalled();
 });
});
