// Preview only: all Supabase requests are intercepted before components load.
import React from 'react';
import {createRoot} from 'react-dom/client';
import '../../src/styles.css';
import '../../src/design.css';
import '../../src/usernameFonts.css';
import '../../src/supporter.css';
import '../../src/ownerStyleVariants.css';
import {ownerStyleVariants} from '../../src/ownerStyleVariants';
const realFetch=window.fetch.bind(window);
window.fetch=async(url,init)=>{
  if(!String(url).includes('.supabase.co'))return realFetch(url,init);
  const endpoint=String(url).split('/').pop();
  if(endpoint==='get_pass_status')return Response.json({active:true,status:'none',borderStyle:'none',nameStyle:'none'});
  if(endpoint==='get_box_state')return Response.json({balance:0,inventory:ownerStyleVariants.flatMap(([style])=>[{kind:'name',style,rarity:'rare'},{kind:'frame',style,rarity:'rare'}])});
  if(endpoint==='check_username')return Response.json({valid:true,available:true});
  document.getElementById('last-request')!.textContent=JSON.stringify({endpoint,body:init?.body?JSON.parse(String(init.body)):null});
  return Response.json({});
};
const [{default:ProfileForm},{Avatar},{default:UsernameText}]=await Promise.all([import('../../src/ProfileForm'),import('../../src/components'),import('../../src/UsernameText')]);
const other=new URLSearchParams(location.search).has('other');
const profile={uid:'00000000-0000-4000-8000-000000000001',playerId:other?1000002:1000001,email:'',username:other?'Jogador':'jrlescovar',usernameLower:other?'jogador':'jrlescovar',avatarColor:'#3b82f6',level:34,xp:10,green:5,red:2,greenStreakCurrent:2,greenStreakMax:3,dailyStreakCurrent:1,lastPlayedDate:null,balance:0};
createRoot(document.getElementById('root')!).render(<div style={{maxWidth:1000,margin:'20px auto',padding:16}}><style>{`.variant-gallery-grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:8px}@media(max-width:900px){.variant-gallery-grid{grid-template-columns:repeat(4,minmax(0,1fr))}}@media(max-width:640px){.variant-gallery-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}`}</style><h1>Personalizações · prévia local</h1>{!new URLSearchParams(location.search).has('gallery')&&<><ProfileForm profile={profile}/><pre id="last-request" style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}/></>}{!other&&<section className="variant-gallery"><h2>{ownerStyleVariants.length} pares · Nome e Moldura</h2><div className="variant-gallery-grid">{ownerStyleVariants.map(([style,label,family])=><article key={style} className="card" style={{padding:10,borderColor:'#4ade80',display:'grid',justifyItems:'center',gap:6,textAlign:'center',fontSize:11}}><Avatar name="jrlescovar" color="#364152" borderStyle={style}/><span className={'pass-name-'+style}><UsernameText name="jrlescovar" font="dancingscript"/></span><strong>{label}</strong><small>Efeito Azul {family}</small></article>)}</div></section>}</div>);
