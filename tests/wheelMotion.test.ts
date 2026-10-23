import {describe,it,expect,vi} from 'vitest';
import {animateWheel,setWheelAngle} from '../src/wheelMotion';
function fixture(){
 const animations:{startTime:number|null;onfinish:null;finish:ReturnType<typeof vi.fn>;cancel:ReturnType<typeof vi.fn>}[]=[];
 const animate=(..._args:unknown[])=>{const a={startTime:null,onfinish:null,finish:vi.fn(),cancel:vi.fn()};animations.push(a);return a;};
 const icons=[0,125].map(middle=>({dataset:{wheelMiddle:String(middle)},style:{transform:''},animate:vi.fn(animate)}));
 const disc={style:{transform:''},clientWidth:250,clientHeight:250,ownerDocument:{timeline:{currentTime:42}},querySelectorAll:()=>icons,animate:vi.fn(animate)};
 return {disc:disc as unknown as HTMLElement,icons,animations};
}
describe('upright prizes following wheel sectors',()=>{
 it('synchronizes the disc and local artwork counter-rotations',()=>{
 const {disc,icons,animations}=fixture();animateWheel(disc,72,1900);expect(animations).toHaveLength(3);expect(animations.every(a=>a.startTime===42)).toBe(true);
 for(const icon of icons){const frames=icon.animate.mock.calls[0][0] as Keyframe[];expect(frames[0].transform).toBe('rotate(-72deg)');expect(frames[1].transform).toBe('rotate(-1900deg)');}
 });
 it('finishes and cancels all animations together',()=>{const {disc,animations}=fixture();const group=animateWheel(disc,0,1810);group.finish();group.cancel();for(const a of animations){expect(a.finish).toHaveBeenCalledOnce();expect(a.cancel).toHaveBeenCalledOnce();}});
 it('restores upright icons at the result angle',()=>{const {disc,icons}=fixture();setWheelAngle(disc,135);expect(disc.style.transform).toBe('rotate(135deg)');for(const icon of icons)expect(icon.style.transform).toContain('rotate(-135deg)');});
});
