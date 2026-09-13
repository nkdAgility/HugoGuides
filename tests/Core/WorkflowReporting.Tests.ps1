BeforeAll {
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module powershell-yaml
    $workflow=ConvertFrom-Yaml (Get-Content "$root/.github/workflows/guide-site-build.yaml" -Raw)
    $reportJob=$workflow.jobs['prepare-report']
}
Describe 'Isolated workflow Prepare reporting' {
    It 'keeps write permission away from candidate execution' {
        $reportJob.permissions['pull-requests'] | Should -Be write
        @($reportJob.steps|Where-Object { $_.Contains('run') }).Count | Should -Be 0
        @($reportJob.steps|Where-Object { $_.uses -match 'checkout' }).Count | Should -Be 0
        $workflow.permissions['pull-requests'] | Should -BeNullOrEmpty
        $reportJob.needs | Should -Be prepare
        $reportJob.if | Should -Match 'always\(\)'
    }
    It 'passes report permission through the generated consumer caller' {
        $consumer=ConvertFrom-Yaml (Get-Content "$root/system/OpenGuidePlatform.GuideSite.Adoption/main.yaml" -Raw)
        $consumer.jobs['guide-site'].permissions['pull-requests'] | Should -Be write
        $consumer.jobs['guide-site'].permissions.actions | Should -Be read
        $consumer.permissions['pull-requests'] | Should -BeNullOrEmpty
    }
    It 'delivers current reports, preserves stale reports and distinguishes delivery failures' {
        $script=($reportJob.steps|Where-Object uses -EQ 'actions/github-script@v7').with.script
        $scriptPath=Join-Path $TestDrive 'report-script.json'
        [IO.File]::WriteAllText($scriptPath,(ConvertTo-Json -InputObject $script))
        $runner=@'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const script = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
const run = new AsyncFunction('require','github','core','context','process',script);
async function test(options={}) {
  const sha='a'.repeat(40);
  const assessment={schemaVersion:1,sourceCommit:sha,target:'preview',stage:'Prepare',outcome:options.outcome||'pass',...options.assessment};
  const markdown=`## Prepare: ${assessment.outcome}\n\nCommit: ${sha}\n${options.text||''}`;
  const notices=[],failures=[],posts=[];
  let gets=0;
  const api={rest:{pulls:{get:async()=>({data:{state:'open',head:{sha:(options.stale && ++gets>=options.stale)?'b'.repeat(40):sha}}})},issues:{listComments:()=>{},createComment:async comment=>{if(options.apiFailure)throw Error('API unavailable');posts.push(comment);}}},paginate:async()=>options.prior||[]};
  const files={'assessment/assessment.json':JSON.stringify(assessment),'assessment/assessment.md':markdown};
  const fakeFs={lstatSync:()=>{if(options.missing)throw Error('Report missing');return {isFile:()=>true,size:100};},readFileSync:path=>files[path]};
  await run(name=>{assert.equal(name,'node:fs');return fakeFs;},api,{notice:x=>notices.push(x),setFailed:x=>failures.push(x)},{repo:{owner:'org',repo:'repo'},payload:{pull_request:{number:35}},runId:100},{env:{ASSESSED_COMMIT:sha,ASSESSED_TARGET:'preview',GITHUB_RUN_ATTEMPT:'1',PREPARE_RESULT:options.prepareResult||'success'}});
  return {notices,failures,posts};
}
(async()=>{
  const success=await test({text:'${throw new Error("Never execute report text") }'});
  assert.equal(success.posts.length,1);assert.equal(success.failures.length,0);
  assert.match(success.posts[0].body,/not independent policy/);
  const blocked=await test({outcome:'blocked',prepareResult:'failure'});
  assert.match(blocked.posts[0].body,/did not complete successfully/);
  assert.match(blocked.posts[0].body,/## Prepare: blocked/);
  for(const stale of [1,2]){const r=await test({stale});assert.equal(r.posts.length,0);assert.match(r.notices[0],/REPORT_SUPERSEDED/);}
  const body=(await test()).posts[0].body;
  const prior=[{user:{login:'github-actions[bot]'},body}];
  assert.match((await test({prior})).notices[0],/REPORT_ALREADY_DELIVERED/);
  prior[0].body+=' changed';
  assert.match((await test({prior})).failures[0],/REPORT_DELIVERY_FAILED/);
  for(const options of [{missing:true},{apiFailure:true},{assessment:{sourceCommit:'b'.repeat(40)}}]){
    const r=await test(options);assert.equal(r.posts.length,0);assert.match(r.failures[0],/REPORT_DELIVERY_FAILED/);
  }
  console.log('PASS isolated PR delivery: current, blocked, stale, duplicate, conflicting, missing and API failure evidence');
})().catch(error=>{console.error(error);process.exitCode=1;});
'@
        $runner=$runner.Replace('\\n','\n')
        $runnerPath=Join-Path $TestDrive 'report-test.cjs'
        [IO.File]::WriteAllText($runnerPath,$runner)
        & node $runnerPath $scriptPath
        $LASTEXITCODE | Should -Be 0
    }
}