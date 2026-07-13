# Privacy

MacPulse is local-only software.

## Data read

- aggregate Mach CPU counters;
- Mach virtual-memory counters;
- hardware and operating-system descriptors;
- read-only AGXAccelerator/IOAccelerator registry properties;
- Low Power Mode and thermal state.

## Data stored

A bounded JSON payload containing recent utilization, optional GPU telemetry, machine class, timestamps, and history is stored in the process-local Application Support directory. Standard user preferences are stored in `UserDefaults`. The widget stores only its own bounded timeline history in its sandbox.

## Data not collected

MacPulse does not intentionally read or store:

- user name;
- Apple ID;
- host name;
- serial number;
- files or document contents;
- browser history;
- IP or MAC addresses;
- contacts, calendar, mail, microphone, camera, or location.

## Network

The application contains no networking feature and performs no update, analytics, advertising, or telemetry request.

## Diagnostics

The built-in diagnostic JSON excludes identifying account, network, and path information. Users should still inspect any report before publishing it.

## Privacy manifest

The application target contains `PrivacyInfo.xcprivacy`. It declares:

- tracking disabled;
- no tracking domains;
- no collected data types;
- approved UserDefaults reasons for application preferences and local widget history.

The manifest must be reviewed whenever persistence APIs or data flows change.
