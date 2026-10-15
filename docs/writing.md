# Text rules

Use [ASD-STE100 Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf) for comments, documentation and human-readable messages.
Apply the same rules to the project Notion page.
The [official FAQ](https://www.asd-ste100.org/STE_faq.html) explains the rules and technical terminology.

## Instructions

- Use the active voice.
- Give one instruction in each sentence.
- Put required conditions before the instruction.
- Use a maximum of 20 words in an instruction sentence.
- Use a maximum of 25 words in a descriptive sentence.
- Use the same term for the same item.
- Do not use idioms, contractions or unnecessary words.
- Use approved words with their approved meanings and parts of speech.
- Keep code identifiers, paths, commands, product names and API fields unchanged.

## Project technical terms

These nouns identify software items or functions:

| Term | Meaning |
| --- | --- |
| activation | Apply a built system configuration to a host |
| closure | A Nix output and all its dependencies |
| GC root | A reference that prevents Nix garbage collection |
| initrd | Files and programs that start before the installed root filesystem |
| CoW | Copy-on-write data storage |
| NOCOW | File policy that disables CoW |
| sparse raw image | Guest disk file with unallocated ranges |
| virtio-fs | Filesystem export from a host to a guest |
| scrub | Filesystem checksum verification |
| TRIM | SSD block discard operation |
| CI | Automated repository checks and builds |
| PR | GitHub pull request |

Use product names, filesystem names and protocol names from the configuration.
Use these technical verbs for their software operations:

- `activate`, `boot`, `build`, `deploy`, `evaluate`, `format`, `merge`, `mount`, `pin`, `rebuild`, `scrub` and `trim`.
