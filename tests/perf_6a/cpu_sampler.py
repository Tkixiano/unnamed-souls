import ctypes as c,json,time,os,sys,pathlib
from ctypes import wintypes as w
base=pathlib.Path(__file__).resolve().parent
variant=sys.argv[1]; phase=base/(variant+'_phase.json')
k=c.WinDLL('kernel32',use_last_error=True)
k.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD]; k.OpenProcess.restype=w.HANDLE
k.GetProcessTimes.argtypes=[w.HANDLE,c.POINTER(w.FILETIME),c.POINTER(w.FILETIME),c.POINTER(w.FILETIME),c.POINTER(w.FILETIME)];k.GetProcessTimes.restype=w.BOOL
k.CloseHandle.argtypes=[w.HANDLE]
def state():
 try:return json.loads(phase.read_text(encoding='utf-8-sig'))
 except (ValueError,OSError):return {}
start=time.perf_counter()
while True:
 st=state()
 if st.get('label')=='waiting_for_sampler':break
 if time.perf_counter()-start>50:raise RuntimeError('No waiting benchmark: inspect native log')
 time.sleep(.1)
pid=st['pid']; h=k.OpenProcess(0x400|0x10,False,pid)
if not h: raise c.WinError(c.get_last_error())
def cpu():
 vals=[w.FILETIME() for i in range(4)]
 if not k.GetProcessTimes(h,*[c.byref(x) for x in vals]):raise c.WinError(c.get_last_error())
 return sum((x.dwHighDateTime<<32)+x.dwLowDateTime for x in vals[2:])/10000000
(base/(variant+'_sampler_ready')).write_text(str(pid))
rows=[];last=(time.perf_counter(),cpu(),state().get('label'));ended=False
while time.perf_counter()-start<300:
 time.sleep(.1);st=state();now=(time.perf_counter(),cpu(),st.get('label'))
 if now[2]==last[2] and str(now[2]).startswith('cpu_'):
  rows.append({'label':now[2],'wall_s':now[0]-last[0],'cpu_s':now[1]-last[1]})
 last=now
 if st.get('label')=='complete':ended=True;break
k.CloseHandle(h)
out={'variant':variant,'pid':pid,'logical_cpus':os.cpu_count(),'ended':ended,'method':'Windows GetProcessTimes kernel+user / perf_counter wall; excludes changing phase boundaries and instrumented windows','samples':rows}
(base/(variant+'_cpu.json')).write_text(json.dumps(out,indent=2))
print(json.dumps({'variant':variant,'ended':ended,'intervals':len(rows)}))
