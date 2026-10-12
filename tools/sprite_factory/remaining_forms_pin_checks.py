"""Accept only the explicitly requalified alias resolver in historical receipts."""
import hashlib
import json
from pathlib import Path


def code_pin_valid(root, name, historical):
    actual=hashlib.sha256((root/name).read_bytes()).hexdigest()
    if actual==historical: return True
    if name!='scripts/battle/battle_ui/reviewed_model_catalog.gd': return False
    receipt_path=root/'tools/sprite_factory/remaining_forms_repair_qualification.json'
    receipt=json.loads(receipt_path.read_bytes())
    if (receipt.get('runtime_approved') is True and receipt.get('admitted_registry_check_passed') is True
            and receipt.get('historical_code_sha256',{}).get(name)==historical
            and receipt.get('code_sha256',{}).get(name)==actual
            and len(receipt.get('shared_forms',{}).get('forms',[]))==13):
        return True
    return False
