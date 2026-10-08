# Built-in abapGit label colors

User settings on A4H25 contain `abap2UI5:lightblue, abapGit:lightred`.
The service reads these settings correctly, but its named-color allow-list
omitted these built-in abapGit label styles, causing automatic fallback.

Recognize every named style advertised by abapGit's personal settings and map
its color family to the existing six-color pill palette. The same service
mapping supplies tiles, list rows and repository headers. Keep the current
automatic colors for unconfigured or unsupported values and retain hex-color
validation. Do not modify persisted user settings.
