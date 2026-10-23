import {describe,it,expect,vi} from 'vitest';
import {runBotPickBatches} from '../src/botPickBatches';

describe('manual bot pick requests',()=>{
 it('sends sequential requests until the backlog is complete',async()=>{
  const next=vi.fn().mockResolvedValueOnce({batchCreated:15,hasMore:true}).mockResolvedValueOnce({batchCreated:3,hasMore:false});
  const report=vi.fn();
  expect(await runBotPickBatches(next,()=>true,report)).toBe(18);
  expect(next.mock.calls).toEqual([[true],[false]]);
  expect(report.mock.calls.map(call=>call[1])).toEqual([15,18]);
 });
 it('retains completed progress when the next request fails',async()=>{
  const next=vi.fn().mockResolvedValueOnce({batchCreated:15,hasMore:true}).mockRejectedValueOnce(new Error('offline'));
  const report=vi.fn();
  await expect(runBotPickBatches(next,()=>true,report)).rejects.toThrow('offline');
  expect(report).toHaveBeenCalledTimes(1);
  expect(report.mock.calls[0][1]).toBe(15);
 });
 it('stops when the panel closes, including an in-flight response',async()=>{
  let active=true;
  const next=vi.fn(async()=>{active=false;return {batchCreated:15,hasMore:true};});
  const report=vi.fn();
  await runBotPickBatches(next,()=>active,report);
  expect(next).toHaveBeenCalledTimes(1);
  expect(report).not.toHaveBeenCalled();
 });
 it('rejects a response that would spin forever without progress',async()=>{
  const next=vi.fn().mockResolvedValue({batchCreated:0,hasMore:true});
  await expect(runBotPickBatches(next,()=>true,()=>{})).rejects.toThrow('avançar');
  expect(next).toHaveBeenCalledTimes(1);
 });
 it('accepts a completed replay without making more requests',async()=>{
  const next=vi.fn().mockResolvedValue({batchCreated:0,hasMore:false});
  expect(await runBotPickBatches(next,()=>true,()=>{})).toBe(0);
  expect(next).toHaveBeenCalledTimes(1);
 });
});
