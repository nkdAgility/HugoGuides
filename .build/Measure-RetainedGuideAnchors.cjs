// Diagnostic E05 replay of retained raw Hugo artifacts; never contacts a consumer origin.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');
const [artifactContainer, navigationFile, toolRoot, outputArgument] = process.argv.slice(2);
if (!artifactContainer || !navigationFile || !toolRoot || !/^\.processing\/[A-Za-z0-9_-]+$/.test(outputArgument || '')) {
  throw new Error('Usage: node .build/Measure-RetainedGuideAnchors.cjs <artifact-container> <navigation.json> <browser-tool-root> .processing/<fresh-output>');
}
const output=path.resolve(outputArgument);
for(let cursor=output;cursor!==path.dirname(cursor);cursor=path.dirname(cursor)){
  if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error('Linked output directory is unsupported.');
}
fs.mkdirSync(output);
const tools=createRequire(path.resolve(toolRoot,'package.json'));
const {chromium,expect}=tools('@playwright/test');
const evidence=JSON.parse(fs.readFileSync(navigationFile,'utf8'));
const report={schemaVersion:1,checkerSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),playwright:tools('@playwright/test/package.json').version,scope:'Browser replay of local retained artifacts; all external requests blocked. Resolves selected static anchor findings, not full visual/network acceptance.',results:[]};
const save=()=>fs.writeFileSync(path.join(output,'runtime-anchors.json'),JSON.stringify(report,null,2));
(async()=>{
  const browser=await chromium.launch({headless:true});
  report.browser=browser.version();
  try{
    for(const result of evidence.results.filter(r=>['original','relocated'].includes(r.variant)&&r.target==='local')){
      const findings=result.findings.filter(f=>f.Code==='INTERNAL_ANCHOR_MISSING');
      if(!findings.length)continue;
      for(const value of [result.repository,result.variant,result.target])if(!/^[A-Za-z0-9_-]+$/.test(value))throw Error('Unsafe artifact identity.');
      const artifact=fs.realpathSync(path.join(artifactContainer,result.repository,result.variant,result.target));
      const context=await browser.newContext({viewport:{width:1365,height:900},serviceWorkers:'block'});
      const blocked=new Set();
      await context.route('**/*',async route=>{
        const request=route.request();const url=new URL(request.url());
        if(url.origin!==new URL(result.baseUri).origin || !['GET','HEAD'].includes(request.method())){blocked.add(url.origin);return route.abort();}
        let file=path.resolve(artifact,'.'+decodeURIComponent(url.pathname));
        if(file!==artifact&&!file.startsWith(artifact+path.sep))return route.fulfill({status:400,body:'Unsafe path'});
        if(fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');
        if(!fs.existsSync(file)||!fs.statSync(file).isFile())return route.fulfill({status:404,body:'Absent from retained artifact'});
        const actual=fs.realpathSync(file);
        if(!actual.startsWith(artifact+path.sep))return route.fulfill({status:400,body:'Linked path leaves artifact'});
        const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.woff2':'font/woff2','.ico':'image/x-icon','.pdf':'application/pdf'};
        return route.fulfill({status:200,contentType:types[path.extname(file)]||'application/octet-stream',body:fs.readFileSync(file)});
      });
      try{
        const page=await context.newPage();
        for(const relative of [...new Set(findings.map(f=>f.Page))]){
          const url=new URL(relative.replace(/index\.html$/,''),result.baseUri).href;
          const response=await page.goto(url,{waitUntil:'load',timeout:30000});
          if(!response||response.status()!==200)throw Error(`Retained page did not load: ${relative}`);
          const targets=[...new Set(findings.filter(f=>f.Page===relative).map(f=>f.Target.slice(1)))];
          const observed=await page.evaluate(targets=>targets.map(id=>{
            const element=document.getElementById(id)||[...document.querySelectorAll('a[name]')].find(a=>a.name===id);
            return {id,exists:!!element,element:element?.tagName||null,relatedIds:element?[]:[...document.querySelectorAll('[id]')].map(e=>e.id).filter(value=>value.endsWith(id)||(id.startsWith('appendix')&&value.startsWith('appendix')))};
          }),targets);
          let skipLink=null;
          if(observed.some(a=>a.id==='content'&&a.exists)){
            const link=page.locator('a[href="#content"]').first();
            await link.press('Enter');
            await expect(page).toHaveURL(/#content$/);
            const target=page.locator('main#content');
            await expect(target).toHaveCount(1);
            skipLink={hashNavigation:true,target:'main#content',visible:await target.isVisible()};
          }
          report.results.push({repository:result.repository,sourceCommit:result.sourceCommit,variant:result.variant,target:result.target,page:relative,url,anchors:observed,skipLink,externalOriginsBlocked:[...blocked].sort()});
          save();
        }
      }finally{await context.close();}
    }
    report.completed=true;save();
    console.log(`Recorded ${report.results.length} retained-page browser observations.`);
  }finally{await browser.close();}
})().catch(error=>{report.completed=false;report.error=error.message;save();console.error(error);process.exitCode=1;});