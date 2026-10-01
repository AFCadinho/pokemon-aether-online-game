import copy
import unittest
from battle_form_motion_intake import prepare


class MotionTests(unittest.TestCase):
    def test_shared_attack_changes_only_name_and_preserves_source(self):
        data={'clips':[{'name':'pm1120_12_00|pm1120_11_00_00400_attack01','frames':[{'time':0,'tracks':{'eye':{'1':[1,2,3]}}}]}]}
        original=copy.deepcopy(data)
        result,receipt=prepare('pm1120_12_00',data)
        self.assertEqual(data,original)
        self.assertEqual(result['clips'][0]['frames'],data['clips'][0]['frames'])
        self.assertEqual(receipt['aliases'][0]['source'],data['clips'][0]['name'])
        with self.assertRaises(ValueError):prepare('pm1130_12_00',data)

    def test_complete_clock_uses_all_three_components_without_duplicate_keys(self):
        clips=[]
        for i,suffix in enumerate(['20460_rangeattack02_start','20461_rangeattack02_loop','20462_rangeattack02_end']):
            clips.append({'name':'pm1130_12_00|pm1130_12_00_'+suffix,'fps':30,'duration':1,
                          'frames':[{'time':0,'tracks':{'part':i}},{'time':1,'tracks':{'part':i}}]})
        result,receipt=prepare('pm1130_12_00',{'clips':clips})
        combined=result['clips'][-1]
        self.assertEqual(combined['duration'],3)
        self.assertEqual([f['time'] for f in combined['frames']],[0,1,2,3])
        self.assertEqual([f['tracks']['part'] for f in combined['frames']],[0,1,2,2])
        self.assertEqual(len(receipt['composite_special_attack']['native_components']),3)
        clips[1]['fps']=24
        with self.assertRaises(ValueError):prepare('pm1130_12_00',{'clips':clips})


if __name__=='__main__':unittest.main()
