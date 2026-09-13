BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
    $workflow=ConvertFrom-Yaml (Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw)
}
Describe 'Deployment consumes validated data without executing candidate code' {
    It 'keeps candidate code and checkout out of the privileged job' {
        $deploy=$workflow.jobs.deploy
        @($deploy.steps|Where-Object { $_.Contains('run') -or $_.uses -match 'checkout' }).Count | Should -Be 0
        @($deploy.steps|Where-Object { $_['with']['name'] -match 'Prepare|Build' }).Count | Should -Be 0
        ($deploy.steps|Where-Object uses -Like 'Azure/*').with.app_location | Should -Be 'deployment/site'
        ($workflow.jobs.validate.steps|Where-Object { $_['name'] -eq 'Check deployment inputs without deployment credentials' }).run | Should -Match '-Stage Deploy'
        $workflow.jobs.validate.Contains('permissions') | Should -BeFalse
    }
    It 'checks the actual uploaded bytes, identity and validation outcome as data' {
        $script=($workflow.jobs.deploy.steps|Where-Object uses -Like 'actions/github-script@*').with.script
        $scriptPath=Join-Path $TestDrive 'deployment-script.json'
        [IO.File]::WriteAllText($scriptPath,(ConvertTo-Json -InputObject $script))
        $runner=@'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const script = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const run = new Function('require','process','core', script);
process.chdir(path.dirname(process.argv[2]));
const sha = 'a'.repeat(40);
const env = {EXPECTED_COMMIT:sha, EXPECTED_TARGET:'preview', DEPLOYMENT_ENVIRONMENT:'35'};
fs.mkdirSync('deployment/site/.well-known', {recursive:true});
const content = '<script>throw new Error("This must never execute")</script>';
const published = {sourceCommit:sha,target:'preview',platformVersion:'1.0.0-preview'};
const write = (name,value) => fs.writeFileSync(`deployment/${name}`, typeof value==='string'?value:JSON.stringify(value));
write('site/index.html',content);
write('site/.well-known/open-guide-platform.json',published);
const identity = {schemaVersion:1,sourceCommit:sha,target:'preview',version:published.platformVersion,files:['index.html','.well-known/open-guide-platform.json'].map(p=>{
  const bytes=fs.readFileSync(`deployment/site/${p}`);
  return {path:p,length:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
})};
const report = {Outcome:'pass',SourceCommit:sha,Target:'preview'};
const reset = () => {write('artifact-identity.json',identity);write('artifact-validation.json',report);write('site/index.html',content);};
const invoke = (options={}) => run(name=> {
  if(name==='node:fs' && options.link) return {...fs,lstatSync:p=>String(p).endsWith('index.html')?{isFile:()=>false,isDirectory:()=>false}:fs.lstatSync(p)};
  return require(name);
},{env:{...env,...options.env}},{notice:()=>{}});
reset();invoke();
write('site/index.html',content+'tampered');assert.throws(()=>invoke(),/bytes differ/);reset();
write('site/extra.txt','extra');assert.throws(()=>invoke(),/inventory changed/);fs.unlinkSync('deployment/site/extra.txt');
write('artifact-validation.json',{...report,Outcome:'fail'});assert.throws(()=>invoke(),/passing evidence/);reset();
write('artifact-validation.json',{...report,SourceCommit:'b'.repeat(40)});assert.throws(()=>invoke(),/passing evidence/);reset();
write('artifact-identity.json',{...identity,files:[identity.files[0],identity.files[0]]});assert.throws(()=>invoke(),/bytes differ/);reset();
write('artifact-identity.json',{...identity,version:'another-version'});assert.throws(()=>invoke(),/Published deployment identity/);reset();
assert.throws(()=>invoke({env:{EXPECTED_TARGET:'production'}}),/passing evidence/);
assert.throws(()=>invoke({env:{DEPLOYMENT_ENVIRONMENT:''}}),/passing evidence/);
assert.throws(()=>invoke({link:true}),/non-regular deployment file/);
console.log('PASS deployment data isolation and tamper rejection');
'@
        $runnerPath=Join-Path $TestDrive 'deployment-test.cjs'
        [IO.File]::WriteAllText($runnerPath,$runner)
        & node $runnerPath $scriptPath
        $LASTEXITCODE | Should -Be 0
    }
}