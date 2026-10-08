import { X } from 'lucide-react';
import ChestIcon from './ChestIcon';
import SupporterEmblem from './SupporterEmblem';
import type { WheelPrize } from './types';

export default function WheelPrizeIcon({kind,small=false,size}:{kind:WheelPrize['kind'];small?:boolean;size?:number}){
  if(kind==='supporter')return <SupporterEmblem className="profile-supporter-emblem wheel-supporter-icon"/>;
  if(kind==='empty')return <X size={small?18:25}/>;
  return <ChestIcon size={size??(small?24:40)} halloween={kind==='halloween'} graffiti={kind==='font'} className={`wheel-chest wheel-chest-${kind}`}/>;
}
