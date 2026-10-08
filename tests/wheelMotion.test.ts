import { describe, expect, it, vi } from 'vitest';
import { animateWheel, setWheelAngle } from '../src/wheelMotion';

function fixture(){
  const icons=[0,125].map(middle=>({dataset:{wheelMiddle:String(middle)},style:{transform:''},animate:vi.fn()}));
  const motions: {frames:Keyframe[];animation:{startTime:number|null;onfinish:null;finish:ReturnType<typeof vi.fn>;cancel:ReturnType<typeof vi.fn>}}[]=[];
  function animate(frames:Keyframe[]){
    const animation={startTime:null as number|null,onfinish:null,finish:vi.fn(),cancel:vi.fn()};
    motions.push({frames,animation});return animation;
  }
  for(const icon of icons)icon.animate.mockImplementation(animate);
  const disc={style:{transform:''},clientWidth:250,clientHeight:250,parentElement:{querySelectorAll:()=>icons},ownerDocument:{timeline:{currentTime:42}},animate:vi.fn(animate)};
  return {disc:disc as unknown as HTMLElement,icons,motions};
}

// Compose the interpolated CSS transform functions, omitting only the fixed
// percentage centering offset. This checks the artwork's actual orientation
// and its orbital position throughout the spin rather than just endpoints.
function interpolatedMatrix(from:string,to:string,progress:number){
  const ops=(text:string)=>Array.from(text.matchAll(/(translate|rotate)\(([^)]+)\)/g)).filter(match=>!match[2].includes('%')).map(match=>({kind:match[1],values:match[2].split(',').map(value=>parseFloat(value))}));
  const start=ops(from),end=ops(to);
  let matrix={a:1,b:0,c:0,d:1,e:0,f:0};
  start.forEach((operation,index)=>{
    const values=operation.values.map((value,key)=>value+(end[index].values[key]-value)*progress);
    if(operation.kind==='translate')matrix={...matrix,e:matrix.e+matrix.a*values[0]+matrix.c*values[1],f:matrix.f+matrix.b*values[0]+matrix.d*values[1]};
    else {
      const angle=values[0]*Math.PI/180,cos=Math.cos(angle),sin=Math.sin(angle);
      matrix={...matrix,a:matrix.a*cos+matrix.c*sin,b:matrix.b*cos+matrix.d*sin,c:-matrix.a*sin+matrix.c*cos,d:-matrix.b*sin+matrix.d*cos};
    }
  });
  return matrix;
}

describe('upright wheel artwork',()=>{
  it('keeps icons upright at every sampled animation point while orbiting with their sectors',()=>{
    const {disc,icons,motions}=fixture();
    const start=72,target=1900;
    animateWheel(disc,start,target);
    icons.forEach((icon,index)=>{
      const frames=motions[index+1].frames;
      const middle=Number(icon.dataset.wheelMiddle)*Math.PI/180,x=90*Math.sin(middle),y=-90*Math.cos(middle);
      for(const progress of [0,.1,.37,.75,1]){
        const matrix=interpolatedMatrix(String(frames[0].transform),String(frames[1].transform),progress);
        const angle=(start+(target-start)*progress)*Math.PI/180;
        expect(matrix.a).toBeCloseTo(1);expect(matrix.d).toBeCloseTo(1);
        expect(matrix.b).toBeCloseTo(0);expect(matrix.c).toBeCloseTo(0);
        expect(x+matrix.e).toBeCloseTo(x*Math.cos(angle)-y*Math.sin(angle));
        expect(y+matrix.f).toBeCloseTo(x*Math.sin(angle)+y*Math.cos(angle));
      }
    });
  });
  it('shares one clock and finishes/cancels all orbits, including interrupted spins',()=>{
    const {disc,motions}=fixture();
    const group=animateWheel(disc,0,1810);
    expect(motions.every(motion=>motion.animation.startTime===42)).toBe(true);
    group.finish();
    expect(motions.every(motion=>motion.animation.finish.mock.calls.length===1)).toBe(true);
    group.cancel();
    expect(motions.every(motion=>motion.animation.cancel.mock.calls.length===1)).toBe(true);
  });
  it('restores an upright final position without requiring an animation',()=>{
    const {disc,icons}=fixture();
    setWheelAngle(disc,135);
    expect(disc.style.transform).toBe('rotate(135deg)');
    for(const icon of icons){
      const matrix=interpolatedMatrix(icon.style.transform,icon.style.transform,1);
      expect(matrix.a).toBeCloseTo(1);expect(matrix.b).toBeCloseTo(0);
      expect(matrix.c).toBeCloseTo(0);expect(matrix.d).toBeCloseTo(1);
    }
  });
});
