# E02 mechanical relocation

The move manifest records every tracked module/example source file and its pre-move SHA-256. Two tracked empty Hugo build locks are excluded as generated files. All other module files move byte-for-byte, including go.mod, templates, assets and translations. The module identity remains unchanged until the explicit identity/cutover work.

The example moves to examples/reference-guide-site. Only its module replacement paths and output/resource directories change in this commit. Development commands, editor tasks, instruction scopes, translation helper defaults and CI source paths follow the new locations. Azure hosting configuration remains at the root because the existing packaging workflow consumes it there.

Local, preview and production example builds pass. Module source hashes match the manifest. Raw outputs have the same file inventories as the frozen baseline, but byte identity is not claimed: debug output exposes relocated filesystem paths, and Hugo reports pre-existing duplicate output routes from imported content. The unchanged control build with --printPathWarnings reports four writers to index.html/index.xml plus download/translation route collisions. These are not resolved by editing multilingual module templates.

The planned follow-up removes the example's active Kanban content/i18n dependency and retains its own example guides. That is a distinct example-only behavior change, not a change to consumer guide content or module behavior. Consumer functional equivalence remains E05 before adoption.
