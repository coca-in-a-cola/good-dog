# command-director

Original GDD sections: 4,12. Status: OPEN / not implemented.

## Responsibility and contract

Signal-driven IDLE→ORDER_SHOWN→WAITING→SUCCESS|ESCALATE|FAIL. Command resources own ladder20/10/5/3/2/1; start after dismissal, reset to20 each new task. Reject stale/duplicate completion, stop timer instantly, QUIET outside bark task does not penalize. Esc pauses, failure resets menu/no progress save.

## Acceptance and evidence

Test actual production signals/resources, deterministic failure paths and restart cleanup. Record command, exit, tested source identity and evidence path; add visual/audio evidence where relevant. Source values override this synopsis. No phase accepted by documentation alone.
