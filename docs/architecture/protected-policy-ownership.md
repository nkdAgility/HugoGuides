# Protected-policy ownership — decision for E01/E06

Recorded human owner: **@MrHinsh** for technical/publication policy in all three consumers and for platform evaluator releases. Preserve each consumer's existing editorial ownership. No role, CODEOWNERS or ruleset change has been applied by this decision.

Evidence checked on 13 September 2026:

| Repository | Existing evidence | Protected-policy owner |
|---|---|---|
| KanbanGuides/KanbanGuides | Technical/configuration/layout entries name @mrhinsh. Current repository administrators include @MrHinsh and @ViralGoodAgile. | @MrHinsh |
| nkdAgility/the-safe-delusion | No root .github/CODEOWNERS file. Current administrators are @MrHinsh and @nkdagilitybot; @lucaminudel has write access. | @MrHinsh; preserve audited guide/PDF protection and its separate content approval |
| ScrumGuides/ScrumGuide-ExpansionPack | Technical/configuration/layout entries name @mrhinsh, with per-guide editorial owners. Current administrators include @MrHinsh, @ViralGoodAgile and @rjocham. | @MrHinsh |
| nkdAgility/OpenGuidePlatform | Current administrators are @MrHinsh and @nkdagilitybot. | @MrHinsh; automation identity does not itself grant publication-policy approval |

Git remotes supplied the exact repository identities. CODEOWNERS files were read from the current local consumer checkouts; administrator roles were queried through the GitHub API. These are evidence for the proposal, not proof that CODEOWNERS coverage or independent enforcement currently works. In particular, the purported default owner line uses `-`, not the intended catch-all pattern; review technical-path coverage in each adoption PR rather than claiming the comment makes every file protected.

The maintainer instructed closure of the outstanding E01 gaps after this owner was proposed. This records @MrHinsh as the technical/publication-policy owner for implementation, preserving existing editorial ownership. Administrative installation and live enforcement remain separate E06 acceptance work; no permissions or GitHub settings are changed. The installer/evaluator must never infer maintainer authority from a candidate policy field, PR label or the agent's own claim.

Existing repository administration and editorial roles are recorded separately from the proposed approver. This does not propose removing collaborators or reducing anyone's access. The independent evaluator/deployment authority still needs E06 implementation and tamper tests; instruction files and repository-local settings cannot provide that boundary.