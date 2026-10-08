import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { retirePushNotifications } from './retirePushNotifications';
import './styles.css';
import './design.css';
import './halloween.css';
// Font previews from previous visits must not compete with login/startup assets.
const warmFonts=()=>void import('./fontLoading').then(({warmRecentUsernameFonts})=>warmRecentUsernameFonts());
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App /></React.StrictMode>);
if ('serviceWorker' in navigator) void retirePushNotifications(navigator.serviceWorker);
if('requestIdleCallback' in window)window.requestIdleCallback(warmFonts,{timeout:3000});
else globalThis.setTimeout(warmFonts,1500);

import './usernameFonts.css';
