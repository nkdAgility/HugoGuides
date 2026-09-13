# Using the shared publishing commands

These are platform candidate skills, not yet an installed consumer release. E07 will supply the pinned bootstrap/package paths. Do not import an arbitrary globally installed Core version or invent policy from test fixtures.

In the platform development checkout, load `system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1`. In an adopted site, load Core through its version-locked bootstrap. Set WorkspaceRoot to the consumer repository root and load its reviewed site policy with `Import-GuidePolicy -Path $PolicyPath`.

Site policy describes an unrestricted collection of guides; counts in fixtures are examples. Core decisions have no agent dependency. Agent instructions do not grant write authority or replace the independent E06 gate. Mutation commands support WhatIf and refuse protected resources under the supplied policy.

Initial extraction deliberately reports unsupported work rather than pretending to complete it: effective Hugo wrapper/i18n reconciliation and build wiring for PDF cache evidence remain E03 follow-up. Root Prepare/Build reporting is E04. Preserve the consumer's multilingual content structure and bespoke wrapper throughout.
