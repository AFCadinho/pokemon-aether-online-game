"""Native TRMMT form slots including scalar emission parameters."""
import math
import struct
from pathlib import Path
from scvi_tracm import _Buffer
from scvi_form_material import sample
from alternate_forms_batch import sha


def parameters(path, variant, index):
    if variant not in ('normal','rare') or type(index) is not int or not 0<=index<=17:
        raise ValueError('Invalid native form slot')
    b=_Buffer(Path(path).read_bytes())
    v,=[v for v in b.tables(b.u32(0),2) if b.string(v,0)==variant]
    result={};bindings=[]
    for prop in b.tables(v,3):
        assert b.string(prop,0)=='color'
        targets={tuple(b.string(m,i) for i in range(3)) for m in b.tables(prop,1)}
        ptr=b.pointer(b.pointer(prop,4),0);c=_Buffer(b.data[ptr+4:ptr+4+b.u32(ptr)])
        found=set()
        for t in c.tables(c.u32(0),1):
            assert not c.field(t,5) and not c.field(t,6)
            mesh=c.string(t,0)
            for m in c.tables(c.pointer(t,4),2):
                mat=c.string(m,0)
                for slot,kind in [(1,'float'),(2,'color')]:
                    for param in c.tables(m,slot):
                        key=c.string(param,0);identity=(mesh,mat,key)
                        if identity not in targets:continue
                        channels=c.pointer(param,1)
                        sequences=[channels] if kind=='float' else [c.pointer(channels,k) for k in range(4)]
                        values=[]
                        for seq in sequences:
                            keys=[tuple(c.scalar(k,i,lambda o:struct.unpack_from('<f',c.data,o)[0]) for i in (0,1)) for k in c.tables(seq,0)]
                            values.append(sample(keys,index))
                        value=values[0] if kind=='float' else values
                        k=(mat,key,kind)
                        if k in result and result[k]!=value:raise ValueError('Conflicting mesh-bound selector values')
                        found.add(identity);result[k]=value;bindings.append([mesh,mat,key,kind,value])
        if found!=targets:raise ValueError('Missing native selector channel')
    return result,bindings


def apply(table, selector, variant, index, output):
    values,bindings=parameters(selector,variant,index)
    data=bytearray(Path(table).read_bytes());original=bytes(data);b=_Buffer(data);remaining=set(values);allowed=set()
    for m in b.tables(b.u32(0),1):
        name=b.string(m,0)
        for slot,kind,fmt in [(4,'float','<f'),(7,'color','<4f')]:
            for p in b.tables(m,slot):
                key=(name,b.string(p,0),kind)
                if key not in values:continue
                loc=b.field(p,1)
                if not loc:raise ValueError('Selector target has no explicit source storage')
                v=values[key];v=[v] if kind=='float' else v
                assert all(math.isfinite(x) for x in v)
                struct.pack_into(fmt,data,p+loc,*v)
                allowed.update(range(p+loc,p+loc+struct.calcsize(fmt)));remaining.remove(key)
    assert not remaining and len(data)==len(original)
    assert all(a==z or i in allowed for i,(a,z) in enumerate(zip(data,original)))
    Path(output).write_bytes(data)
    return {'source_sha256':sha(table),'selector_sha256':sha(selector),'variant':variant,'index':index,
        'bindings':bindings,'only_selected_parameter_bytes_changed':True,'output_sha256':sha(output)}
