"""Finish delivery and UI checks as each independent battle measurement becomes ready."""
import argparse,hashlib,time
from concurrent.futures import ThreadPoolExecutor,as_completed
from final_twenty_one import ROOT,WORK,NAMES,read,write,sha,run,context,check_ui

def finish(name):
    deadline=time.monotonic()+5400
    status=WORK/'status/battle'/(name+'.json')
    while not status.exists():
        if time.monotonic()>deadline:raise TimeoutError('Battle evidence did not arrive: '+name)
        time.sleep(3)
    measured=read(status);assert measured['status']=='measured',(name,measured)
    delivery=WORK/'delivery'/name;state=WORK/'status/delivery'/(name+'.json')
    if not state.exists():
        import alternate_forms_delivery
        write(state,alternate_forms_delivery.qualify(name))
    assert read(state)['status']=='delivery_checked'
    print('DELIVERED',name,flush=True)
    for renderer in ['gl_compatibility','mobile']:
        check_ui(name,renderer)
    return name

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('names',nargs='+',choices=NAMES);p.add_argument('--workers',type=int,default=1,choices=[1,2]);a=p.parse_args();context()
    errors=[]
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        jobs={pool.submit(finish,n):n for n in a.names}
        for future in as_completed(jobs):
            try:print('FINISHED',future.result(),flush=True)
            except Exception as e:errors.append({'species':jobs[future],'error':str(e)});print('FAILED',jobs[future],str(e),flush=True)
    run_key=hashlib.sha256('\n'.join(a.names).encode()).hexdigest()[:12]
    write(WORK/('pipeline-errors-'+run_key+'.json'),errors)
    if errors:raise SystemExit(1)
