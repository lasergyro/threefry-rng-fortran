PractRand (stdin32, default test set; stops at the first failing length):

| Rounds | Function | Layout | Result | Source |
| --- | --- | --- | --- | --- |
| 1 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (63 failing results) | src 85557f4d |
| 1 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (63 failing results) | src 85557f4d |
| 2 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (60 failing results) | src 85557f4d |
| 2 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (60 failing results) | src 85557f4d |
| 3 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (57 failing results) | src 85557f4d |
| 3 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (57 failing results) | src 85557f4d |
| 4 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (54 failing results) | src 85557f4d |
| 4 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (47 failing results) | src 85557f4d |
| 5 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (34 failing results) | src 85557f4d |
| 5 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (31 failing results) | src 85557f4d |
| 6 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (19 failing results) | src 85557f4d |
| 6 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (15 failing results) | src 85557f4d |
| 7 | `threefry2x32_r` | counter | **FAIL at 1 megabyte** (7 failing results) | src 85557f4d |
| 7 | `threefry2x32_r` | key | **FAIL at 1 megabyte** (9 failing results) | src 85557f4d |
| 8 | `threefry2x32_r` | counter | **FAIL at 8 megabytes** (2 failing results) | src 85557f4d |
| 8 | `threefry2x32_r` | key | **FAIL at 8 megabytes** (1 failing results) | src 85557f4d |
| 9 | `threefry2x32_r` | counter | **FAIL at 256 megabytes** (2 failing results) | src 85557f4d |
| 9 | `threefry2x32_r` | key | **FAIL at 512 megabytes** (2 failing results) | src 85557f4d |
| 10 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 10 | `threefry2x32_r` | counter | no failure up to 1 terabyte | src 85557f4d |
| 10 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 10 | `threefry2x32_r` | key | no failure up to 1 terabyte; final length flags: [Low1/32]FPF-14+6/16:(0,14-0) R= +8.7 p = 1.2e-7 suspicious; [Low1/32]FPF-14+6/16:cross R= +12.9 p = 3.2e-11 VERY SUSPICIOUS | src 85557f4d |
| 11 | `threefry2x32_r` | counter | no failure up to 32 gigabytes; final length flags: [Low1/32]DC6-9x1Bytes-1 R= -4.5 p =1-3.3e-3 unusual | src 85557f4d |
| 11 | `threefry2x32_r` | counter | no failure up to 1 terabyte; final length flags: [Low1/32]Gap-16:B R= -4.7 p =1-6.8e-4 unusual | src 85557f4d |
| 11 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 11 | `threefry2x32_r` | key | no failure up to 1 terabyte | src 85557f4d |
| 12 | `threefry2x32_r` | counter | no failure up to 32 gigabytes; final length flags: [Low8/32]BCFN(2+0,13-0,T) R= -7.9 p =1-4.1e-4 unusual | src 85557f4d |
| 12 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 13 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 13 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 14 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 14 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 15 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 15 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 16 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 16 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 17 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 17 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 18 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 18 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 19 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 19 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 20 | `threefry2x32` | counter | no failure up to 8 gigabytes | src 85557f4d |
| 20 | `threefry2x32_r` | counter | no failure up to 32 gigabytes | src 85557f4d |
| 20 | `threefry2x32_r` | counter | no failure up to 1 terabyte | src 85557f4d |
| 20 | `threefry2x32_r` | key | no failure up to 32 gigabytes | src 85557f4d |
| 20 | `threefry2x32_r` | key | no failure up to 1 terabyte | src 85557f4d |

dieharder (stdin_input_raw, -g 200):

| Rounds | Function | Layout | Arguments | Result | Wall time | Source |
| --- | --- | --- | --- | --- | --- | --- |
| 20 | `threefry2x32` | counter | `-g 200 -a` | 111 test rows: 104 PASSED, 7 WEAK, 0 FAILED | 00:35:37 | src 85557f4d |

TestU01 1.2.3:

| Battery | Rounds | Function | Layout | Result | CPU time | Source |
| --- | --- | --- | --- | --- | --- | --- |
| Crush | 20 | `threefry2x32` | counter | all 144 statistics passed | 00:13:28.00 | src 85557f4d |
| Crush | 20 | `threefry2x32` | key | pass; 1 of 144 outside [0.001, 0.999] (about 0.3 expected by chance): BirthdaySpacings, t = 2 p = 0.9994 | 00:13:29.38 | src 85557f4d |
| BigCrush | 20 | `threefry2x32` | counter | all 160 statistics passed | 01:36:00.17 | src 85557f4d |
| BigCrush | 20 | `threefry2x32` | key | all 160 statistics passed | 01:36:12.19 | src 85557f4d |

