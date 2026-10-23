import {describe,expect,it} from 'vitest';
import {authStorageKey,needsAuthRestore} from '../src/authBootstrap';
const key='sb-example-auth-token';
const empty={getItem:()=>null};
describe('deferred public authentication',()=>{
 it('keeps the SDK session key compatible with the existing project',()=>{expect(authStorageKey('https://example.supabase.co')).toBe(key);expect(authStorageKey('')).toBeNull();});
 it('does not request private session code for a new visitor',()=>{expect(needsAuthRestore(new URL('https://site.example/'),empty,key)).toBe(false);});
 it('restores existing sessions, including those needing refresh',()=>{expect(needsAuthRestore(new URL('https://site.example/'),{getItem:()=>'persisted-session'},key)).toBe(true);});
 it.each(['?code=callback','?error=access_denied','?error_description=declined','#access_token=callback','#refresh_token=callback','#error=access_denied'])('delegates OAuth return %s to the existing SDK',suffix=>{expect(needsAuthRestore(new URL('https://site.example/'+suffix),empty,key)).toBe(true);});
 it('falls back to the SDK if storage is blocked or configuration is unavailable',()=>{expect(needsAuthRestore(new URL('https://site.example/'),{getItem:()=>{throw Error('blocked');}},key)).toBe(true);expect(needsAuthRestore(new URL('https://site.example/'),empty,null)).toBe(true);});
});
