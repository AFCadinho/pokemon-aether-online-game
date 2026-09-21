import tempfile
import unittest
from pathlib import Path
from scvi_source_audit import differences,timeline_counts
from test_scvi_identity import Fixture


class SourceAuditTests(unittest.TestCase):
    def test_priority_difference_is_reported_not_erased(self):
        a={'nodes':[{'priority':0,'name':'eyelid'}]}
        b={'nodes':[{'priority':2,'name':'eyelid'}]}
        self.assertEqual(differences(a,b),[{'path':'/nodes/0/priority','model':0,'romfs':2}])

    def test_new_fields_and_structure_differences_are_not_ignored(self):
        self.assertTrue(differences({'nodes':[]},{'nodes':[],'unknown':0}))
        self.assertTrue(differences([1],[1,2]))
        self.assertTrue(differences(1,'1'))
        self.assertEqual(differences({'value':[1,2.]},{'value':[1,2.]}),[])

    def test_counts_measure_unfiltered_timeline_structures(self):
        f=Fixture();root=f.table(5,present=[1,2,3,4])
        for slot,value in [(2,2),(3,3),(4,0)]:f.put(f.field(root,slot),value,'B')
        for pointer,present in zip(f.vector(f.field(root,1),3),[[4,5],[4,5],[5]]):
            track=f.table(7,present=present);f.pointer(pointer,track)
            for slot in present:f.pointer(f.field(track,slot),f.table(0))
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'test.tracm';path.write_bytes(f.finish(root))
            self.assertEqual(timeline_counts(path),([2,3,0],[2,3,0]))
