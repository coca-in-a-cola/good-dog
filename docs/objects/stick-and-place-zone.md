# stick-and-place-zone

Original GDD sections: 4,5. Status: OPEN (F3). F2 provides only the extension contract `scripts/interactables/interactable.gd`: `completed(completion)`, `completion_signal`, `complete()` fires once per arm, `reset()`, bound with `CommandDirector.bind_interactable()` and disconnected by `stop()`. Stick, place zone and pit subclasses with aim/zone/trigger logic are not implemented.

## Responsibility and contract

Grab E only aimed within2m; invalid attempts do nothing while timer runs. Carry stick lower-centre like in teeth; place only carrying+inside marked zone+E. Emit grabbed/placed exactly once; clear carried visual after placement.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
