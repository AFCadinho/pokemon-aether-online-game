#!/usr/bin/env python3
"""Run the frozen full texture probes in a fresh, minimal native project."""
import argparse
from pathlib import Path
import signal
import subprocess
import sys

import audit_full_texture_storage as audit
import resume_full_texture_audit as resume
import study_lossless_texture_storage as base
from probe_v13_compression import read, require, write

PROJECT = '''config_version=5

[application]
config/name="PokeAether offline texture probe"

[display]
window/size/viewport_width=64
window/size/viewport_height=64

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'''
SCRIPTS = [audit.SCRIPT, base.SCRIPT, 'tools/sprite_factory/model_texture_audit.gd',
           'tools/sprite_factory/shared_geometry_collection.gd', 'tools/sprite_factory/shared_geometry_prototype.gd',
           'tools/sprite_factory/model_geometry_audit.gd', 'scripts/services/model_pair_pack.gd']


def make_project():
    root = base.ROOT/'.tmp/full-texture-isolated-project-v1'
    root.mkdir(exist_ok=True)
    project = root/'project.godot'
    if project.exists(): require(project.read_text() == PROJECT, 'Changed isolated probe configuration')
    else: project.write_text(PROJECT)
    for name in SCRIPTS:
        target = root/name
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink(): require(target.resolve() == (base.ROOT/name).resolve(), 'Changed probe script link')
        else:
            require(not target.exists(), 'Unexpected copied probe script')
            target.symlink_to(base.ROOT/name)
    return root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = make_project()
    bindings = {p: base.sha(base.ROOT/p) for p in [*SCRIPTS, 'tools/resume_full_texture_audit.py', 'tools/resume_isolated_texture_audit.py']}
    project_sha = base.sha(root/'project.godot')

    def native_run(mode, config, output, script=audit.SCRIPT):
        require(script in SCRIPTS, 'Unexpected isolated probe')
        output.mkdir(parents=True, exist_ok=False)
        job = output/'input.json'
        write(job, config)
        log = output/'engine.stdout.log'
        command = ['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
                   '--path', str(root), '--log-file', str(output/'engine.log'),
                   '--script', 'res://'+script, '--', mode, str(job), str(output)]
        with log.open('w') as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
        text = log.read_text()
        require(result.returncode == 0 and 'LOSSLESS_TEXTURE_ENGINE_OK' in text and
                'ERROR:' not in text and 'SCRIPT ERROR' not in text, f'Isolated native audit failed: {log}')
        report = read(output/'report.json')
        require(report['complete'] and report['input_sha256'] == base.sha(job) and
                report['pack_sha256'] == config['asset']['sha256'], 'Unbound isolated native evidence')
        return report

    original = audit.native_run
    audit.native_run = native_run
    argv = sys.argv
    try:
        sys.argv = [str(base.ROOT/'tools/resume_full_texture_audit.py'), '--output', str(args.output)]
        resume.main()
    finally:
        audit.native_run = original
        sys.argv = argv
    require(bindings == {p: base.sha(base.ROOT/p) for p in bindings} and
            base.sha(root/'project.godot') == project_sha, 'Changed isolation inputs')
    report = read(args.output/'report.json')
    report.update(isolation_inputs=bindings, isolated_project_sha256=project_sha,
                  isolated_project_path=str(root), isolated_execution_driver_sha256=base.sha(Path(__file__)))
    write(args.output/'report.json', report)
    print('ISOLATED_TEXTURE_AUDIT_COMPLETE', flush=True)


if __name__ == '__main__':
    def interrupted(signum, _frame):
        raise InterruptedError(f'Audit interrupted by signal {signum}; checkpoints retained')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    main()
