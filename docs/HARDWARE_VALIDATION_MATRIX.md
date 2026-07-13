# Hardware Validation Matrix

This matrix is a release evidence template, not a claim that every listed configuration has been tested in the source-generation environment.

| ID | Hardware class | Architecture | GPU provider expected | Required observation |
|---|---|---|---|---|
| AS-1 | Apple Silicon Mac | arm64 | AGXAccelerator | CPU, GPU activity if published, widgets, sleep/wake |
| IM-1 | Intel Mac integrated GPU | x86_64 | IOAccelerator | CPU and Intel activity if published |
| AMD-1 | Intel Mac + AMD discrete | x86_64 | IOAccelerator | utilization, model, stale handling, optional clocks/temp/power/VRAM |
| DG-1 | Dual-GPU Intel Mac | x86_64 | multiple IOAccelerator entries | primary continuity and all selection modes |
| HK-1 | accelerated Intel/AMD Hackintosh | x86_64 | IOAccelerator | no crash; honest supported/unavailable fields |
| VM-1 | macOS virtual machine | arm64/x86_64 | hypervisor-dependent | CPU works; GPU unavailable unless exposed |
| NEG-1 | no usable accelerator telemetry | any | none | GPU em dash/unavailable, CPU remains functional |

For every executed row record:

- exact hardware model or anonymized board class;
- macOS version and build;
- MacPulse version/build;
- architecture;
- connected display topology;
- provider class and utilization key;
- idle and controlled-load observations;
- average app CPU/wakeups for the selected profile;
- screenshots of all supported widget sizes;
- pass/fail and issue references.
