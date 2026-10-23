import fs from 'node:fs';
import React from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {createServer} from 'vite';

// Public content only: never render sessions, profiles or any account data into HTML.
const server=await createServer({server:{middlewareMode:true,hmr:false},appType:'custom'});
try {
 const {default:LoginScreen}=await server.ssrLoadModule('/src/LoginScreen.tsx');
 const markup=renderToStaticMarkup(React.createElement(LoginScreen,{onEnter(){},busy:false,error:''}));
 const file='index.html';
 let html=fs.readFileSync(file,'utf8');
 if(!html.includes('<!--login-shell-->'))html=html.replace(/<div id="root">[\s\S]*<\/div>\s*<script type="module"/, '<div id="root"><!--login-shell--><!--/login-shell--></div>\n <script type="module"');
 html=html.replace(/<!--login-shell-->[\s\S]*?<!--\/login-shell-->/,()=>`<!--login-shell-->${markup}<!--/login-shell-->`);
 fs.writeFileSync(file,html);
 console.log('Prerendered public login without account data.');
}finally{await server.close();}
