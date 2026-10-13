"""Keep each worktree's isolated debug identity independent of other slots."""


def package_for_root(root):
    slot = root.parent.name
    suffix = "." + slot.replace("-", "_") if slot in {"slot-a", "slot-b", "slot-c", "slot-d"} else ""
    return "com.pokeaether.androidgpuqa" + suffix
