"""Read-only semantic comparison of retained E05 artifacts; never rewrites baselines."""
import hashlib, json, re, sys
from html.parser import HTMLParser
from pathlib import Path

def digest(value):
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()

class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.main=0; self.inert=0; self.heading=None
        self.text=[]; self.main_text=[]; self.headings=[]; self.ids=[]; self.links=[]; self.main_links=[]
        self.lang=''; self.direction=''; self.redirects=[]
    def handle_starttag(self,tag,attributes):
        a=dict(attributes)
        if tag in ('script','style'): self.inert+=1
        if tag=='main': self.main+=1
        if tag=='html': self.lang=a.get('lang',''); self.direction=a.get('dir','')
        if tag=='meta' and a.get('http-equiv','').lower()=='refresh': self.redirects.append(a.get('content',''))
        if a.get('id'): self.ids.append(a['id'])
        if tag=='a' and a.get('name'): self.ids.append(a['name'])
        if tag=='a' and 'href' in a:
            self.links.append(a['href'])
            if self.main: self.main_links.append(a['href'])
        if re.fullmatch('h[1-6]',tag): self.heading=[tag,[]]
    def handle_endtag(self,tag):
        if tag in ('script','style'): self.inert=max(0,self.inert-1)
        if tag=='main': self.main=max(0,self.main-1)
        if self.heading and tag==self.heading[0]:
            self.headings.append([tag,' '.join(' '.join(self.heading[1]).split())]); self.heading=None
    def handle_data(self,data):
        if self.inert:return
        self.text.append(data)
        if self.main:self.main_text.append(data)
        if self.heading:self.heading[1].append(data)
    def result(self):
        main=' '.join(' '.join(self.main_text).split())
        return {'language':self.lang,'direction':self.direction,'mainTextCharacters':len(main),
          'mainTextSha256':digest(main),'headingSha256':digest(self.headings),
          'idsSha256':digest(sorted(self.ids)),'mainLinksSha256':digest(self.main_links),
          'allLinksSha256':digest(self.links),'textSha256':digest(' '.join(' '.join(self.text).split())),
          'redirects':self.redirects,'headingCount':len(self.headings)}

def main():
    root=Path(sys.argv[1]).resolve(); output=Path(sys.argv[2]).resolve()
    if output.exists():raise RuntimeError('Use a fresh evidence directory.')
    if '.processing' not in output.parts:raise RuntimeError('Output belongs under .processing.')
    for parent in [output,*output.parents]:
        if parent.is_symlink():raise RuntimeError('Linked output is unsupported.')
    comparison=json.loads((root/'comparison.json').read_text(encoding='utf8'))
    results=[]; verified=0; observations={}
    builds=comparison['builds']+[{**b,'variant':'original-repeat-2'} for b in comparison['builds'] if b['variant']=='original']
    for build in builds:
        repo,variant,target=(build[k] for k in ('repository','variant','ring'))
        artifact=root/'artifacts'/repo/variant/target
        records=json.loads((root/f'{repo}-{variant}-{target}.files.json').read_text(encoding='utf8'))
        expected={r['path']:r['sha256'] for r in records}
        actual={}
        for file in artifact.rglob('*'):
            if file.is_symlink():raise RuntimeError(f'Linked retained artifact: {file}')
            if file.is_file():actual[file.relative_to(artifact).as_posix()]=hashlib.sha256(file.read_bytes()).hexdigest()
        if actual!=expected:raise RuntimeError(f'Retained inventory changed: {repo}/{variant}/{target}')
        verified+=len(actual)
        pages={}
        for relative in sorted(actual):
            if relative.endswith('.html'):
                parser=Page();parser.feed((artifact/relative).read_text(encoding='utf-8-sig'));pages[relative]=parser.result()
        observations[(repo,variant,target)]=pages
        results.append({'repository':repo,'variant':variant,'target':target,'sourceCommit':build['sourceCommit'],'pages':pages})
    pairs=[]
    for repo in sorted({b['repository'] for b in comparison['builds']}):
        for target in ('local','preview','production'):
            for left,right in (('original','relocated'),('pinned','original'),('original','original-repeat-2')):
                before=observations[(repo,left,target)];after=observations[(repo,right,target)]
                differences=[]
                for route in sorted(set(before)|set(after)):
                    fields=['page-presence'] if route not in before or route not in after else [k for k in before[route] if before[route][k]!=after[route][k]]
                    if fields:differences.append({'page':route,'fields':fields})
                pairs.append({'repository':repo,'target':target,'before':left,'after':right,'pagesCompared':len(set(before)|set(after)),'differences':differences})
    output.mkdir(parents=True)
    report={'schemaVersion':1,'checkerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'verifiedFiles':verified,
     'scope':'All retained HTML pages. Text whitespace is collapsed; script/style text is excluded. Main text, heading content, IDs, ordered links, language, direction and redirects are compared separately. Raw artifact hashes are verified first. No finding is waived and no visual approval is inferred.',
     'results':results,'comparisons':pairs}
    (output/'rendered-semantics.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    for pair in pairs:print(f"{pair['repository']} {pair['target']} {pair['before']}->{pair['after']}: {len(pair['differences'])}/{pair['pagesCompared']} pages differ")
    print(f'Verified {verified} retained files.')

if __name__=="__main__": main()
