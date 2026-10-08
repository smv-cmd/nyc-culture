const CACHE="nyc-culture-v1";
const SHELL=["./","index.html","manifest.webmanifest","icons/icon-192.png","icons/apple-touch-icon.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=="GET")return;
  // Data and the page itself: network first, fall back to the saved copy.
  if(u.origin===location.origin&&(u.pathname.endsWith("data.json")||u.pathname.endsWith("/")||u.pathname.endsWith("index.html"))){
    const key=u.pathname.endsWith("data.json")?"data.json":"index.html";
    e.respondWith(fetch(e.request).then(r=>{if(r.ok){const c=r.clone();caches.open(CACHE).then(ca=>ca.put(key,c))}return r}).catch(()=>caches.match(key)));
    return;
  }
  // Everything else (icons, fonts): cache first.
  e.respondWith(caches.match(e.request).then(m=>m||fetch(e.request).then(r=>{if(r.ok||r.type==="opaque"){const c=r.clone();caches.open(CACHE).then(ca=>ca.put(e.request,c))}return r})));
});
