const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const [requestFile, toolRoot] = process.argv.slice(2);
const input = JSON.parse(fs.readFileSync(requestFile, 'utf8'));
const root = fs.realpathSync(input.artifactRoot);
const base = new URL(input.baseUri);
if (!['https:', 'http:'].includes(base.protocol)) throw Error('Invalid artifact origin.');
const tools = createRequire(path.join(toolRoot, 'package.json'));
const {chromium} = tools('playwright');
const report = {schemaVersion:1, outcome:'blocked', artifactIdentitySha256:input.artifactIdentitySha256,
  checkerSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),
  playwright:tools('playwright/package.json').version, observations:[], blockedRequests:[]};
const blocked = new Set();
const deadline = setTimeout(()=>{console.error('Runtime anchor validation timed out.');process.exit(1);},30000 + input.anchors.length * 20000);
(async()=>{
  const browser = await chromium.launch({headless:true});
  report.browser = browser.version();
  try {
    for (const expected of input.anchors) {
      if (!/^\/(?!\/)/.test(expected.route) || /[\\?#%]/.test(expected.route) || !expected.fragment) throw Error('Invalid runtime anchor declaration.');
      const context = await browser.newContext({serviceWorkers:'block',acceptDownloads:false});
      try {
        await context.routeWebSocket('**/*', socket=>{blocked.add(socket.url());socket.close();});
        await context.route('**/*', async route=>{
          const request=route.request(), url=new URL(request.url());
          if (url.origin!==base.origin || !['GET','HEAD'].includes(request.method())) {blocked.add(url.href);return route.abort();}
          let file=path.resolve(root,'.'+decodeURIComponent(url.pathname));
          if (!file.startsWith(root+path.sep) && file!==root) return route.abort();
          if(fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');
          if(!fs.existsSync(file)||!fs.statSync(file).isFile())return route.fulfill({status:404,body:'Missing artifact resource'});
          file=fs.realpathSync(file);
          if(!file.startsWith(root+path.sep))return route.abort();
          const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.woff2':'font/woff2','.png':'image/png','.jpg':'image/jpeg'};
          await route.fulfill({status:200,contentType:types[path.extname(file)]||'application/octet-stream',body:fs.readFileSync(file)});
        });
        const page=await context.newPage();
        const response=await page.goto(new URL(expected.route,base).href,{waitUntil:'load',timeout:15000});
        let exists=false, error=null;
        if(response?.status()===200){
          try{await page.waitForFunction(id=>!!document.getElementById(id)||[...document.querySelectorAll('a[name]')].some(a=>a.name===id),expected.fragment,{timeout:3000});exists=true;}
          catch{error='Declared anchor was not created by the current artifact.';}
        }else{error='Declared page did not load from the artifact.';}
        report.observations.push({...expected,exists,error});
      }finally{await context.close();}
    }
    report.outcome=report.observations.every(o=>o.exists)?'pass':'fail';
  }finally{await browser.close();}
})().catch(error=>{report.error=error.message;process.exitCode=1;}).finally(()=>{
  clearTimeout(deadline);report.blockedRequests=[...blocked].sort();console.log(JSON.stringify(report));
});
