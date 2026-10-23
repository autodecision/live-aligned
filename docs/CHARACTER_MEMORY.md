# Character dialogue memory

`character_memory.gd` stores independent local dialogue for each stable character
ID under `user://ai/memory`. The player can compact or clear the selected
character's memory. Failed, cancelled, and incomplete dialogue is not a completed
turn and should not be passed to `append_turn()`.

The design takes inspiration from `~/Projects/chatbot/chatbot-old/memory.py`:
limited retained records, cosine-ranked relevant recall, separate recent dialogue,
and strict storage/memory budgets. The bot's learned embeddings, Python, NumPy,
and SQLite are not required or bundled. Here cosine similarity compares sparse
word-frequency vectors computed on demand. It finds shared words; it does not
understand synonyms or provide learned semantic retrieval. Character IDs select
separate files, never a shared pool of memories for all NPCs.

## Finite retention

Defaults retain up to 12 recent complete turns plus 512 older excerpts and up to
24 structured durable player notes (`obligation`, `plan`, `goal`, `feeling`,
`friends`, `no_friends`) per character, subject to the byte ceiling. Each message is limited to 6,000 Unicode
characters before storage. Older dialogue becomes literal extracts from the
beginning, middle, and end of each message, preserving speaker labels and marking
gaps. During long conversations and as record or byte limits are approached,
logical compaction rolls excess character volume from `recent` into `recall`,
extracts durable player statements into `notes`, and folds non-redundant clauses
from pruned recall entries into surviving neighbor digests (`| Earlier: …`) before
removal. Role-guided RAG retrieval combines stem-normalized word matching with
the character's check-in focus and durable notes, and includes recent overflow turns
so long conversations have no blind spot between `recent` and `recall`. Manual compaction keeps up to four recent turns and halves the
recall allowance for that operation, with a minimum of eight excerpts.

The effective per-character snapshot limit defaults to **1 MiB** and is always
clamped to 2 KiB–1 MiB, and at most half the global limit. The global limit defaults
to **128 MiB**, configurable from 8 KiB through 2 GiB. One per-character allowance
is reserved inside the global limit for an atomic staging write, so the default
retained corpus is at most **127 MiB**, with up to 1 MiB of staging headroom.
There are at most 512 character snapshots (configurable downward). The UI/statistics
report the effective snapshot budget, total budget, retained budget, and reserve.
UTF-8 serialized byte sizes enforce disk limits; character counts enforce prompt
and message limits independently. Actual retention may be lower for long or
non-ASCII messages.

Global byte or character-count pressure evicts entire other character snapshots,
oldest modification time first, with the hashed filename breaking ties. The
character being saved is protected. Viewing a character does not refresh its
modification time. Shrinking limits enforces retention immediately, so a smaller
global/count budget may remove old characters. `evicted_characters` reports
whole-character evictions during the current store instance; `pruned_entries`
counts discarded records retained in each character snapshot. Neither counter is
an unlimited audit log. Prompt context defaults to at most 18,000 characters,
including up to six matching excerpts within a 4,800-character recall allowance.
Budgets of zero or one omit recent pairs; larger small budgets truncate only the
latest pair while keeping its two roles. The current query is appended separately
by the dialogue caller. Persona and current-query text are outside this memory
context allowance.

## Persistence and recovery

Character IDs are SHA-256 hashed into filenames, so path-like IDs cannot escape
the dedicated directory. Files validate schema, character identity, field types,
record counts, and the 1 MiB load ceiling. Invalid character records report an
error and remain available for recovery until that character is explicitly
cleared or storage-limit eviction removes it. Files above the hard 1 MiB safety
ceiling are removed when configuration enforces the ceiling.

A save writes a single `.tmp` snapshot, flushes it, checks its length, and atomically
renames it over the previous snapshot. Other characters are evicted only after a
successful commit. If write or rename fails, other character snapshots remain;
a post-commit eviction failure returns `committed: true` and an error. This is
ordinary file replacement, not a guarantee against filesystem/power failure.
Interrupted `.tmp` files are removed on configuration and before writes; there are
no growing quarantine, backup, tombstone, or journal collections. Clearing a
character removes both its snapshot and staging file.

Every regular file in the dedicated directory counts toward the global byte
budget, including unknown names and interrupted writes. Only exact owned hashed
snapshot/staging names are removed automatically. Unknown files are left for the
user; if they consume the budget, writes report an error. Unreadable inventory
files fail closed rather than being counted as empty. The directory is intended
for this store only, with one active writer; it is not a recursive arbitrary-file
quota or a multi-process database.

Credential-shaped strings are redacted before persistence as a best-effort
safeguard. This is not a general secret detector. Recalled excerpts are labeled
as quoted historical data for the model; model behavior still depends on the
chosen provider and character prompt.

## Verification

Run `godot --headless --path . --script res://scripts/check_character_memory.gd`.
The check uses a unique temporary directory, removes it afterward, and never
reads or modifies the player's memory. It covers restart persistence, recall,
character isolation, byte/count pressure, long Unicode, selected deletion,
malformed records, credential redaction, manual compaction, tiny prompt budgets,
limit reduction, interrupted writes, and forced write/rename failures that must
preserve the other characters.
