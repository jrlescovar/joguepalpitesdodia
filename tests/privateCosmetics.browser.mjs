import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
const browser = await chromium.launch({headless:true,channel:'chrome'});
const page = await browser.newPage({viewport:{width:390,height:844}});
const writes=[];
await page.route('**/rest/v1/rpc/**', async route => {
  const name=route.request().url().split('/').pop();
  if(name.startsWith('set_')||name.startsWith('update_')) writes.push({name,body:route.request().postDataJSON()});
  const value=name==='get_pass_status'?{active:false,nameStyle:'none',borderStyle:'none'}:
    name==='get_box_state'?{balance:0,inventory:[{kind:'name',style:'preview-plasma'},{kind:'frame',style:'preview-plasma'},{kind:'font',style:'preview-teko'}]}:{};
  await route.fulfill({json:value});
});
await page.goto('http://127.0.0.1:5178/');
await page.evaluate(async()=>{
  const React=(await import('/node_modules/.vite/deps/react.js')).default;
  const {createRoot}=(await import('/node_modules/.vite/deps/react-dom_client.js')).default;
  const {default:ProfileForm}=await import('/src/ProfileForm.tsx');
  await import('/src/supporter.css');
  document.getElementById('root').style.display='none';
  const element=document.createElement('div');element.style.cssText='max-width:580px;margin:20px auto;padding:16px';document.body.append(element);
  const root=createRoot(element);
  window.showTestProfile=id=>root.render(React.createElement(ProfileForm,{key:id,profile:{uid:'test-'+id,playerId:id,username:id===1000001?'jrlescovar':'visitante',avatarColor:'#3b82f6',passNameStyle:'none',passBorderStyle:'none',usernameFont:'normal',level:30,xp:0},onDone:()=>{window.saved=true;}}));
  window.showTestProfile(1000001);
});
await page.locator('.style-category-preview').first().waitFor();
await page.waitForTimeout(350);
for(const tab of ['Cor nome','Moldura','Fonte']){
  await page.getByRole('button',{name:tab,exact:true}).click();
  assert.equal(await page.locator('.style-category-preview').count(),10);
  const order=await page.locator('.pass-style-option').evaluateAll(els=>els.slice(-10).every(e=>e.classList.contains('style-category-preview')));
  assert.ok(order);
  assert.equal(await page.locator('.style-category-preview').first().evaluate(e=>getComputedStyle(e).borderColor),'rgb(74, 222, 128)');
  if(tab==='Fonte'){
    await page.evaluate(()=>document.fonts.ready);
    assert.ok(await page.locator('.style-category-preview .pass-name-preview').evaluateAll(els=>els.every(e=>getComputedStyle(e).visibility==='visible')));
  }
  await page.locator('.style-category-preview').last().click();
  await page.locator('.pass-style-option:not(.style-category-preview)').evaluateAll(els=>els.forEach(e=>e.style.display='none'));
  await page.locator('.pass-style-options').screenshot({path:process.env.TEMP+'/private-'+(tab==='Fonte'?'fonts':tab==='Moldura'?'frames':'colors')+'.png'});
}
await page.getByRole('button',{name:'Salvar alterações'}).click();
await page.waitForFunction(()=>window.saved);
assert.ok(writes.some(w=>w.name==='set_username_font'&&w.body.p_font==='preview-faster'));
assert.ok(writes.some(w=>w.name==='set_pass_styles'&&w.body.p_name_style==='preview-neon-ocean'&&w.body.p_border_style==='preview-neon-ocean'));
await page.evaluate(()=>window.showTestProfile(1000002));
for(const tab of ['Cor nome','Moldura','Fonte']){
  await page.getByRole('button',{name:tab,exact:true}).click();
  assert.equal(await page.locator('.style-category-preview').count(),0);
}
console.log('PASS: 30 private items, ordering, green borders, loaded fonts, selection/save, other-user filtering.');
await browser.close();
