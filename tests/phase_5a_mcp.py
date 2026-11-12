import urllib.request,json,sys,pathlib
url='http://127.0.0.1:8000/mcp'
headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
def rpc(method,params=None):
 payload={'jsonrpc':'2.0','id':1,'method':method}
 if params is not None: payload['params']=params
 req=urllib.request.Request(url,json.dumps(payload).encode(),headers)
 with urllib.request.urlopen(req,timeout=180) as r:
  sid=r.headers.get('mcp-session-id')
  if sid: headers['mcp-session-id']=sid
  data=r.read().decode()
 for line in data.splitlines():
  if line.startswith('data: '): return json.loads(line[6:])
 return json.loads(data)
rpc('initialize',{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'codex-5a','version':'1'}})
if sys.argv[1]=='list':
 r=rpc('tools/list'); pathlib.Path('tests/phase_5a_mcp_tools.json').write_text(json.dumps(r,indent=2)); print([(x['name']) for x in r['result']['tools']])
else:
 args={} if sys.argv[1]=='eval' else json.loads(sys.argv[2]) if len(sys.argv)>2 and sys.argv[2].startswith('{') else (json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8-sig')) if len(sys.argv)>2 else {})
 name=sys.argv[1]
 if name=='eval':
  name='editor_manage'; args={'op':'game_eval','params':{'code':pathlib.Path(sys.argv[2]).read_text(encoding='utf-8-sig')}}
 r=rpc('tools/call',{'name':name,'arguments':args})
 if 'result' in r:
  res=r['result']
  for c in res.get('content',[]):
   if c.get('type')=='image':
    import base64
    pathlib.Path('tests/phase_5a_evidence').mkdir(exist_ok=True)
    pathlib.Path('tests/phase_5a_evidence/latest.png').write_bytes(base64.b64decode(c.pop('data')))
  if 'structuredContent' in res: r=res['structuredContent']
 print(json.dumps(r,ensure_ascii=False))


